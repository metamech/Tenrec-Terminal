import Foundation

// MARK: - Event type

/// Events emitted by the shell integration service when OSC 133 sequences are parsed.
enum ShellIntegrationEvent: Sendable {
    /// ESC ] 133 ; A ST — shell drew the prompt
    case promptStarted
    /// ESC ] 133 ; B ST — user submitted a command (Enter pressed)
    case commandStarted
    /// ESC ] 133 ; C ST — command output is beginning
    case commandOutputStarted
    /// ESC ] 133 ; D ; <exitcode> ST — command finished
    case commandFinished(exitCode: Int32)
}

// MARK: - Service

/// Parses OSC 133 sequences from raw terminal byte streams to detect command boundaries.
///
/// OSC 133 is the FinalTerm / iTerm2 shell integration protocol:
///
///   ESC ] 133 ; A ST   — prompt start
///   ESC ] 133 ; B ST   — command start (user pressed Enter)
///   ESC ] 133 ; C ST   — command output start
///   ESC ] 133 ; D ; N ST — command finished with exit code N
///
/// String Terminator (ST) may be BEL (\x07) or ESC \ (\x1B\x5C).
///
/// Feed raw terminal data via `processData(_:)`. Sequences that span multiple data
/// chunks are buffered internally. Events are dispatched to the registered handler
/// on the main actor.
actor ShellIntegrationService {

    // MARK: Public state

    /// Maximum number of ``CommandRecord`` entries kept in ``commandHistory``.
    let historyLimit: Int

    // MARK: Private state

    /// Callback dispatched on `@MainActor` when an OSC 133 event is detected.
    private var onEvent: (@MainActor @Sendable (ShellIntegrationEvent) -> Void)?

    // -- OSC parsing state --

    /// Bytes accumulated inside an in-progress OSC sequence (after the opening ESC ]).
    private var oscBuffer: [UInt8] = []

    /// Whether the parser is currently inside an OSC sequence body.
    private var inOSC: Bool = false

    /// Intermediate state: we saw an ESC byte but have not yet seen the ] that confirms OSC.
    private var sawESC: Bool = false

    // -- Command timing --

    /// Wall-clock time when the most recent "B" (command start) marker arrived.
    private var commandStartTime: Date?

    /// Text of the command, if captured via a supplementary mechanism (future extension).
    private var currentCommandText: String?

    // -- History --

    private var commandHistory: [CommandRecord] = []

    // MARK: Init

    init(
        historyLimit: Int = 100,
        onEvent: (@MainActor @Sendable (ShellIntegrationEvent) -> Void)? = nil
    ) {
        self.historyLimit = historyLimit
        self.onEvent = onEvent
    }

    // MARK: Public API

    /// Replace the event handler. Safe to call at any time.
    func setEventHandler(
        _ handler: @escaping @MainActor @Sendable (ShellIntegrationEvent) -> Void
    ) {
        onEvent = handler
    }

    /// Feed a slice of raw terminal output bytes into the parser.
    ///
    /// The parser is entirely stateful; call this repeatedly as data arrives.
    /// Sequences that span chunk boundaries are reassembled from the internal buffer.
    func processData(_ data: ArraySlice<UInt8>) {
        for byte in data {
            if inOSC {
                handleByteInsideOSC(byte)
            } else {
                handleByteOutsideOSC(byte)
            }
        }
    }

    /// Convenience overload for `Data`.
    func processData(_ data: Data) {
        processData(data[data.startIndex ..< data.endIndex])
    }

    /// Return a snapshot of the command history (most recent first).
    func getCommandHistory() -> [CommandRecord] {
        commandHistory
    }

    // MARK: - Byte-level parser

    private func handleByteOutsideOSC(_ byte: UInt8) {
        if sawESC {
            sawESC = false
            if byte == 0x5D { // ] — confirmed OSC open
                inOSC = true
                oscBuffer.removeAll(keepingCapacity: true)
            }
            // Any other byte after ESC is unrelated; discard the held ESC.
            return
        }

        if byte == 0x1B { // ESC — may start ESC ]
            sawESC = true
        }
        // All other bytes outside an OSC sequence are passed through unmodified
        // (the terminal emulator, SwiftTerm, handles rendering separately).
    }

    private func handleByteInsideOSC(_ byte: UInt8) {
        // Check for BEL terminator
        if byte == 0x07 {
            flushOSCBuffer()
            return
        }

        // Check for ESC \ (two-byte ST): the ESC arrives first.
        // We detect it by inspecting the last byte already in the buffer.
        if byte == 0x5C && oscBuffer.last == 0x1B {
            oscBuffer.removeLast() // strip the ESC that was buffered
            flushOSCBuffer()
            return
        }

        oscBuffer.append(byte)

        // Safety valve: abandon runaway sequences that will never be valid OSC 133.
        // 256 bytes is generous — a valid "133;D;NNN" sequence is at most ~10 bytes.
        if oscBuffer.count > 256 {
            oscBuffer.removeAll(keepingCapacity: true)
            inOSC = false
        }
    }

    // MARK: - OSC dispatch

    /// Called when a complete OSC body (everything between ESC ] and ST) is ready.
    private func flushOSCBuffer() {
        let body = oscBuffer
        oscBuffer.removeAll(keepingCapacity: true)
        inOSC = false
        processOSCBody(body)
    }

    /// Parse the OSC body and emit the appropriate ``ShellIntegrationEvent``.
    ///
    /// - Parameter body: Raw bytes of the OSC body, e.g. `133;D;0` (no surrounding ESC ] or ST).
    private func processOSCBody(_ body: [UInt8]) {
        guard let str = String(bytes: body, encoding: .utf8) else { return }

        // Expect "133;" prefix
        guard str.hasPrefix("133;") else { return }

        let payload = str.dropFirst(4) // everything after "133;"
        guard let marker = payload.first else { return }

        switch marker {
        case "A":
            emitEvent(.promptStarted)

        case "B":
            commandStartTime = Date()
            emitEvent(.commandStarted)

        case "C":
            emitEvent(.commandOutputStarted)

        case "D":
            let exitCode = parseExitCode(from: payload)
            recordFinishedCommand(exitCode: exitCode)
            emitEvent(.commandFinished(exitCode: exitCode))

        default:
            break // Unknown marker — silently ignore for forward compatibility
        }
    }

    // MARK: - Helpers

    /// Parse the exit code from a "D" payload such as "D;0" or "D;127".
    /// Returns 0 if the code is absent or unparseable.
    private func parseExitCode(from payload: Substring) -> Int32 {
        // payload is e.g. "D" (no code) or "D;0" or "D;127"
        let rest = payload.dropFirst() // drop "D"
        guard rest.first == ";" else { return 0 }
        let codeStr = rest.dropFirst() // drop ";"
        return Int32(codeStr) ?? -1
    }

    /// Append a ``CommandRecord`` to the history ring buffer.
    private func recordFinishedCommand(exitCode: Int32) {
        let record = CommandRecord(
            commandText: currentCommandText,
            exitCode: exitCode,
            startedAt: commandStartTime ?? Date(),
            finishedAt: Date()
        )
        commandHistory.insert(record, at: 0)
        if commandHistory.count > historyLimit {
            commandHistory.removeLast()
        }
        commandStartTime = nil
        currentCommandText = nil
    }

    /// Dispatch `event` to the registered handler on the main actor.
    private func emitEvent(_ event: ShellIntegrationEvent) {
        guard let handler = onEvent else { return }
        Task { @MainActor in
            handler(event)
        }
    }
}
