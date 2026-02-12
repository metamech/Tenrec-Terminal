//
//  Tenrec_TerminalTests.swift
//  Tenrec TerminalTests
//
//  Created by Iain Shigeoka on 2/11/26.
//

import Foundation
import Testing
@testable import Tenrec_Terminal

struct Tenrec_TerminalTests {

    @Test func testProcessExecution() async throws {
        let output = ShellExecutionPoC.testProcessExecution()
        #expect(output == "Hello from shell", "Process execution should succeed and return expected output")
    }

    @Test func testPTYAllocation() async throws {
        let ptyAllocated = ShellExecutionPoC.testPTYAllocation()
        #expect(ptyAllocated, "PTY allocation should succeed with sandbox disabled")
    }

    @Test func testTerminalSessionCreation() async throws {
        let session = TerminalSession(name: "Test Session", workingDirectory: "/tmp")
        #expect(session.name == "Test Session")
        #expect(session.workingDirectory == "/tmp")
        #expect(session.status == .active)
    }

    @Test func testTerminalSessionDefaults() async throws {
        let session = TerminalSession(name: "Default")
        #expect(session.workingDirectory == "~")
        #expect(session.status == .active)
        #expect(session.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

}
