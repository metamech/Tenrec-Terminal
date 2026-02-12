import SwiftUI
import SwiftData

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    @Query private var sessions: [TerminalSession]

    var body: some View {
        List(selection: $viewModel.selection) {
            Section("Terminals") {
                ForEach(sessions) { session in
                    NavigationLink(value: SidebarSelection.terminal(session.id)) {
                        Label(session.name, systemImage: "terminal")
                    }
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
                Button(action: {
                    // Stub: New terminal action will be implemented later
                }) {
                    Label("New Terminal", systemImage: "plus")
                }
            }
        }
    }
}

#Preview {
    NavigationSplitView {
        SidebarView(viewModel: SidebarViewModel())
            .modelContainer(for: TerminalSession.self, inMemory: true)
    } content: {
        Text("Content")
    } detail: {
        Text("Detail")
    }
}
