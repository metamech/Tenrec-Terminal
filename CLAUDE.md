# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tenrec Terminal is a SwiftUI-based macOS/iOS application using modern Apple frameworks:
- **UI Framework:** SwiftUI
- **Data Persistence:** SwiftData
- **Testing Framework:** Swift Testing (not XCTest)
- **Minimum Deployment:** macOS 26.2, iOS 26.2
- **Build System:** Xcode 26.2+
- **GitHub:** metamech/Tenrec-Terminal

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


## Planning

1. Summarize relevant code and current behavior.
2. Ask clarifying questions with recommendations based on codebase conventions.
3. Propose a phased plan. For each phase specify:
 - Purpose and scope
 - Files/functions to change
 - Tests to add or update
 - Recommended Claude model (opus/sonnet/haiku) with rationale
4. Note edge cases and performance considerations where non-obvious.

## GitHub Integration

- If linked to an existing issue:
  - update the final plan on the issue when it diverges from the description
  - technical details in the issue are "pseudo code guidance" and not hard requirements unless explicitly declared as a strict requirement
- If no issue exists, create one before implementation begins.

## Implementation Protocol

- Do not write code until I say "implement."
- Create and checkout a feature branch from `main` before starting in a "phase 0".
- feature branch naming convention "<type>/X-<slug>" where `<type>` is issue/task type (feature, bugfix, docs, etc), `X` is the GitHub Issue number, and `<slug>` is a short description/title.
- Commit after each phase.
- **Before starting each phase** (including the first), output the phase number, its recommended model, and ask: "Ready to proceed with Phase N? (switch to /model <X> if needed)" then STOP and wait for my explicit go-ahead. Do NOT continue until I respond.
- Only implement one phase per response. After committing a phase, stop and prompt me for the next phase.

## Constraints

- Pre-release: no data migrations or legacy compatibility needed.

## Important Notes

- SwiftData schema is defined in `Tenrec_TerminalApp` — changes to models should be reflected there
- Previews use in-memory data stores to avoid affecting real data during development
- The model context is automatically provided by SwiftUI's environment
