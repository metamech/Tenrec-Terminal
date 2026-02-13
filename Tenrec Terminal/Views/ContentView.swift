import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var viewModel = SidebarViewModel()
    @State private var inspectorVisible = false

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            ContentPaneView(selection: viewModel.selection)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            inspectorVisible.toggle()
                        }) {
                            Label("Toggle Inspector", systemImage: "sidebar.right")
                        }
                    }
                }
                .inspector(isPresented: $inspectorVisible) {
                    DetailPaneView(selection: viewModel.selection)
                }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TerminalSession.self, inMemory: true)
}
