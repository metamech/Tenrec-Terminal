import SwiftUI
import SwiftData
import SwiftTerm
import AppKit

// MARK: - ContentPaneView

struct ContentPaneView: View {
    let selection: SidebarSelection?
    let terminalManager: TerminalManagerViewModel

    @State private var isSearchVisible = false
    @State private var searchText = ""
    @State private var searchMatchCount: Int? = nil

    var body: some View {
        Group {
            switch selection {
            case .terminal:
                // The container manages all terminal views. It always fills the space
                // and uses show/hide to switch between cached PTY instances.
                ZStack(alignment: .top) {
                    TerminalContainerView(
                        terminalManager: terminalManager,
                        searchBridge: SearchBridge(
                            searchText: $searchText,
                            matchCount: $searchMatchCount,
                            isVisible: $isSearchVisible
                        )
                    )

                    if isSearchVisible {
                        VStack {
                            TerminalSearchBar(
                                searchText: $searchText,
                                onNext: { terminalManager.searchNext(text: searchText) },
                                onPrevious: { terminalManager.searchPrevious(text: searchText) },
                                onDismiss: { dismissSearch() },
                                matchCount: searchMatchCount
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    }
                }
                .onChange(of: searchText) { _, newText in
                    if isSearchVisible {
                        terminalManager.searchNext(text: newText)
                    }
                }

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
        .keyboardShortcut("f", modifiers: .command)  // handled via onKeyPress below
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Cmd+F — open search
                if event.modifierFlags.contains(.command),
                   event.keyCode == 3 /* f */ {
                    withAnimation(.easeIn(duration: 0.15)) { isSearchVisible = true }
                    return nil
                }
                // Esc — dismiss search
                if event.keyCode == 53 /* Esc */ && isSearchVisible {
                    dismissSearch()
                    return nil
                }
                return event
            }
        }
    }

    private func dismissSearch() {
        withAnimation(.easeOut(duration: 0.12)) {
            isSearchVisible = false
        }
        searchText = ""
        searchMatchCount = nil
        terminalManager.clearSearch()
    }
}

// MARK: - SearchBridge

/// Bridges SwiftUI state into TerminalContainerView's coordinator so the
/// NSView layer can trigger search operations without holding SwiftUI state.
struct SearchBridge {
    @Binding var searchText: String
    @Binding var matchCount: Int?
    @Binding var isVisible: Bool
}

// MARK: - TerminalContainerView

/// An NSViewRepresentable that owns a cache of `LocalProcessTerminalView` instances,
/// one per session UUID. Switching sessions shows/hides NSViews rather than
/// recreating them, keeping PTY processes alive across selection changes.
struct TerminalContainerView: NSViewRepresentable {
    let terminalManager: TerminalManagerViewModel
    var searchBridge: SearchBridge?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        context.coordinator.container = container
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.searchBridge = searchBridge

        guard let activeID = terminalManager.activeSessionId else {
            // No active session — hide all views
            coordinator.terminalViews.values.forEach { $0.terminalView.isHidden = true }
            return
        }

        let sessions = terminalManager.fetchSessions()

        // Create a terminal view for the active session if it doesn't exist yet
        if coordinator.terminalViews[activeID] == nil {
            if let session = sessions.first(where: { $0.id == activeID }) {
                let profile = terminalManager.resolveProfile(for: session)
                coordinator.createTerminalView(for: session, profile: profile, in: nsView)
            }
        } else {
            // Apply any profile changes to the existing view
            if let session = sessions.first(where: { $0.id == activeID }),
               let entry = coordinator.terminalViews[activeID],
               let profile = terminalManager.resolveProfile(for: session) {
                coordinator.applyProfile(profile, to: entry.terminalView)
            }
        }

        // Show the active view, hide all others; make it fill the container
        for (id, entry) in coordinator.terminalViews {
            let isActive = (id == activeID)
            entry.terminalView.isHidden = !isActive
            if isActive {
                entry.terminalView.frame = nsView.bounds
                entry.terminalView.autoresizingMask = [.width, .height]
                coordinator.activeTerminalView = entry.terminalView
                // Expose active view to the manager for search operations
                terminalManager.activeTerminalView = entry.terminalView
                // Restore first-responder focus to the terminal when switching back
                DispatchQueue.main.async {
                    entry.terminalView.window?.makeFirstResponder(entry.terminalView)
                }
            }
        }

        // Remove cached views for sessions that are now terminated / no longer fetched
        let liveIDs = Set(sessions.map { $0.id })
        let staleIDs = coordinator.terminalViews.keys.filter { !liveIDs.contains($0) && $0 != activeID }
        for staleID in staleIDs {
            coordinator.removeTerminalView(for: staleID)
        }
    }

    // MARK: - Coordinator

    final class Coordinator {
        /// Pairs a SwiftTerm view with its TerminalSessionViewModel delegate holder.
        struct TerminalEntry {
            let terminalView: LocalProcessTerminalView
            let sessionViewModel: TerminalSessionViewModel
            let delegateHolder: TerminalDelegateHolder
        }

        var container: NSView?
        var terminalViews: [UUID: TerminalEntry] = [:]
        var activeTerminalView: LocalProcessTerminalView?
        var searchBridge: SearchBridge?

        func createTerminalView(for session: TerminalSession, profile: TerminalProfile?, in container: NSView) {
            let sessionViewModel = TerminalSessionViewModel(session: session)
            let delegateHolder = TerminalDelegateHolder(viewModel: sessionViewModel)

            let terminalView = LocalProcessTerminalView(frame: container.bounds)
            terminalView.autoresizingMask = [.width, .height]
            terminalView.processDelegate = delegateHolder

            // Apply profile before starting the process
            if let profile {
                applyProfile(profile, to: terminalView)
            }

            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let shellName = (shell as NSString).lastPathComponent
            let execName = "-\(shellName)"

            let workingDirectory: String
            if session.workingDirectory == "~" {
                workingDirectory = NSHomeDirectory()
            } else {
                workingDirectory = session.workingDirectory
            }

            terminalView.startProcess(
                executable: shell,
                args: ["-l"],
                environment: nil,
                execName: execName,
                currentDirectory: workingDirectory
            )

            container.addSubview(terminalView)

            terminalViews[session.id] = TerminalEntry(
                terminalView: terminalView,
                sessionViewModel: sessionViewModel,
                delegateHolder: delegateHolder
            )
        }

        /// Applies a TerminalProfile's font, colors, and cursor style to a live terminal view.
        func applyProfile(_ profile: TerminalProfile, to terminalView: LocalProcessTerminalView) {
            // Font
            if let font = NSFont(name: profile.fontFamily, size: profile.fontSize) {
                terminalView.font = font
            }

            // Foreground and background colors
            if let fg = nsColor(from: profile.foregroundColor) {
                terminalView.nativeForegroundColor = fg
            }
            if let bg = nsColor(from: profile.backgroundColor) {
                terminalView.nativeBackgroundColor = bg
                terminalView.layer?.opacity = Float(profile.opacity)
            }

            // ANSI 16-color palette
            let swiftTermColors = profile.ansiColors.prefix(16).compactMap { swiftTermColor(from: $0) }
            if swiftTermColors.count == 16 {
                terminalView.installColors(swiftTermColors)
            }

            // Cursor style
            let cursorStyle: CursorStyle
            switch profile.cursorStyle {
            case "underline": cursorStyle = .steadyUnderline
            case "bar":       cursorStyle = .steadyBar
            default:          cursorStyle = .steadyBlock
            }
            terminalView.terminal.setCursorStyle(cursorStyle)
        }

        func removeTerminalView(for id: UUID) {
            guard let entry = terminalViews[id] else { return }
            entry.terminalView.terminate()
            entry.terminalView.removeFromSuperview()
            terminalViews.removeValue(forKey: id)
        }

        // MARK: - Color parsing

        private func nsColor(from hex: String) -> NSColor? {
            var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if str.hasPrefix("#") { str = String(str.dropFirst()) }

            var rgba: UInt64 = 0
            guard Scanner(string: str).scanHexInt64(&rgba) else { return nil }

            switch str.count {
            case 6:
                return NSColor(
                    calibratedRed:   CGFloat((rgba >> 16) & 0xFF) / 255,
                    green: CGFloat((rgba >>  8) & 0xFF) / 255,
                    blue:  CGFloat( rgba        & 0xFF) / 255,
                    alpha: 1.0
                )
            case 8:
                return NSColor(
                    calibratedRed:   CGFloat((rgba >> 24) & 0xFF) / 255,
                    green: CGFloat((rgba >> 16) & 0xFF) / 255,
                    blue:  CGFloat((rgba >>  8) & 0xFF) / 255,
                    alpha: CGFloat( rgba        & 0xFF) / 255
                )
            default:
                return nil
            }
        }

        private func swiftTermColor(from hex: String) -> SwiftTerm.Color? {
            var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if str.hasPrefix("#") { str = String(str.dropFirst()) }

            var rgba: UInt64 = 0
            guard Scanner(string: str).scanHexInt64(&rgba), str.count >= 6 else { return nil }

            // Scale 8-bit (0-255) components to 16-bit (0-65535) using * 257
            let r = UInt16((rgba >> 16) & 0xFF) * 257
            let g = UInt16((rgba >>  8) & 0xFF) * 257
            let b = UInt16( rgba        & 0xFF) * 257
            return SwiftTerm.Color(red: r, green: g, blue: b)
        }
    }
}

// MARK: - TerminalDelegateHolder

/// Holds the `LocalProcessTerminalViewDelegate` conformance so it can live outside
/// the SwiftUI update cycle without being deallocated.
final class TerminalDelegateHolder: NSObject, LocalProcessTerminalViewDelegate {
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

// MARK: - Previews

#Preview("Terminal Active") {
    let container = try! ModelContainer(
        for: TerminalSession.self, TerminalProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ContentPaneView(
        selection: .terminal(UUID()),
        terminalManager: TerminalManagerViewModel(modelContext: container.mainContext)
    )
    .modelContainer(container)
}

#Preview("Prompt Selected") {
    let container = try! ModelContainer(
        for: TerminalSession.self, TerminalProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ContentPaneView(
        selection: .prompt("Default Prompt"),
        terminalManager: TerminalManagerViewModel(modelContext: container.mainContext)
    )
    .modelContainer(container)
}

#Preview("No Selection") {
    let container = try! ModelContainer(
        for: TerminalSession.self, TerminalProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ContentPaneView(
        selection: nil,
        terminalManager: TerminalManagerViewModel(modelContext: container.mainContext)
    )
    .modelContainer(container)
}
