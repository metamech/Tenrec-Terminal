import Foundation
import Observation
import SwiftData

@Observable
class TerminalSessionViewModel {
    private let session: TerminalSession

    // MARK: - Shell Integration / Buffer State

    /// Observable buffer state published by BufferMonitorService for this session.
    /// Created once and retained for the lifetime of the view model.
    @MainActor
    let bufferState = TerminalBufferState()

    // MARK: - Convenience Accessors (buffer state pass-through)

    /// True when the buffer scanner has detected a prompt awaiting user input.
    @MainActor
    var hasPendingInput: Bool { bufferState.hasPendingInput }

    /// Text of the detected prompt, if any.
    @MainActor
    var pendingPromptText: String? { bufferState.pendingPromptText }

    /// Most recently completed command recorded via shell integration.
    @MainActor
    var lastCommand: CommandRecord? { bufferState.lastCommand }

    init(session: TerminalSession) {
        self.session = session
    }

    // MARK: - Computed Properties

    var title: String {
        get { session.name }
        set { session.name = newValue }
    }

    var workingDirectory: String {
        get { session.workingDirectory }
        set { session.workingDirectory = newValue }
    }

    var isRunning: Bool {
        get { session.status == .active }
    }

    var sessionID: UUID {
        session.id
    }

    // MARK: - Methods for Coordinator

    /// Updates the session title from terminal escape sequences
    func updateTitle(_ newTitle: String) {
        session.name = newTitle
    }

    /// Updates the working directory from terminal reports
    /// Handles URL-format strings (e.g., "file:///Users/name/path") by stripping the file:// prefix
    func updateWorkingDirectory(_ directory: String) {
        let cleanPath = Self.urlToPath(directory)
        session.workingDirectory = cleanPath
    }

    /// Marks the session as terminated when the shell process exits
    func markTerminated() {
        session.status = .terminated
    }

    // MARK: - Helper Methods

    /// Converts a file URL string to a plain filesystem path
    /// - Parameter urlString: URL-format string (e.g., "file:///Users/name/path" or "/plain/path")
    /// - Returns: Plain filesystem path
    static func urlToPath(_ urlString: String) -> String {
        // Handle file:// URL format
        if urlString.hasPrefix("file://") {
            var path = String(urlString.dropFirst(7)) // Remove "file://"

            // Remove hostname if present (e.g., file://hostname/path -> /path)
            if let firstSlash = path.firstIndex(of: "/"), firstSlash != path.startIndex {
                path = String(path[firstSlash...])
            }

            return path
        }

        // Already a plain path
        return urlString
    }
}
