import Foundation

/// Represents a completed command detected via shell integration (OSC 133).
struct CommandRecord: Identifiable, Sendable {
    let id: UUID
    let commandText: String?          // May not always be available
    let exitCode: Int32?
    let startedAt: Date
    let finishedAt: Date?

    var duration: TimeInterval? {
        guard let finishedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }

    init(id: UUID = UUID(), commandText: String? = nil, exitCode: Int32? = nil, startedAt: Date = Date(), finishedAt: Date? = nil) {
        self.id = id
        self.commandText = commandText
        self.exitCode = exitCode
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}
