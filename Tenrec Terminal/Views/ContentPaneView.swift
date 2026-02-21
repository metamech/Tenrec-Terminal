import SwiftUI
import SwiftData
import SwiftTerm

// MARK: - ContentPaneView

struct ContentPaneView: View {
    let selection: SidebarSelection?
    let terminalManager: TerminalManagerViewModel

    var body: some View {
        Group {
            switch selection {
            case .terminal:
                // The container manages all terminal views. It always fills the space
                // and uses show/hide to switch between cached PTY instances.
                TerminalContainerView(terminalManager: terminalManager)

            case .prompt(let name):
                VStack {
                    Text("Prompt Content")
                        .font(.title)
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .template(let name):
                VStack {
                    Text("Template Content")
                        .font(.title)
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case nil:
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.left",
                    description: Text("Select an item from the sidebar")
                )
            }
        }
        .navigationTitle("Content")
    }
}

// MARK: - TerminalContainerView

/// An NSViewRepresentable that owns a cache of `LocalProcessTerminalView` instances,
/// one per session UUID. Switching sessions shows/hides NSViews rather than
/// recreating them, keeping PTY processes alive across selection changes.
struct TerminalContainerView: NSViewRepresentable {
    let terminalManager: TerminalManagerViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        context.coordinator.container = container
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        guard let activeID = terminalManager.activeSessionId else {
            // No active session — hide all views
            coordinator.terminalViews.values.forEach { $0.terminalView.isHidden = true }
            return
        }

        let sessions = terminalManager.fetchSessions()

        // Create a terminal view for the active session if it doesn't exist yet
        if coordinator.terminalViews[activeID] == nil {
            if let session = sessions.first(where: { $0.id == activeID }) {
                coordinator.createTerminalView(for: session, in: nsView)
            }
        }

        // Show the active view, hide all others; make it fill the container
        for (id, entry) in coordinator.terminalViews {
            let isActive = (id == activeID)
            entry.terminalView.isHidden = !isActive
            if isActive {
                entry.terminalView.frame = nsView.bounds
                entry.terminalView.autoresizingMask = [.width, .height]
                // Restore first-responder focus to the terminal when switching back
                DispatchQueue.main.async {
                    entry.terminalView.window?.makeFirstResponder(entry.terminalView)
                }
            }
        }

        // Remove cached views for sessions that are now terminated / no longer fetched
        let liveIDs = Set(sessions.map { $0.id })
        let staleIDs = coordinator.terminalViews.keys.filter { !liveIDs.contains($0) && $0 != activeID }
        for staleID in staleIDs {
            coordinator.removeTerminalView(for: staleID)
        }
    }

    // MARK: - Coordinator

    final class Coordinator {
        /// Pairs a SwiftTerm view with its TerminalSessionViewModel delegate holder.
        struct TerminalEntry {
            let terminalView: LocalProcessTerminalView
            let sessionViewModel: TerminalSessionViewModel
            let delegateHolder: TerminalDelegateHolder
        }

        var container: NSView?
        var terminalViews: [UUID: TerminalEntry] = [:]

        func createTerminalView(for session: TerminalSession, in container: NSView) {
            let sessionViewModel = TerminalSessionViewModel(session: session)
            let delegateHolder = TerminalDelegateHolder(viewModel: sessionViewModel)

            let terminalView = LocalProcessTerminalView(frame: container.bounds)
            terminalView.autoresizingMask = [.width, .height]
            terminalView.processDelegate = delegateHolder

            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let shellName = (shell as NSString).lastPathComponent
            let execName = "-\(shellName)"

            let workingDirectory: String
            if session.workingDirectory == "~" {
                workingDirectory = NSHomeDirectory()
            } else {
                workingDirectory = session.workingDirectory
            }

            terminalView.startProcess(
                executable: shell,
                args: ["-l"],
                environment: nil,
                execName: execName,
                currentDirectory: workingDirectory
            )

            container.addSubview(terminalView)

            terminalViews[session.id] = TerminalEntry(
                terminalView: terminalView,
                sessionViewModel: sessionViewModel,
                delegateHolder: delegateHolder
            )
        }

        func removeTerminalView(for id: UUID) {
            guard let entry = terminalViews[id] else { return }
            entry.terminalView.terminate()
            entry.terminalView.removeFromSuperview()
            terminalViews.removeValue(forKey: id)
        }
    }
}

// MARK: - TerminalDelegateHolder

/// Holds the `LocalProcessTerminalViewDelegate` conformance so it can live outside
/// the SwiftUI update cycle without being deallocated.
final class TerminalDelegateHolder: NSObject, LocalProcessTerminalViewDelegate {
    let viewModel: TerminalSessionViewModel

    init(viewModel: TerminalSessionViewModel) {
        self.viewModel = viewModel
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // No-op for now
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        viewModel.updateTitle(title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory else { return }
        viewModel.updateWorkingDirectory(directory)
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        viewModel.markTerminated()
    }
}

// MARK: - Previews

#Preview("Terminal Active") {
    ContentPaneView(
        selection: .terminal(UUID()),
        terminalManager: TerminalManagerViewModel(
            modelContext: try! ModelContainer(
                for: TerminalSession.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext
        )
    )
    .modelContainer(for: TerminalSession.self, inMemory: true)
}

#Preview("Prompt Selected") {
    ContentPaneView(
        selection: .prompt("Default Prompt"),
        terminalManager: TerminalManagerViewModel(
            modelContext: try! ModelContainer(
                for: TerminalSession.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext
        )
    )
}

#Preview("No Selection") {
    ContentPaneView(
        selection: nil,
        terminalManager: TerminalManagerViewModel(
            modelContext: try! ModelContainer(
                for: TerminalSession.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext
        )
    )
}
