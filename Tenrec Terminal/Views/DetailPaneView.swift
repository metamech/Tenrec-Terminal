import SwiftUI

struct DetailPaneView: View {
    let selection: SidebarSelection?

    var body: some View {
        Group {
            switch selection {
            case .terminal(let id):
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terminal Inspector")
                        .font(.headline)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(id.uuidString)
                            .font(.system(.caption, design: .monospaced))
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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
        .navigationSplitViewColumnWidth(min: 250, ideal: 300)
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
