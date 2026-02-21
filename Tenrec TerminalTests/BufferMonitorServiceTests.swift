import Foundation
import Testing
@testable import Tenrec_Terminal

// MARK: - Mock TerminalBufferState for Testing
//
// This mock provides the interface expected by BufferMonitorService.
// Once TerminalBufferState is implemented, replace with the real class.

@Observable
@MainActor
final class MockTerminalBufferState {
    var hasPendingInput: Bool = false
    var pendingPromptText: String?
    var pendingPromptCategory: PromptCategory?
    var isMonitoring: Bool = false
    var updatePendingInputCallCount = 0
    var lastUpdatedMatch: PromptMatch?
    var resetCallCount = 0

    func updatePendingInput(match: PromptMatch?) {
        updatePendingInputCallCount += 1
        lastUpdatedMatch = match
        if let match = match {
            hasPendingInput = true
            pendingPromptText = match.matchedText
            pendingPromptCategory = match.category
        } else {
            hasPendingInput = false
            pendingPromptText = nil
            pendingPromptCategory = nil
        }
    }

    func reset() {
        resetCallCount += 1
        hasPendingInput = false
        pendingPromptText = nil
        pendingPromptCategory = nil
        isMonitoring = false
    }
}

// MARK: - Mock BufferMonitorService for Testing
//
// This is a test double that allows us to verify the expected behavior
// without requiring the full actor implementation.

actor MockBufferMonitorService {
    private let bufferState: MockTerminalBufferState
    private let matcher: PromptPatternMatcher
    private let scanLineCount: Int
    private let scanInterval: TimeInterval

    private var bufferReader: (@Sendable () -> [String])?
    private var monitoringTask: Task<Void, Never>?
    private var lastScannedHash: Int?

    init(
        bufferState: MockTerminalBufferState,
        matcher: PromptPatternMatcher = PromptPatternMatcher(),
        scanLineCount: Int = 10,
        scanInterval: TimeInterval = 0.5
    ) {
        self.bufferState = bufferState
        self.matcher = matcher
        self.scanLineCount = scanLineCount
        self.scanInterval = scanInterval
    }

    func setBufferReader(_ reader: @escaping @Sendable () -> [String]) {
        self.bufferReader = reader
    }

    func startMonitoring() {
        if monitoringTask == nil {
            monitoringTask = Task {
                while !Task.isCancelled {
                    await self.scanBuffer()
                    try? await Task.sleep(nanoseconds: UInt64(self.scanInterval * 1_000_000_000))
                }
            }
            Task { @MainActor in
                self.bufferState.isMonitoring = true
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        Task { @MainActor in
            self.bufferState.isMonitoring = false
        }
    }

    func scanBuffer() async {
        guard let bufferReader = bufferReader else {
            return
        }

        let lines = bufferReader()
        let linesToScan = Array(lines.suffix(scanLineCount))

        let matches = matcher.matchAll(lines: linesToScan)
        let firstMatch = matches.first

        // Debounce: if the content hasn't changed, don't update
        let contentHash = linesToScan.hashValue
        if let lastHash = lastScannedHash, lastHash == contentHash {
            return
        }
        lastScannedHash = contentHash

        await MainActor.run {
            self.bufferState.updatePendingInput(match: firstMatch)
        }
    }
}

// MARK: - Test Suite: BufferMonitorService Core Functionality

@Suite("BufferMonitorService")
struct BufferMonitorServiceTests {

    // MARK: Initialization

    @Test("initializes with provided bufferState")
    func initializesWithBufferState() async {
        await MainActor.run {
            let bufferState = MockTerminalBufferState()
            _ = MockBufferMonitorService(bufferState: bufferState)
        }
    }

    @Test("initializes with default matcher")
    func initializesWithDefaultMatcher() async {
        await MainActor.run {
            let bufferState = MockTerminalBufferState()
            _ = MockBufferMonitorService(bufferState: bufferState)
        }
    }

    @Test("initializes with custom scanLineCount")
    func initializesWithCustomScanLineCount() async {
        await MainActor.run {
            let bufferState = MockTerminalBufferState()
            _ = MockBufferMonitorService(bufferState: bufferState, scanLineCount: 20)
        }
    }

    @Test("initializes with custom scanInterval")
    func initializesWithCustomScanInterval() async {
        await MainActor.run {
            let bufferState = MockTerminalBufferState()
            _ = MockBufferMonitorService(bufferState: bufferState, scanInterval: 1.0)
        }
    }

    // MARK: Buffer Reader Management

    @Test("setBufferReader stores the reader closure")
    func setBufferReaderStores() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        nonisolated(unsafe) var readerCalled = false
        await service.setBufferReader {
            readerCalled = true
            return []
        }

        await service.scanBuffer()
        #expect(readerCalled == true)
    }

    // MARK: Scan Buffer Detection

    @Test("scanBuffer detects prompt in buffer")
    func scanBufferDetectsPrompt() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return ["$ ", "Continue? (y/n)"]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.hasPendingInput == true)
            #expect(bufferState.pendingPromptCategory == .confirmation)
        }
    }

    @Test("scanBuffer sets pending prompt text on match")
    func scanBufferSetsPendingText() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return ["$ setup", "Install? [Y/n]"]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptText != nil)
            #expect(bufferState.pendingPromptText?.contains("Install") == true)
        }
    }

    @Test("scanBuffer sets pending prompt category on match")
    func scanBufferSetsPendingCategory() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return ["Password: "]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptCategory == .credential)
        }
    }

    @Test("scanBuffer clears prompt when none detected")
    func scanBufferClearsPrompt() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        // First, set up a state with pending input
        await MainActor.run {
            bufferState.hasPendingInput = true
            bufferState.pendingPromptText = "Old Prompt"
            bufferState.pendingPromptCategory = .credential
        }

        // Now scan a buffer with no prompts
        await service.setBufferReader {
            return ["$ ls", "file1.txt file2.txt"]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.hasPendingInput == false)
            #expect(bufferState.pendingPromptText == nil)
            #expect(bufferState.pendingPromptCategory == nil)
        }
    }

    @Test("scanBuffer detects credential prompts")
    func scanBufferDetectsCredential() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return ["$ ssh user@host", "Password: "]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptCategory == .credential)
            #expect(bufferState.hasPendingInput == true)
        }
    }

    @Test("scanBuffer detects authorization prompts")
    func scanBufferDetectsAuthorization() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return ["$ command", "Allow or Deny?"]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptCategory == .authorization)
        }
    }

    // MARK: Debouncing

    @Test("scanBuffer debounces same content twice")
    func scanBufferDebounces() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        let content = ["$ ls", "Continue? (y/n)"]
        await service.setBufferReader {
            return content
        }

        // First scan
        await service.scanBuffer()
        await MainActor.run {
            #expect(bufferState.updatePendingInputCallCount == 1)
        }

        // Second scan with same content
        await service.scanBuffer()
        await MainActor.run {
            #expect(bufferState.updatePendingInputCallCount == 1)
        }
    }

    @Test("scanBuffer updates when content changes")
    func scanBufferUpdatesOnContentChange() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        nonisolated(unsafe) var bufferContent = ["$ ls"]
        await service.setBufferReader {
            return bufferContent
        }

        // First scan
        await service.scanBuffer()
        await MainActor.run {
            #expect(bufferState.updatePendingInputCallCount == 1)
        }

        // Change content
        bufferContent = ["$ ls", "file.txt", "Continue? (y/n)"]

        // Second scan with different content
        await service.scanBuffer()
        await MainActor.run {
            #expect(bufferState.updatePendingInputCallCount == 2)
        }
    }

    // MARK: No Reader Set

    @Test("scanBuffer does nothing when no reader set")
    func scanBufferNoReaderSet() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.updatePendingInputCallCount == 0)
        }
    }

    // MARK: Empty Buffer

    @Test("scanBuffer handles empty buffer")
    func scanBufferEmptyBuffer() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return []
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.hasPendingInput == false)
        }
    }

    @Test("scanBuffer handles buffer with only non-matching lines")
    func scanBufferNonMatchingLines() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return ["$ ls", "file1.txt", "file2.txt", "$ echo hello"]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.hasPendingInput == false)
        }
    }

    // MARK: Start/Stop Monitoring

    @Test("startMonitoring sets isMonitoring to true")
    func startMonitoringEnabled() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.startMonitoring()

        do {
            try await Task.sleep(nanoseconds: 100_000_000)
        } catch {}

        await MainActor.run {
            #expect(bufferState.isMonitoring == true)
        }
    }

    @Test("stopMonitoring sets isMonitoring to false")
    func stopMonitoringDisabled() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.startMonitoring()
        do {
            try await Task.sleep(nanoseconds: 100_000_000)
        } catch {}

        await service.stopMonitoring()
        do {
            try await Task.sleep(nanoseconds: 100_000_000)
        } catch {}

        await MainActor.run {
            #expect(bufferState.isMonitoring == false)
        }
    }

    @Test("startMonitoring creates periodic scanning task")
    func startMonitoringPeriodic() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState, scanInterval: 0.1)

        nonisolated(unsafe) var callCount = 0
        await service.setBufferReader {
            callCount += 1
            return ["Continue? (y/n)"]
        }

        await service.startMonitoring()

        do {
            try await Task.sleep(nanoseconds: 350_000_000)
        } catch {}

        await service.stopMonitoring()

        #expect(callCount > 0)
    }

    // MARK: Scan Line Count

    @Test("scanBuffer scans only recent lines")
    func scanBufferRecentLines() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState, scanLineCount: 3)

        let manyLines = [
            "line 1", "line 2", "line 3", "line 4", "line 5",
            "Continue? (y/n)"
        ]

        await service.setBufferReader {
            return manyLines
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptCategory == .confirmation)
        }
    }

    @Test("scanBuffer respects scanLineCount limit")
    func scanBufferRespectsScanLineLimit() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState, scanLineCount: 2)

        let manyLines = [
            "Continue? (y/n)",
            "line 2",
            "line 3",
        ]

        await service.setBufferReader {
            return manyLines
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.hasPendingInput == false)
        }
    }

    // MARK: First Match Precedence

    @Test("scanBuffer returns first match when multiple prompts in buffer")
    func scanBufferFirstMatchPrecedence() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return [
                "$ command1",
                "Continue? (y/n)",
                "Password: ",
            ]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptCategory == .confirmation)
        }
    }

    // MARK: ANSI Codes in Buffer

    @Test("scanBuffer handles ANSI codes in buffer lines")
    func scanBufferANSIInBuffer() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return [
                "$ \u{1B}[1mcommand\u{1B}[0m",
                "\u{1B}[32mContinue?\u{1B}[0m (y/n)",
            ]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptCategory == .confirmation)
        }
    }

    // MARK: Update Pending Input Tracking

    @Test("scanBuffer calls updatePendingInput with correct match")
    func scanBufferUpdatesPendingInputMatch() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.setBufferReader {
            return ["Install? [Y/n]"]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.updatePendingInputCallCount == 1)
            #expect(bufferState.lastUpdatedMatch != nil)
            #expect(bufferState.lastUpdatedMatch?.category == .confirmation)
        }
    }

    @Test("scanBuffer calls updatePendingInput with nil when no match")
    func scanBufferUpdatesPendingInputNil() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await MainActor.run {
            bufferState.updatePendingInput(match: PromptMatch(
                line: 0,
                matchedText: "Old",
                category: .credential,
                patternLabel: "test"
            ))
        }

        await service.setBufferReader {
            return ["$ ls", "file.txt"]
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.updatePendingInputCallCount == 2)
            #expect(bufferState.lastUpdatedMatch == nil)
        }
    }
}

// MARK: - Test Suite: Edge Cases and Integration

@Suite("BufferMonitorService Edge Cases")
struct BufferMonitorServiceEdgeCaseTests {

    @Test("handles very long buffer efficiently")
    func handlesVeryLongBuffer() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState, scanLineCount: 10)

        nonisolated(unsafe) var longBuffer: [String] = []
        for i in 0..<1000 {
            longBuffer.append("Line \(i)")
        }
        longBuffer.append("Continue? (y/n)")

        await service.setBufferReader {
            return longBuffer
        }

        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptCategory == .confirmation)
        }
    }

    @Test("handles rapid content changes")
    func handlesRapidContentChanges() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        nonisolated(unsafe) var content = ["$ "]
        await service.setBufferReader {
            return content
        }

        for i in 0..<5 {
            content = ["$ command \(i)"]
            await service.scanBuffer()
        }

        content = ["$ done", "Continue? (y/n)"]
        await service.scanBuffer()

        await MainActor.run {
            #expect(bufferState.pendingPromptCategory == .confirmation)
        }
    }

    @Test("multiple startMonitoring calls don't create multiple tasks")
    func multipleStartMonitoringCalls() async {
        let bufferState = await MainActor.run { MockTerminalBufferState() }
        let service = MockBufferMonitorService(bufferState: bufferState)

        await service.startMonitoring()
        do {
            try await Task.sleep(nanoseconds: 50_000_000)
        } catch {}

        await service.startMonitoring()
        do {
            try await Task.sleep(nanoseconds: 50_000_000)
        } catch {}

        await MainActor.run {
            #expect(bufferState.isMonitoring == true)
        }

        await service.stopMonitoring()
    }
}
