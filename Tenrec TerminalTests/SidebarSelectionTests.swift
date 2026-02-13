import Foundation
import Testing
@testable import Tenrec_Terminal

struct SidebarSelectionTests {

    @Test func testTerminalCaseEquality() async throws {
        let id = UUID()
        let selection1 = SidebarSelection.terminal(id)
        let selection2 = SidebarSelection.terminal(id)
        #expect(selection1 == selection2)
    }

    @Test func testPromptCaseEquality() async throws {
        let selection1 = SidebarSelection.prompt("Test")
        let selection2 = SidebarSelection.prompt("Test")
        #expect(selection1 == selection2)
    }

    @Test func testTemplateCaseEquality() async throws {
        let selection1 = SidebarSelection.template("Test")
        let selection2 = SidebarSelection.template("Test")
        #expect(selection1 == selection2)
    }

    @Test func testCrossCaseInequality() async throws {
        let id = UUID()
        let terminal = SidebarSelection.terminal(id)
        let prompt = SidebarSelection.prompt("Test")
        let template = SidebarSelection.template("Test")

        #expect(terminal != prompt)
        #expect(terminal != template)
        #expect(prompt != template)
    }

    @Test func testHashability() async throws {
        let id = UUID()
        let selection1 = SidebarSelection.terminal(id)
        let selection2 = SidebarSelection.prompt("Test")
        let selection3 = SidebarSelection.template("Test")

        var set = Set<SidebarSelection>()
        set.insert(selection1)
        set.insert(selection2)
        set.insert(selection3)

        #expect(set.count == 3)
        #expect(set.contains(selection1))
        #expect(set.contains(selection2))
        #expect(set.contains(selection3))
    }
}
