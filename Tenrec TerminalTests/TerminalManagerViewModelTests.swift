import Foundation
import Testing
import SwiftData
@testable import Tenrec_Terminal

// MARK: - Helpers

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([TerminalSession.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

// MARK: - Test Suite

@Suite("TerminalManagerViewModel")
struct TerminalManagerViewModelTests {

    // MARK: createSession

    @Test("createSession produces sequential names starting at Terminal 1")
    func createSessionSequentialNames() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        let s1 = vm.createSession()
        let s2 = vm.createSession()
        let s3 = vm.createSession()

        #expect(s1.name == "Terminal 1")
        #expect(s2.name == "Terminal 2")
        #expect(s3.name == "Terminal 3")
    }

    @Test("createSession fills gaps in numbering")
    func createSessionFillsGaps() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        // Insert sessions manually with specific names to simulate a gap.
        let s1 = TerminalSession(name: "Terminal 1")
        let s3 = TerminalSession(name: "Terminal 3")
        context.insert(s1)
        context.insert(s3)

        let next = vm.createSession()
        #expect(next.name == "Terminal 2")
    }

    // MARK: closeSession

    @Test("closeSession marks session as terminated")
    func closeSessionSetsTerminated() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        let s1 = vm.createSession()
        vm.closeSession(id: s1.id)

        #expect(s1.status == .terminated)
    }

    @Test("closeSession on active session selects adjacent session")
    func closeActiveSessionSelectsAdjacent() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        let s1 = vm.createSession()
        let s2 = vm.createSession()

        // Make s2 lastActiveAt slightly later so fetchSessions returns [s2, s1].
        s2.lastActiveAt = s1.lastActiveAt.addingTimeInterval(1)

        vm.activeSessionId = s2.id
        vm.closeSession(id: s2.id)

        // After closing s2 (index 0 in sorted list), s1 should be selected.
        #expect(vm.activeSessionId == s1.id)
    }

    @Test("closeSession on the only session sets activeSessionId to nil")
    func closeOnlySessionSetsNilActiveId() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        let s1 = vm.createSession()
        vm.activeSessionId = s1.id
        vm.closeSession(id: s1.id)

        #expect(vm.activeSessionId == nil)
    }

    // MARK: switchToSession

    @Test("switchToSession updates activeSessionId and lastActiveAt")
    func switchToSessionUpdatesState() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        let s1 = vm.createSession()
        let s2 = vm.createSession()

        let beforeSwitch = s2.lastActiveAt
        // Small sleep to ensure Date() advances.
        Thread.sleep(forTimeInterval: 0.01)

        vm.switchToSession(id: s2.id)

        #expect(vm.activeSessionId == s2.id)
        #expect(s2.lastActiveAt > beforeSwitch)
        // s1 should be unaffected.
        #expect(vm.activeSessionId != s1.id)
    }

    // MARK: renameSession

    @Test("renameSession persists new name to model")
    func renameSessionPersists() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        let s1 = vm.createSession()
        vm.renameSession(id: s1.id, name: "My Custom Shell")

        #expect(s1.name == "My Custom Shell")
    }

    // MARK: fetchSessions

    @Test("fetchSessions excludes terminated sessions and sorts by lastActiveAt descending")
    func fetchSessionsOrderAndFilter() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        let s1 = vm.createSession()
        let s2 = vm.createSession()
        let s3 = vm.createSession()

        // Assign distinct lastActiveAt values.
        let base = Date()
        s1.lastActiveAt = base
        s2.lastActiveAt = base.addingTimeInterval(2)
        s3.lastActiveAt = base.addingTimeInterval(1)

        // Terminate s1.
        vm.closeSession(id: s1.id)

        let results = vm.fetchSessions()

        // s1 should be excluded; remaining are s2, s3 sorted descending by lastActiveAt.
        #expect(results.count == 2)
        #expect(results[0].id == s2.id)
        #expect(results[1].id == s3.id)
    }

    // MARK: sessionCount

    @Test("sessionCount reflects only non-terminated sessions")
    func sessionCountExcludesTerminated() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalManagerViewModel(modelContext: context)

        let s1 = vm.createSession()
        _ = vm.createSession()

        #expect(vm.sessionCount == 2)

        vm.closeSession(id: s1.id)

        #expect(vm.sessionCount == 1)
    }
}
