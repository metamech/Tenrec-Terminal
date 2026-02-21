import SwiftUI
import SwiftData

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    let terminalManager: TerminalManagerViewModel

    // All sessions sorted by lastActiveAt descending.
    // Filtering out terminated sessions happens in the view body since
    // SwiftData #Predicate can crash at runtime with enum rawValue comparisons.
    @Query(sort: \TerminalSession.lastActiveAt, order: .reverse)
    private var allSessions: [TerminalSession]

    private var sessions: [TerminalSession] {
        allSessions.filter { $0.status != .terminated }
    }

    var body: some View {
        List(selection: $viewModel.selection) {
            Section("Terminals") {
                ForEach(sessions) { session in
                    SessionRow(
                        session: session,
                        terminalManager: terminalManager
                    )
                }
            }

            Section("Prompts") {
                ForEach(viewModel.prompts, id: \.self) { prompt in
                    NavigationLink(value: SidebarSelection.prompt(prompt)) {
                        Label(prompt, systemImage: "text.alignleft")
                    }
                }
            }

            Section("Templates") {
                ForEach(viewModel.templates, id: \.self) { template in
                    NavigationLink(value: SidebarSelection.template(template)) {
                        Label(template, systemImage: "doc.text")
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        .toolbar {
            ToolbarItem {
                Button(action: createNewTerminal) {
                    Label("New Terminal", systemImage: "plus")
                }
            }
        }
        .onChange(of: viewModel.selection) { _, newSelection in
            if case .terminal(let id) = newSelection {
                terminalManager.switchToSession(id: id)
            }
        }
        .onChange(of: terminalManager.activeSessionId) { _, newID in
            if let newID, viewModel.selection != .terminal(newID) {
                viewModel.selection = .terminal(newID)
            }
        }
    }

    private func createNewTerminal() {
        let session = terminalManager.createSession()
        terminalManager.switchToSession(id: session.id)
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: TerminalSession
    let terminalManager: TerminalManagerViewModel

    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showCloseConfirmation = false
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        NavigationLink(value: SidebarSelection.terminal(session.id)) {
            HStack(spacing: 6) {
                // Status indicator dot
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(statusColor(for: session.status))

                if isRenaming {
                    TextField("Session name", text: $renameText)
                        .focused($isRenameFocused)
                        .onSubmit { commitRename() }
                        .onExitCommand { cancelRename() }
                        .textFieldStyle(.plain)
                } else {
                    Text(session.name)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            startRenaming()
                        }
                }
            }
        }
        .contextMenu {
            Button("Rename") { startRenaming() }

            Button("Close", role: .destructive) {
                if session.status == .terminated {
                    terminalManager.closeSession(id: session.id)
                } else {
                    showCloseConfirmation = true
                }
            }

            Divider()

            Button("Copy Session ID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.id.uuidString, forType: .string)
            }
        }
        .alert("Close Terminal?", isPresented: $showCloseConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Close", role: .destructive) {
                terminalManager.closeSession(id: session.id)
            }
        } message: {
            Text("This terminal is running a process. Close anyway?")
        }
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active:   return .green
        case .inactive: return .gray
        case .terminated: return .red
        }
    }

    private func startRenaming() {
        renameText = session.name
        isRenaming = true
        // Delay focus so the TextField has time to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isRenameFocused = true
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            terminalManager.renameSession(id: session.id, name: trimmed)
        }
        isRenaming = false
        isRenameFocused = false
    }

    private func cancelRename() {
        isRenaming = false
        isRenameFocused = false
    }
}

// MARK: - Preview

#Preview {
    NavigationSplitView {
        SidebarView(
            viewModel: SidebarViewModel(),
            terminalManager: TerminalManagerViewModel(
                modelContext: try! ModelContainer(
                    for: TerminalSession.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                ).mainContext
            )
        )
        .modelContainer(for: TerminalSession.self, inMemory: true)
    } detail: {
        Text("Detail")
    }
}
