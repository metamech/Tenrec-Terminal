//
//  Tenrec_TerminalApp.swift
//  Tenrec Terminal
//
//  Created by Iain Shigeoka on 2/11/26.
//

import SwiftUI
import SwiftData

@main
struct Tenrec_TerminalApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TerminalSession.self,
            TerminalProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    seedDefaultProfilesIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)

        // macOS Settings window (Cmd+,)
        Settings {
            PreferencesView()
                .modelContainer(sharedModelContainer)
        }
    }

    // MARK: - Profile Seeding

    private func seedDefaultProfilesIfNeeded() {
        let context = sharedModelContainer.mainContext
        let vm = TerminalProfileViewModel(modelContext: context)
        vm.seedDefaultProfilesIfNeeded()
    }
}
