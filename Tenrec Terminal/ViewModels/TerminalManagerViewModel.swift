import Foundation
import Observation
import SwiftData
import SwiftTerm

@Observable
class TerminalManagerViewModel {
    private let modelContext: ModelContext

    var activeSessionId: UUID?

    /// Sessions that currently have a detected prompt awaiting user input.
    /// Updated by the Coordinator as BufferMonitorService emits state changes.
    var sessionsPendingInput: Set<UUID> = []

    // Search state — read by ContentPaneView to update match count
    var lastSearchText: String = ""

    // Weak reference to the active terminal view for search operations.
    // This is set by TerminalContainerView.Coordinator when the active view changes.
    weak var activeTerminalView: LocalProcessTerminalView?

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

    /// Sets the color tag for a session.
    func setColorTag(id: UUID, tag: String?) {
        let allSessions = fetchAllSessions()
        if let session = allSessions.first(where: { $0.id == id }) {
            session.colorTag = tag
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

    // MARK: - Profile Resolution

    /// Returns the TerminalProfile for a session, falling back to the first built-in.
    func resolveProfile(for session: TerminalSession) -> TerminalProfile? {
        let descriptor = FetchDescriptor<TerminalProfile>()
        let allProfiles = (try? modelContext.fetch(descriptor)) ?? []

        if let pid = session.profileId,
           let match = allProfiles.first(where: { $0.id == pid }) {
            return match
        }
        // Fall back to the first built-in, then any profile
        return allProfiles.first(where: { $0.isBuiltIn }) ?? allProfiles.first
    }

    // MARK: - Search

    /// Finds and selects the next occurrence of text in the active terminal view.
    func searchNext(text: String) {
        guard !text.isEmpty, let view = activeTerminalView else { return }
        lastSearchText = text
        let opts = SearchOptions()
        view.findNext(text, options: opts)
    }

    /// Finds and selects the previous occurrence of text in the active terminal view.
    func searchPrevious(text: String) {
        guard !text.isEmpty, let view = activeTerminalView else { return }
        lastSearchText = text
        let opts = SearchOptions()
        view.findPrevious(text, options: opts)
    }

    /// Clears the current search state in the active terminal view.
    func clearSearch() {
        activeTerminalView?.clearSearch()
        lastSearchText = ""
    }

    // MARK: - Private Helpers

    /// Returns every session regardless of status. Used for name uniqueness checks.
    private func fetchAllSessions() -> [TerminalSession] {
        let descriptor = FetchDescriptor<TerminalSession>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
