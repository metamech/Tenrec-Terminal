import Foundation
import Testing
@testable import Tenrec_Terminal

// MARK: - Helpers

/// Build a raw OSC 133 sequence terminated by BEL.
/// e.g. makeOSC133BEL("A") → ESC ] 1 3 3 ; A BEL
private func makeOSC133BEL(_ params: String) -> [UInt8] {
    var bytes: [UInt8] = [0x1B, 0x5D] // ESC ]
    bytes += Array("133;\(params)".utf8)
    bytes.append(0x07) // BEL
    return bytes
}

/// Build a raw OSC 133 sequence terminated by ESC \.
private func makeOSC133ESCBackslash(_ params: String) -> [UInt8] {
    var bytes: [UInt8] = [0x1B, 0x5D] // ESC ]
    bytes += Array("133;\(params)".utf8)
    bytes += [0x1B, 0x5C] // ESC \
    return bytes
}

// MARK: - Test suite

@Suite("ShellIntegrationService")
struct ShellIntegrationServiceTests {

    // MARK: Basic event detection — BEL terminator

    @Test("Detects promptStarted from 133;A with BEL")
    func detectPromptStartedBEL() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let bytes = makeOSC133BEL("A")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])

        // Give the Task { @MainActor } dispatch a chance to run
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .promptStarted = events.first { } else {
            Issue.record("Expected .promptStarted, got \(String(describing: events.first))")
        }
    }

    @Test("Detects commandStarted from 133;B with BEL")
    func detectCommandStartedBEL() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let bytes = makeOSC133BEL("B")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .commandStarted = events.first { } else {
            Issue.record("Expected .commandStarted, got \(String(describing: events.first))")
        }
    }

    @Test("Detects commandOutputStarted from 133;C with BEL")
    func detectCommandOutputStartedBEL() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let bytes = makeOSC133BEL("C")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .commandOutputStarted = events.first { } else {
            Issue.record("Expected .commandOutputStarted, got \(String(describing: events.first))")
        }
    }

    @Test("Detects commandFinished with exit code 0 from 133;D;0 with BEL")
    func detectCommandFinishedExitZeroBEL() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let bytes = makeOSC133BEL("D;0")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .commandFinished(let code) = events.first {
            #expect(code == 0)
        } else {
            Issue.record("Expected .commandFinished(exitCode: 0), got \(String(describing: events.first))")
        }
    }

    @Test("Detects commandFinished with exit code 127 from 133;D;127 with BEL")
    func detectCommandFinishedExitNonZeroBEL() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let bytes = makeOSC133BEL("D;127")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .commandFinished(let code) = events.first {
            #expect(code == 127)
        } else {
            Issue.record("Expected .commandFinished(exitCode: 127)")
        }
    }

    // MARK: ESC \ terminator

    @Test("Detects promptStarted from 133;A terminated by ESC backslash")
    func detectPromptStartedESCBackslash() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let bytes = makeOSC133ESCBackslash("A")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .promptStarted = events.first { } else {
            Issue.record("Expected .promptStarted via ESC \\")
        }
    }

    @Test("Detects commandFinished via ESC backslash terminator")
    func detectCommandFinishedESCBackslash() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let bytes = makeOSC133ESCBackslash("D;1")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .commandFinished(let code) = events.first {
            #expect(code == 1)
        } else {
            Issue.record("Expected .commandFinished(exitCode: 1)")
        }
    }

    // MARK: Chunked / split delivery

    @Test("Handles sequences split across multiple processData calls")
    func splitSequenceReassembly() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        // Split "ESC ] 133 ; A BEL" into three separate chunks
        let full = makeOSC133BEL("A")
        let chunk1 = full[full.startIndex ..< full.startIndex + 3] // ESC ] 1
        let chunk2 = full[full.startIndex + 3 ..< full.startIndex + 5] // 3 3
        let chunk3 = full[full.startIndex + 5 ..< full.endIndex]       // ; A BEL

        await service.processData(chunk1)
        await service.processData(chunk2)
        await service.processData(chunk3)
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .promptStarted = events.first { } else {
            Issue.record("Expected .promptStarted from reassembled chunks")
        }
    }

    @Test("Handles sequence split right before BEL terminator")
    func splitAtBEL() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let full = makeOSC133BEL("B")
        let body = full[full.startIndex ..< full.endIndex - 1]    // everything before BEL
        let bel  = full[full.endIndex - 1 ..< full.endIndex]      // just BEL

        await service.processData(body)
        await service.processData(bel)
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .commandStarted = events.first { } else {
            Issue.record("Expected .commandStarted when BEL arrives in a separate chunk")
        }
    }

    @Test("Handles ESC backslash ST split between chunks")
    func splitESCBackslash() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let full = makeOSC133ESCBackslash("C")
        // Deliver everything except the final \ in the first chunk
        let body = full[full.startIndex ..< full.endIndex - 1]
        let tail = full[full.endIndex - 1 ..< full.endIndex] // just 0x5C

        await service.processData(body)
        await service.processData(tail)
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .commandOutputStarted = events.first { } else {
            Issue.record("Expected .commandOutputStarted when ESC \\ spans chunks")
        }
    }

    // MARK: Safety / edge cases

    @Test("Ignores non-133 OSC sequences")
    func ignoresNon133OSC() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        // OSC 0 (set window title) — should be silently ignored
        var bytes: [UInt8] = [0x1B, 0x5D]
        bytes += Array("0;Window Title".utf8)
        bytes.append(0x07)
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.isEmpty)
    }

    @Test("Abandons sequences exceeding 256-byte buffer limit")
    func bufferSafetyLimit() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        // Open an OSC sequence then flood with 300 junk bytes (no terminator)
        var bytes: [UInt8] = [0x1B, 0x5D]
        bytes += [UInt8](repeating: 0x41, count: 300) // 300 × 'A'
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])

        // Now send a real OSC 133 A — the service should have recovered and parsed it
        let good = makeOSC133BEL("A")
        await service.processData(good[good.startIndex ..< good.endIndex])
        await Task.yield()
        await Task.yield()

        // The runaway sequence is discarded; the subsequent valid sequence fires one event
        #expect(events.count == 1)
        if case .promptStarted = events.first { } else {
            Issue.record("Expected .promptStarted after recovering from runaway buffer")
        }
    }

    @Test("Ignores unrecognised 133 marker letters")
    func ignoresUnknownMarker() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        // 133;Z is not a known marker
        let bytes = makeOSC133BEL("Z;some-payload")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.isEmpty)
    }

    @Test("Handles 133;D without exit code, defaults to 0")
    func commandFinishedNoExitCode() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        let bytes = makeOSC133BEL("D")
        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .commandFinished(let code) = events.first {
            #expect(code == 0)
        } else {
            Issue.record("Expected .commandFinished(exitCode: 0) when no code is present")
        }
    }

    // MARK: Command history

    @Test("Records finished commands in history")
    func commandHistoryRecorded() async {
        let service = ShellIntegrationService()

        // Simulate B → C → D sequence
        let seqB = makeOSC133BEL("B")
        let seqC = makeOSC133BEL("C")
        let seqD = makeOSC133BEL("D;0")

        await service.processData(seqB[seqB.startIndex ..< seqB.endIndex])
        await service.processData(seqC[seqC.startIndex ..< seqC.endIndex])
        await service.processData(seqD[seqD.startIndex ..< seqD.endIndex])

        let history = await service.getCommandHistory()
        #expect(history.count == 1)
        #expect(history[0].exitCode == 0)
    }

    @Test("History is ordered most recent first")
    func commandHistoryOrdering() async {
        let service = ShellIntegrationService()

        for code in [0, 1, 2] as [Int32] {
            let seqB = makeOSC133BEL("B")
            let seqD = makeOSC133BEL("D;\(code)")
            await service.processData(seqB[seqB.startIndex ..< seqB.endIndex])
            await service.processData(seqD[seqD.startIndex ..< seqD.endIndex])
        }

        let history = await service.getCommandHistory()
        #expect(history.count == 3)
        // Most recent first
        #expect(history[0].exitCode == 2)
        #expect(history[1].exitCode == 1)
        #expect(history[2].exitCode == 0)
    }

    @Test("History is capped at historyLimit")
    func commandHistoryLimit() async {
        let limit = 5
        let service = ShellIntegrationService(historyLimit: limit)

        for i in 0 ..< (limit + 3) {
            let seqD = makeOSC133BEL("D;\(i)")
            await service.processData(seqD[seqD.startIndex ..< seqD.endIndex])
        }

        let history = await service.getCommandHistory()
        #expect(history.count == limit)
    }

    // MARK: Mixed data (OSC embedded in normal terminal output)

    @Test("Parses OSC 133 embedded among regular terminal bytes")
    func embeddedInNormalOutput() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        // Regular output bytes before and after the sequence
        var bytes: [UInt8] = Array("hello ".utf8)
        bytes += makeOSC133BEL("A")
        bytes += Array(" world".utf8)

        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 1)
        if case .promptStarted = events.first { } else {
            Issue.record("Expected .promptStarted embedded in normal output")
        }
    }

    @Test("Multiple OSC 133 sequences in one data chunk")
    func multipleSequencesInOneChunk() async {
        var events: [ShellIntegrationEvent] = []
        let service = ShellIntegrationService()
        await service.setEventHandler { @MainActor event in
            events.append(event)
        }

        var bytes = makeOSC133BEL("A")
        bytes += makeOSC133BEL("B")
        bytes += makeOSC133BEL("C")

        await service.processData(bytes[bytes.startIndex ..< bytes.endIndex])
        await Task.yield()
        await Task.yield()

        #expect(events.count == 3)
    }
}
