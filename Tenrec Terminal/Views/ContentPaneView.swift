import SwiftUI
import SwiftData

struct ContentPaneView: View {
    let selection: SidebarSelection?

    var body: some View {
        Group {
            switch selection {
            case .terminal(let id):
                TerminalContentView(sessionID: id)

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

#Preview("Terminal Selected") {
    ContentPaneView(selection: .terminal(UUID()))
}

#Preview("Prompt Selected") {
    ContentPaneView(selection: .prompt("Default Prompt"))
}

#Preview("Template Selected") {
    ContentPaneView(selection: .template("SSH Remote"))
}

#Preview("No Selection") {
    ContentPaneView(selection: nil)
}

// MARK: - Terminal Content View

struct TerminalContentView: View {
    let sessionID: UUID

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TerminalSessionViewModel?
    @State private var session: TerminalSession?

    var body: some View {
        Group {
            if let viewModel {
                ZStack {
                    TerminalViewWrapper(viewModel: viewModel)

                    if !viewModel.isRunning {
                        VStack {
                            Spacer()
                            Text("Process terminated")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                    }
                }
            } else if session == nil {
                ContentUnavailableView(
                    "Session Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The terminal session could not be loaded")
                )
            }
        }
        .task(id: sessionID) {
            fetchSession()
        }
    }

    private func fetchSession() {
        let fetchDescriptor = FetchDescriptor<TerminalSession>(
            predicate: #Predicate { $0.id == sessionID }
        )

        do {
            let sessions = try modelContext.fetch(fetchDescriptor)
            session = sessions.first

            if let session {
                viewModel = TerminalSessionViewModel(session: session)
            }
        } catch {
            print("Failed to fetch session: \(error)")
            session = nil
            viewModel = nil
        }
    }
}
