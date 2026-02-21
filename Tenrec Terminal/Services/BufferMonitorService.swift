import Foundation
import os

/// Periodically scans the terminal buffer for interactive prompt patterns and publishes
/// state changes to ``TerminalBufferState`` on the main actor.
///
/// The scan loop runs entirely on the actor's executor (background). Every state mutation
/// on ``TerminalBufferState`` is dispatched to `@MainActor` explicitly.
///
/// ## Typical lifecycle
/// ```swift
/// let service = BufferMonitorService(bufferState: myState)
/// service.setBufferReader { /* return last N lines from TerminalView */ }
/// await service.startMonitoring()
/// // … terminal in use …
/// await service.stopMonitoring()
/// ```
///
/// ## Testability
/// Inject a custom `bufferReader` closure to avoid a real `TerminalView` in unit tests.
actor BufferMonitorService {

    // MARK: - Private state

    private let matcher: PromptPatternMatcher
    private let bufferState: TerminalBufferState
    private let scanLineCount: Int
    private let scanInterval: TimeInterval

    /// Hash of the last scanned buffer content. Used to skip redundant processing
    /// when the terminal has not produced new output between scan ticks.
    private var lastContentHash: Int = 0

    /// The active monitoring loop task. Non-nil while monitoring is running.
    private var monitorTask: Task<Void, Never>?

    /// Buffer reader closure injected by the view layer (or test harness).
    ///
    /// Returns the last `scanLineCount` lines of the terminal buffer as plain strings.
    /// The closure itself must be safe to call from any actor (it is `@Sendable`).
    private var bufferReader: (@Sendable () -> [String])?

    private static let logger = Logger(
        subsystem: "com.metamech.TenrecTerminal",
        category: "BufferMonitor"
    )

    // MARK: - Initialisation

    /// - Parameters:
    ///   - bufferState: Observable state published to the UI layer.
    ///   - matcher: Pattern engine; defaults to the shared built-in matcher.
    ///   - scanLineCount: Number of terminal lines to read on each scan tick (default 10).
    ///   - scanInterval: Seconds between scan ticks (default 0.5 s).
    init(
        bufferState: TerminalBufferState,
        matcher: PromptPatternMatcher = PromptPatternMatcher(),
        scanLineCount: Int = 10,
        scanInterval: TimeInterval = 0.5
    ) {
        self.bufferState = bufferState
        self.matcher = matcher
        self.scanLineCount = scanLineCount
        self.scanInterval = scanInterval
    }

    // MARK: - Public API

    /// Inject the closure that reads lines from the terminal buffer.
    ///
    /// Call this from the view layer once `TerminalView` is available, for example:
    /// ```swift
    /// await bufferMonitor.setBufferReader {
    ///     let lastRow = terminalView.terminal.buffer.y
    ///     let firstRow = max(0, lastRow - scanLineCount + 1)
    ///     return (firstRow...lastRow).map { row in
    ///         terminalView.terminal.getLine(row: row).translateToString()
    ///     }
    /// }
    /// ```
    func setBufferReader(_ reader: @escaping @Sendable () -> [String]) {
        bufferReader = reader
    }

    /// Start periodic buffer scanning.
    ///
    /// Calling this while already monitoring is a no-op. Sets `bufferState.isMonitoring`
    /// to `true` on the main actor before the first scan tick fires.
    func startMonitoring() {
        guard monitorTask == nil else { return }

        // Update observable state on the main actor before the loop begins.
        let state = bufferState
        Task { @MainActor in
            state.isMonitoring = true
        }

        // Capture interval as a value type so the loop body does not need to
        // hop back to the actor just to read the stored property.
        let interval = scanInterval

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                // Duration-based sleep — available on macOS 13+ / Swift 5.9+.
                // Project minimum is macOS 26.2, so this is always safe.
                try? await Task.sleep(for: .milliseconds(Int(interval * 1_000)))

                guard !Task.isCancelled else { break }
                await self?.scanBuffer()
            }
        }

        Self.logger.debug("Monitoring started (interval: \(interval, format: .fixed(precision: 2))s, lines: \(self.scanLineCount))")
    }

    /// Stop periodic buffer scanning and clear pending-input state.
    ///
    /// Cancels the internal task and resets `bufferState.isMonitoring` and
    /// `bufferState.hasPendingInput` on the main actor.
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil

        let state = bufferState
        Task { @MainActor in
            state.isMonitoring = false
            state.updatePendingInput(match: nil)
        }

        Self.logger.debug("Monitoring stopped")
    }

    // MARK: - Scanning

    /// Perform a single synchronous scan of the terminal buffer.
    ///
    /// This method is `nonisolated`-safe to call from tests directly. It skips
    /// processing when the buffer content has not changed since the last scan
    /// (hash comparison) to keep CPU overhead negligible during idle sessions.
    func scanBuffer() async {
        guard let reader = bufferReader else {
            // No reader yet — view layer has not provided one. Skip silently.
            return
        }

        let lines = reader()
        guard !lines.isEmpty else { return }

        // Fast-path: skip ANSI stripping and regex matching when nothing has changed.
        let contentHash = lines.joined().hashValue
        guard contentHash != lastContentHash else { return }
        lastContentHash = contentHash

        // Strip ANSI codes before pattern matching so escape sequences do not
        // produce false-positive or false-negative matches.
        let strippedLines = lines.map { PromptPatternMatcher.stripANSI($0) }
        let matches = matcher.matchAll(lines: strippedLines)

        // The last match in the array is closest to the cursor (highest line index),
        // making it the most contextually relevant result to surface to the UI.
        let bestMatch = matches.last

        Self.logger.debug(
            "Scan complete — \(lines.count) line(s), \(matches.count) match(es), best: \(bestMatch?.patternLabel ?? "none")"
        )

        let state = bufferState
        await MainActor.run {
            state.updatePendingInput(match: bestMatch)
        }
    }
}
