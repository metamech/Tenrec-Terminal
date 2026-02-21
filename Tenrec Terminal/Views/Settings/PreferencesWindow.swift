import SwiftUI
import SwiftData

// MARK: - PreferencesView

/// The main Preferences window content, organized by tabs.
struct PreferencesView: View {
    var body: some View {
        TabView {
            ProfileListView()
                .tabItem {
                    Label("Profiles", systemImage: "paintbrush")
                }
                .tag("profiles")

            GeneralPreferencesView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag("general")
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - GeneralPreferencesView

/// Placeholder for future general preferences.
private struct GeneralPreferencesView: View {
    var body: some View {
        Form {
            Section("Application") {
                Text("General preferences will appear here in a future release.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
        .modelContainer(for: [TerminalSession.self, TerminalProfile.self], inMemory: true)
}
