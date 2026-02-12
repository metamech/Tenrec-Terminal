# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start

**Tenrec Terminal**: SwiftUI-based macOS/iOS terminal application

| Aspect | Details |
|--------|---------|
| UI Framework | SwiftUI |
| Data Persistence | SwiftData |
| Testing | Swift Testing (not XCTest) |
| Terminal Engine | SwiftTerm v1.10.1+ |
| Min Deployment | macOS 26.2, iOS 26.2 |
| Build System | Xcode 26.2+ |
| Repository | metamech/Tenrec-Terminal |

**Build & Test:**
```bash
make build    # Build the application
make run      # Build and launch
make test     # Run all tests
make clean    # Clean build artifacts
```

## Architecture

### Project Structure

```
Tenrec Terminal/
├── Models/              — SwiftData models
│   └── TerminalSession.swift
├── ViewModels/          — View-specific logic
├── Views/               — SwiftUI components
│   ├── ContentView.swift
│   └── Terminal/        — Terminal-specific views
├── Services/            — Business logic and utilities
│   └── ShellExecutionPoC.swift
├── Utilities/           — Helper utilities
├── Assets.xcassets/     — App icons and colors
└── Tenrec_TerminalApp.swift — App entry point
```

### MVVM Pattern

- **Models** (`Models/`): SwiftData entities
- **ViewModels** (`ViewModels/`): View-specific logic
- **Views** (`Views/`): SwiftUI components, organized by feature
- **Services** (`Services/`): Business logic, PTY handling, shell execution

### Data Models

**TerminalSession** — SwiftData model in `Models/TerminalSession.swift`

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique session identifier |
| name | String | User-facing session name |
| createdAt | Date | Session creation timestamp |
| status | SessionStatus | Session state: `active`, `inactive`, or `terminated` |
| workingDirectory | String | Shell working directory (default: "~") |

**SessionStatus** — Enum in `Models/TerminalSession.swift`
- `active` — Session is running
- `inactive` — Session is paused or backgrounded
- `terminated` — Session has ended

### Key Patterns

**SwiftData Integration**
- Models use `@Model` decorator for persistence
- App container initialized in `Tenrec_TerminalApp` with schema
- Data persisted to disk by default (not in-memory)
- Previews use in-memory containers to avoid affecting real data

**Testing**
- Unit tests use Swift Testing framework (`@Test` macro)
- UI tests use XCTest for automation
- PoC validation tests ensure sandbox is disabled for terminal functionality

## Development Workflow

### 1. Planning Phase

When starting a task:
1. Summarize relevant code and current behavior
2. Ask clarifying questions with recommendations based on codebase conventions
3. Propose a phased plan. For each phase specify:
   - Purpose and scope
   - Files/functions to change
   - Tests to add or update
   - Recommended Claude model (opus/sonnet/haiku) with rationale
4. Note edge cases and performance considerations where non-obvious

**Before implementing**, enter plan mode and wait for explicit approval.

### 2. GitHub Integration

**If linked to an existing issue:**
- Update the final plan on the issue if it diverges from the description
- Treat technical details in the issue as "pseudo code guidance" (not hard requirements unless explicitly marked)

**If no issue exists:**
- Create one before implementation begins

### 3. Implementation Phase

**Branch & Commits:**
- Create and checkout a feature branch from `main` before starting phase 0
- Feature branch naming: `<type>/X-<slug>` where:
  - `<type>` = issue type (feature, bugfix, docs, etc.)
  - `X` = GitHub Issue number
  - `<slug>` = short description
- Commit after each phase

**Phase Execution:**
- **Before each phase** (including the first), output the phase number, recommended model, and ask: "Ready to proceed with Phase N? (switch to /model <X> if needed)" then **STOP**
- Wait for explicit go-ahead before continuing
- Implement only one phase per response
- After committing a phase, stop and prompt for the next phase

## Important Notes

**Schema & Data**
- SwiftData schema is defined in `Tenrec_TerminalApp` — changes to models must be reflected there
- Previews use in-memory data stores to avoid affecting real data during development
- Model context is automatically provided by SwiftUI's environment

**Pre-Release Constraints**
- No data migrations or legacy compatibility needed

**Architectural Decisions**
- Refer to `docs/ADR/` for detailed Architecture Decision Records:
  - **ADR-001**: App Sandbox vs. Terminal Functionality
  - **ADR-002**: MVVM Architecture with SwiftData

## Maintenance

Keep this file concise and token-efficient:
- **Redundancy**: Remove duplicate explanations or alternative commands (keep one recommended approach)
- **Organization**: Group similar information together; use tables for quick reference
- **Clarity**: Preserve all critical guidance, but remove verbose prose
- **Future Content**: Remove placeholder sections for "future" features or empty directories

Review this file when:
- It exceeds 150 lines and contains 3+ similar sections
- New technologies are adopted (update Quick Start table, Architecture sections)
- Workflow or process changes (update Development Workflow section)
- New architectural decisions are documented (reference in Architectural Decisions, not embedding)

Token efficiency matters—every line in CLAUDE.md is loaded into Claude Code's system prompt
on every interaction.