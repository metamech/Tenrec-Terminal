import SwiftUI
import SwiftData

struct DetailPaneView: View {
    let selection: SidebarSelection?

    var body: some View {
        Group {
            switch selection {
            case .terminal(let id):
                TerminalInspectorView(sessionID: id)

            case .prompt(let name):
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prompt Inspector")
                        .font(.headline)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(name)
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            case .template(let name):
                VStack(alignment: .leading, spacing: 16) {
                    Text("Template Inspector")
                        .font(.headline)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(name)
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            case nil:
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "info.circle",
                    description: Text("Inspector will appear here")
                )
            }
        }
        .inspectorColumnWidth(min: 250, ideal: 300)
        .navigationTitle("Inspector")
    }
}

#Preview("Terminal Selected") {
    DetailPaneView(selection: .terminal(UUID()))
}

#Preview("Prompt Selected") {
    DetailPaneView(selection: .prompt("Default Prompt"))
}

#Preview("Template Selected") {
    DetailPaneView(selection: .template("SSH Remote"))
}

#Preview("No Selection") {
    DetailPaneView(selection: nil)
}

// MARK: - Terminal Inspector View

struct TerminalInspectorView: View {
    let sessionID: UUID

    @Environment(\.modelContext) private var modelContext
    @State private var session: TerminalSession?

    var body: some View {
        Group {
            if let session {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terminal Inspector")
                        .font(.headline)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.name)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.status.rawValue.capitalized)
                            .foregroundStyle(statusColor(for: session.status))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Working Directory")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.workingDirectory)
                            .font(.system(.caption, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Created")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.createdAt, style: .relative)
                            .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.id.uuidString)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
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
        } catch {
            print("Failed to fetch session: \(error)")
            session = nil
        }
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active:
            return .green
        case .inactive:
            return .orange
        case .terminated:
            return .red
        }
    }
}
