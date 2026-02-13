import Foundation
import Testing
@testable import Tenrec_Terminal

struct SidebarViewModelTests {

    @Test func testDefaultNilSelection() async throws {
        let viewModel = SidebarViewModel()
        #expect(viewModel.selection == nil)
    }

    @Test func testSetAndGetTerminalSelection() async throws {
        let viewModel = SidebarViewModel()
        let id = UUID()
        viewModel.selection = .terminal(id)
        #expect(viewModel.selection == .terminal(id))
    }

    @Test func testSetAndGetPromptSelection() async throws {
        let viewModel = SidebarViewModel()
        viewModel.selection = .prompt("Test Prompt")
        #expect(viewModel.selection == .prompt("Test Prompt"))
    }

    @Test func testSetAndGetTemplateSelection() async throws {
        let viewModel = SidebarViewModel()
        viewModel.selection = .template("Test Template")
        #expect(viewModel.selection == .template("Test Template"))
    }

    @Test func testPlaceholderPrompts() async throws {
        let viewModel = SidebarViewModel()
        #expect(viewModel.prompts.count == 2)
        #expect(viewModel.prompts.contains("Default Prompt"))
        #expect(viewModel.prompts.contains("Minimal Prompt"))
    }

    @Test func testPlaceholderTemplates() async throws {
        let viewModel = SidebarViewModel()
        #expect(viewModel.templates.count == 2)
        #expect(viewModel.templates.contains("SSH Remote"))
        #expect(viewModel.templates.contains("Development"))
    }
}
