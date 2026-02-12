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
    var status: SessionStatus
    var workingDirectory: String

    init(name: String, workingDirectory: String = "~") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.status = .active
        self.workingDirectory = workingDirectory
    }
}
