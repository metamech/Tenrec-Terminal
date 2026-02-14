import Foundation
import Testing
@testable import Tenrec_Terminal

struct TerminalSessionViewModelTests {

    @Test func testInitFromSession() async throws {
        let session = TerminalSession(name: "Test Terminal", workingDirectory: "/tmp")
        let viewModel = TerminalSessionViewModel(session: session)

        #expect(viewModel.title == "Test Terminal")
        #expect(viewModel.workingDirectory == "/tmp")
        #expect(viewModel.isRunning == true)
        #expect(viewModel.sessionID == session.id)
    }

    @Test func testTitleWriteThrough() async throws {
        let session = TerminalSession(name: "Original Title")
        let viewModel = TerminalSessionViewModel(session: session)

        viewModel.updateTitle("New Title")
        #expect(viewModel.title == "New Title")
        #expect(session.name == "New Title")
    }

    @Test func testWorkingDirectoryWriteThrough() async throws {
        let session = TerminalSession(name: "Test", workingDirectory: "/home")
        let viewModel = TerminalSessionViewModel(session: session)

        viewModel.updateWorkingDirectory("/usr/local")
        #expect(viewModel.workingDirectory == "/usr/local")
        #expect(session.workingDirectory == "/usr/local")
    }

    @Test func testMarkTerminated() async throws {
        let session = TerminalSession(name: "Test")
        let viewModel = TerminalSessionViewModel(session: session)

        #expect(viewModel.isRunning == true)
        #expect(session.status == .active)

        viewModel.markTerminated()
        #expect(viewModel.isRunning == false)
        #expect(session.status == .terminated)
    }

    @Test func testUrlToPathConversion() async throws {
        // Test file:// URL format
        let fileUrl = "file:///Users/ion/Documents"
        #expect(TerminalSessionViewModel.urlToPath(fileUrl) == "/Users/ion/Documents")

        // Test file:// with hostname
        let urlWithHost = "file://localhost/Users/ion/Documents"
        #expect(TerminalSessionViewModel.urlToPath(urlWithHost) == "/Users/ion/Documents")

        // Test plain path (no conversion needed)
        let plainPath = "/Users/ion/Documents"
        #expect(TerminalSessionViewModel.urlToPath(plainPath) == "/Users/ion/Documents")
    }

    @Test func testUpdateWorkingDirectoryWithUrl() async throws {
        let session = TerminalSession(name: "Test", workingDirectory: "~")
        let viewModel = TerminalSessionViewModel(session: session)

        // SwiftTerm sends file:// format
        viewModel.updateWorkingDirectory("file:///tmp")
        #expect(viewModel.workingDirectory == "/tmp")
        #expect(session.workingDirectory == "/tmp")
    }
}
