import SwiftUI

// MARK: - TerminalSearchBar

/// An overlay search bar that sits at the top of the terminal content area.
/// The parent view is responsible for showing/hiding this and passing search
/// actions back to the terminal view via the TerminalSearchDelegate.
struct TerminalSearchBar: View {
    @Binding var searchText: String
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onDismiss: () -> Void
    var matchCount: Int? = nil

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            TextField("Find", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .onSubmit { onNext() }
                .frame(minWidth: 140)

            if let count = matchCount {
                Text(count == 0 ? "No results" : "\(count) found")
                    .font(.system(size: 11))
                    .foregroundStyle(count == 0 ? .red : .secondary)
                    .fixedSize()
            }

            Divider()
                .frame(height: 16)

            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Previous Match (Shift+Cmd+G)")
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button(action: onNext) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Next Match (Cmd+G)")
            .keyboardShortcut("g", modifiers: .command)

            Divider()
                .frame(height: 16)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Close Search (Esc)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .onAppear {
            // Small delay to let the view settle before grabbing focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        TerminalSearchBar(
            searchText: .constant("find me"),
            onNext: {},
            onPrevious: {},
            onDismiss: {},
            matchCount: 3
        )
        .padding()
        Spacer()
    }
    .frame(width: 500, height: 200)
}
