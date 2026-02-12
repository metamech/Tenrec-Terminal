//
//  Tenrec_TerminalTests.swift
//  Tenrec TerminalTests
//
//  Created by Iain Shigeoka on 2/11/26.
//

import Testing
@testable import Tenrec_Terminal

struct Tenrec_TerminalTests {

    @Test func testProcessExecution() async throws {
        // Validate that Process execution works (sandbox disabled)
        let output = ShellExecutionPoC.testProcessExecution()
        #expect(output == "Hello from shell", "Process execution should succeed and return expected output")
    }

    @Test func testPTYAllocation() async throws {
        // Validate that PTY allocation works (sandbox disabled)
        let ptyAllocated = ShellExecutionPoC.testPTYAllocation()
        #expect(ptyAllocated, "PTY allocation should succeed with sandbox disabled")
    }

}
