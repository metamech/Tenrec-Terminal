import Foundation
import SwiftData

enum SessionStatus: String, Codable {
    case active
    case inactive
    case terminated
}

@Model
final class TerminalSession {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastActiveAt: Date = Date()
    var status: SessionStatus
    var workingDirectory: String
    var colorTag: String?

    init(name: String, workingDirectory: String = "~") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.status = .active
        self.workingDirectory = workingDirectory
        self.colorTag = nil
    }
}
