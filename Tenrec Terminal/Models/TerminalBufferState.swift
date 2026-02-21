import Foundation
import Observation

/// Observable state published by BufferMonitorService, consumed by ViewModels.
@Observable
@MainActor
final class TerminalBufferState {
    var hasPendingInput: Bool = false
    var pendingPromptText: String? = nil
    var pendingPromptCategory: PromptCategory? = nil
    var lastCommand: CommandRecord? = nil
    var commandHistory: [CommandRecord] = []
    var isMonitoring: Bool = false

    /// Maximum number of commands to retain in history.
    private let historyLimit = 100

    func recordCommand(_ command: CommandRecord) {
        commandHistory.insert(command, at: 0)
        if commandHistory.count > historyLimit {
            commandHistory.removeLast()
        }
        lastCommand = command
    }

    func updatePendingInput(match: PromptMatch?) {
        if let match {
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
        hasPendingInput = false
        pendingPromptText = nil
        pendingPromptCategory = nil
        lastCommand = nil
        commandHistory = []
        isMonitoring = false
    }
}
