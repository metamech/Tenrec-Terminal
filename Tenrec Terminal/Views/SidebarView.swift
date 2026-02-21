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
                        terminalManager: terminalManager,
                        hasPendingInput: terminalManager.sessionsPendingInput.contains(session.id)
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
    var hasPendingInput: Bool = false

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

                Spacer(minLength: 0)

                // Color tag dot (shown when a tag is set)
                if let tag = session.colorTag, tag != "none", tag != "" {
                    Circle()
                        .fill(colorTagColor(tag))
                        .frame(width: 8, height: 8)
                }

                // Pending-input badge: orange dot when the buffer monitor has
                // detected a prompt awaiting user input in this session.
                if hasPendingInput {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .help("Prompt is waiting for input")
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

            // Color tag submenu
            Menu("Color Tag") {
                ForEach(ColorTag.allCases) { tag in
                    Button {
                        terminalManager.setColorTag(
                            id: session.id,
                            tag: tag == .none ? nil : tag.rawValue
                        )
                    } label: {
                        HStack {
                            if tag != .none {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(tag.color)
                            } else {
                                Image(systemName: "circle")
                            }
                            Text(tag.displayName)
                        }
                    }
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

    private func colorTagColor(_ tag: String) -> Color {
        ColorTag(rawValue: tag)?.color ?? .clear
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

// MARK: - ColorTag

enum ColorTag: String, CaseIterable, Identifiable {
    case none    = "none"
    case red     = "red"
    case orange  = "orange"
    case yellow  = "yellow"
    case green   = "green"
    case blue    = "blue"
    case purple  = "purple"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:   return "None"
        case .red:    return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green:  return "Green"
        case .blue:   return "Blue"
        case .purple: return "Purple"
        }
    }

    var color: Color {
        switch self {
        case .none:   return .clear
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: TerminalSession.self, TerminalProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationSplitView {
        SidebarView(
            viewModel: SidebarViewModel(),
            terminalManager: TerminalManagerViewModel(modelContext: container.mainContext)
        )
        .modelContainer(container)
    } detail: {
        Text("Detail")
    }
}
