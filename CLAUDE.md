# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tenrec Terminal is a SwiftUI-based macOS/iOS application using modern Apple frameworks:
- **UI Framework:** SwiftUI
- **Data Persistence:** SwiftData
- **Testing Framework:** Swift Testing (not XCTest)
- **Minimum Deployment:** macOS 26.2, iOS 26.2
- **Build System:** Xcode 26.2+

## Building and Running

**Build the app:**
```bash
xcodebuild -scheme "Tenrec Terminal" -configuration Debug
```

**Run the app (macOS):**
```bash
xcodebuild -scheme "Tenrec Terminal" -configuration Debug -derivedDataPath build
open build/Build/Products/Debug/Tenrec\ Terminal.app
```

**Build for release:**
```bash
xcodebuild -scheme "Tenrec Terminal" -configuration Release
```

## Testing

**Run all tests:**
```bash
xcodebuild test -scheme "Tenrec Terminal"
```

**Run a specific test target:**
```bash
xcodebuild test -scheme "Tenrec Terminal" -only-testing "Tenrec_TerminalTests"
```

**Run UI tests:**
```bash
xcodebuild test -scheme "Tenrec Terminal" -only-testing "Tenrec_TerminalUITests"
```

## Code Architecture

### Structure
- **Tenrec Terminal/** — Main app source code
  - `Tenrec_TerminalApp.swift` — App entry point and SwiftData container setup
  - `ContentView.swift` — Main UI with NavigationSplitView showing list and detail views
  - `Item.swift` — SwiftData model for items (currently just a timestamp)
- **Tenrec TerminalTests/** — Unit tests using Swift Testing framework
- **Tenrec TerminalUITests/** — UI automation tests

### Key Architectural Patterns

**SwiftData Integration:**
- The `Item` model is decorated with `@Model` to make it a SwiftData entity
- The app container is initialized in `Tenrec_TerminalApp` with a schema including `Item.self`
- Data is persisted to disk by default (not in-memory)

**UI Architecture:**
- `ContentView` uses `@Query` property wrapper to automatically fetch items from SwiftData
- `@Environment(\.modelContext)` provides direct access to the model context for mutations
- Changes to data are wrapped in `withAnimation` for smooth transitions
- The preview uses an in-memory model container for testing the UI

**Testing:**
- Tests use the modern `@Test` macro from the Swift Testing framework
- UI tests inherit from the standard UITest structure

## Important Notes

- SwiftData schema is defined in `Tenrec_TerminalApp` — changes to models should be reflected there
- Previews use in-memory data stores to avoid affecting real data during development
- The model context is automatically provided by SwiftUI's environment
