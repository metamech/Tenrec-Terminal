import Foundation
import Observation
import SwiftData

@Observable
class TerminalManagerViewModel {
    private let modelContext: ModelContext
    var activeSessionId: UUID?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Computed Properties

    /// Count of non-terminated sessions.
    var sessionCount: Int {
        fetchSessions().count
    }

    // MARK: - Session Management

    /// Creates a new session with an auto-generated sequential name.
    /// Fills gaps: if "Terminal 1" and "Terminal 3" exist, next is "Terminal 2".
    @discardableResult
    func createSession() -> TerminalSession {
        let existingNames = Set(fetchAllSessions().map { $0.name })
        var number = 1
        while existingNames.contains("Terminal \(number)") {
            number += 1
        }
        let session = TerminalSession(name: "Terminal \(number)")
        modelContext.insert(session)
        return session
    }

    /// Marks the session as terminated. If it was the active session, selects
    /// the adjacent session in the sorted list (next, or previous if last).
    func closeSession(id: UUID) {
        let sessions = fetchSessions()
        guard let session = sessions.first(where: { $0.id == id }) else { return }

        let wasActive = activeSessionId == id
        session.status = .terminated

        if wasActive {
            // Sessions still available after termination (exclude the closing one).
            let remaining = sessions.filter { $0.id != id }
            if remaining.isEmpty {
                activeSessionId = nil
            } else if let currentIndex = sessions.firstIndex(where: { $0.id == id }) {
                // Prefer the session at the same index (next); fall back to previous.
                let nextIndex = currentIndex < remaining.count ? currentIndex : remaining.count - 1
                activeSessionId = remaining[nextIndex].id
            } else {
                activeSessionId = remaining.first?.id
            }
        }
    }

    /// Updates activeSessionId and touches lastActiveAt on the target session.
    func switchToSession(id: UUID) {
        activeSessionId = id
        let allSessions = fetchAllSessions()
        if let session = allSessions.first(where: { $0.id == id }) {
            session.lastActiveAt = Date()
        }
    }

    /// Renames a session by id.
    func renameSession(id: UUID, name: String) {
        let allSessions = fetchAllSessions()
        if let session = allSessions.first(where: { $0.id == id }) {
            session.name = name
        }
    }

    /// Returns all non-terminated sessions sorted by lastActiveAt descending.
    func fetchSessions() -> [TerminalSession] {
        let descriptor = FetchDescriptor<TerminalSession>(
            sortBy: [SortDescriptor(\.lastActiveAt, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.status != .terminated }
    }

    // MARK: - Private Helpers

    /// Returns every session regardless of status. Used for name uniqueness checks.
    private func fetchAllSessions() -> [TerminalSession] {
        let descriptor = FetchDescriptor<TerminalSession>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
