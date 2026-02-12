import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var viewModel = SidebarViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } content: {
            ContentPaneView(selection: viewModel.selection)
        } detail: {
            DetailPaneView(selection: viewModel.selection)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TerminalSession.self, inMemory: true)
}
