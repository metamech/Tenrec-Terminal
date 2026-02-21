import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var terminalManager: TerminalManagerViewModel?
    @State private var sidebarViewModel = SidebarViewModel()
    @State private var inspectorVisible = false
    @State private var showCloseConfirmation = false
    @State private var sessionToClose: UUID?

    var body: some View {
        Group {
            if let terminalManager {
                terminalManagerContent(terminalManager: terminalManager)
            } else {
                ProgressView("Initializing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if terminalManager == nil {
                terminalManager = TerminalManagerViewModel(modelContext: modelContext)
            }
        }
    }

    @ViewBuilder
    private func terminalManagerContent(terminalManager: TerminalManagerViewModel) -> some View {
        NavigationSplitView {
            SidebarView(
                viewModel: sidebarViewModel,
                terminalManager: terminalManager
            )
        } detail: {
            ContentPaneView(
                selection: sidebarViewModel.selection,
                terminalManager: terminalManager
            )
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { inspectorVisible.toggle() }) {
                        Label("Toggle Inspector", systemImage: "sidebar.right")
                    }
                }
            }
            .inspector(isPresented: $inspectorVisible) {
                DetailPaneView(selection: sidebarViewModel.selection)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onChange(of: terminalManager.activeSessionId) { _, newID in
            if let newID {
                sidebarViewModel.selection = .terminal(newID)
            }
        }
        .alert("Close Terminal?", isPresented: $showCloseConfirmation, presenting: sessionToClose) { id in
            Button("Cancel", role: .cancel) {
                sessionToClose = nil
            }
            Button("Close", role: .destructive) {
                terminalManager.closeSession(id: id)
                sessionToClose = nil
            }
        } message: { _ in
            Text("This terminal is running a process. Close anyway?")
        }
        // Keyboard shortcut handlers live as hidden buttons so they participate
        // in the responder chain without needing .commands (which can't access @State).
        .background {
            keyboardShortcutButtons(terminalManager: terminalManager)
        }
    }

    // Invisible buttons that register keyboard shortcuts.
    // Using Group so they don't affect layout.
    @ViewBuilder
    private func keyboardShortcutButtons(terminalManager: TerminalManagerViewModel) -> some View {
        Group {
            Button("New Terminal") {
                let session = terminalManager.createSession()
                terminalManager.switchToSession(id: session.id)
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Close Terminal") {
                requestCloseCurrentSession(terminalManager: terminalManager)
            }
            .keyboardShortcut("w", modifiers: .command)

            // Cmd+1 through Cmd+9 to switch sessions by index
            ForEach(1..<10) { index in
                Button("Switch to Terminal \(index)") {
                    switchToSessionByIndex(index - 1, terminalManager: terminalManager)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    private func requestCloseCurrentSession(terminalManager: TerminalManagerViewModel) {
        guard let activeID = terminalManager.activeSessionId else { return }
        let sessions = terminalManager.fetchSessions()
        guard let session = sessions.first(where: { $0.id == activeID }) else { return }

        if session.status == .terminated {
            terminalManager.closeSession(id: activeID)
        } else {
            sessionToClose = activeID
            showCloseConfirmation = true
        }
    }

    private func switchToSessionByIndex(_ index: Int, terminalManager: TerminalManagerViewModel) {
        let sessions = terminalManager.fetchSessions()
        guard index < sessions.count else { return }
        terminalManager.switchToSession(id: sessions[index].id)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TerminalSession.self, inMemory: true)
}
