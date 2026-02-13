import SwiftUI

struct ContentPaneView: View {
    let selection: SidebarSelection?

    var body: some View {
        Group {
            switch selection {
            case .terminal(let id):
                VStack {
                    Text("Terminal Content")
                        .font(.title)
                    Text("Session ID: \(id.uuidString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
