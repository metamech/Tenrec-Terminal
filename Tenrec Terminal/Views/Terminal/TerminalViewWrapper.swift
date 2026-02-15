import SwiftUI
import SwiftTerm

struct TerminalViewWrapper: NSViewRepresentable {
    let viewModel: TerminalSessionViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.processDelegate = context.coordinator

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = (shell as NSString).lastPathComponent
        let execName = "-\(shellName)" // Login shell convention

        let workingDirectory: String
        if viewModel.workingDirectory == "~" {
            workingDirectory = NSHomeDirectory()
        } else {
            workingDirectory = viewModel.workingDirectory
        }

        terminalView.startProcess(
            executable: shell,
            args: ["-l"],
            environment: nil,
            execName: execName,
            currentDirectory: workingDirectory
        )

        DispatchQueue.main.async {
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // No updates needed from SwiftUI side — terminal manages its own state
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let viewModel: TerminalSessionViewModel

        init(viewModel: TerminalSessionViewModel) {
            self.viewModel = viewModel
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // No-op for now
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            viewModel.updateTitle(title)
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            guard let directory else { return }
            viewModel.updateWorkingDirectory(directory)
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            viewModel.markTerminated()
        }
    }
}
