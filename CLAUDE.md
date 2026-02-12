# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tenrec Terminal is a SwiftUI-based macOS/iOS application using modern Apple frameworks:
- **UI Framework:** SwiftUI
- **Data Persistence:** SwiftData
- **Testing Framework:** Swift Testing (not XCTest)
- **Terminal Emulation:** SwiftTerm (v1.10.1+)
- **Minimum Deployment:** macOS 26.2, iOS 26.2
- **Build System:** Xcode 26.2+
- **GitHub:** metamech/Tenrec-Terminal

## Building and Running

**Using Makefile (recommended):**
```bash
make build        # Build the application
make run          # Build and launch the application
make clean        # Clean build artifacts
```

**Using xcodebuild directly:**
```bash
xcodebuild -scheme "Tenrec Terminal" -configuration Debug
xcodebuild -scheme "Tenrec Terminal" -configuration Release
```

## Testing

**Using Makefile (recommended):**
```bash
make test         # Run all tests (unit + UI)
```

**Using xcodebuild directly:**
```bash
xcodebuild test -scheme "Tenrec Terminal"
```

## Code Architecture

### MVVM Folder Structure
```
Tenrec Terminal/
├── Models/              — SwiftData models
│   └── TerminalSession.swift
├── ViewModels/          — View models (future)
├── Views/               — SwiftUI views
│   ├── ContentView.swift
│   └── Terminal/        — Terminal-specific views (future)
├── Services/            — Business logic and utilities
│   └── ShellExecutionPoC.swift
├── Utilities/           — Helper utilities (future)
├── Assets.xcassets/     — App icons and colors
└── Tenrec_TerminalApp.swift — App entry point
```

### Data Models

**TerminalSession** (`Models/TerminalSession.swift`)
- SwiftData `@Model` for persisting terminal session state
- Properties:
  - `id: UUID` — Unique session identifier
  - `name: String` — User-facing session name
  - `createdAt: Date` — Session creation timestamp
  - `status: SessionStatus` — Current session state (active/inactive/terminated)
  - `workingDirectory: String` — Shell working directory (defaults to "~")

**SessionStatus** (enum in `TerminalSession.swift`)
- `active` — Session is running
- `inactive` — Session is paused or backgrounded
- `terminated` — Session has ended

### Key Architectural Patterns

**SwiftData Integration:**
- Models use `@Model` decorator for SwiftData persistence
- App container initialized in `Tenrec_TerminalApp` with schema
- Data persisted to disk by default (not in-memory)
- Previews use in-memory containers to avoid affecting real data

**MVVM Pattern:**
- Models: SwiftData entities in `Models/`
- ViewModels: Future view-specific logic in `ViewModels/`
- Views: SwiftUI views in `Views/`, organized by feature
- Services: Business logic, PTY handling, shell execution in `Services/`

**Testing:**
- Unit tests use Swift Testing framework (`@Test` macro)
- UI tests use XCTest for automation
- PoC validation tests ensure sandbox is disabled for terminal functionality


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

## Architectural Decisions

Architecture Decision Records (ADRs) document important design decisions, their context, rationale, and consequences. Refer to the documents in `docs/ADR/` for full details.

- **ADR-001**: App Sandbox vs. Terminal Functionality — See `docs/ADR/001-app-sandbox-vs-terminal-functionality.md`
- **ADR-002**: MVVM Architecture with SwiftData — See `docs/ADR/002-mvvm-architecture-with-swiftdata.md`
