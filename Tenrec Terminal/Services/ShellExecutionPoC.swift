import Foundation

/// Proof of concept for shell execution and PTY allocation.
/// Validates that the app sandbox has been properly disabled.
enum ShellExecutionPoC {
    /// Test Process execution by running a simple shell command.
    /// Returns the command output if successful.
    static func testProcessExecution() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "echo 'Hello from shell'"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Test PTY allocation by calling posix_openpt, grantpt, and unlockpt.
    /// Returns true if PTY allocation succeeds, false otherwise.
    static func testPTYAllocation() -> Bool {
        // Attempt to allocate a PTY master
        let masterFD = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterFD >= 0 else {
            return false
        }

        defer { close(masterFD) }

        // Grant access to the slave side
        guard grantpt(masterFD) == 0 else {
            return false
        }

        // Unlock the slave side
        guard unlockpt(masterFD) == 0 else {
            return false
        }

        return true
    }
}
