# Tenrec Terminal - Claude Code Configuration

SwiftUI-based macOS/iOS terminal application with SwiftData persistence and SwiftTerm v1.10.1+ engine.

## Quick Reference

| Task | Command |
|------|---------|
| Build | `make build` |
| Run | `make run` (build and launch) |
| Test | `make test` |
| Clean | `make clean` |
| Help | `make help` |

## Tech Stack

| Component | Details |
|-----------|---------|
| **Language** | Swift |
| **Platform** | macOS 26.2+, iOS 26.2+ |
| **UI Framework** | SwiftUI |
| **Persistence** | SwiftData |
| **Testing** | Swift Testing (not XCTest) |
| **Terminal Engine** | SwiftTerm v1.10.1+ |
| **Build System** | Xcode 26.2+ |
| **Repository** | metamech/Tenrec-Terminal |

## Development Workflow

### Planning Phase

1. Summarize relevant code and current behavior
2. Ask clarifying questions with recommendations based on codebase conventions
3. Propose phased plan—for each phase specify:
   - Purpose and scope
   - Files/functions to change
   - Tests to add/update
   - Recommended Claude model with rationale
4. Note edge cases and performance considerations

### GitHub Integration

- Create/link issue before implementation
- Treat issue technical details as "pseudo code guidance" unless marked as strict requirements
- Update plan on issue if it diverges from description

### Implementation Protocol

- **Do not write code** until explicitly instructed
- Create feature branch from `main` before Phase 0: `<type>/<issue-number>-<slug>`
  - `<type>`: feature, bugfix, docs, refactor
  - `<issue-number>`: GitHub issue number
  - `<slug>`: short hyphenated description
- **Before each phase**: Output phase number, recommended model, ask "Ready to proceed with Phase N?" then STOP
- Implement one phase per response
- Commit after each phase; prompt for next phase

### Pre-Release Constraints

⚠️ **Pre-release product**: No data migrations or legacy compatibility required.

## Project Structure

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

## MVVM Pattern

- **Models** (`Models/`): SwiftData entities
- **ViewModels** (`ViewModels/`): View-specific logic
- **Views** (`Views/`): SwiftUI components, organized by feature
- **Services** (`Services/`): Business logic, PTY handling, shell execution

## Data Models

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

## Key Patterns

**SwiftData Integration**
- Models use `@Model` decorator for persistence
- App container initialized in `Tenrec_TerminalApp` with schema
- Data persisted to disk by default (not in-memory)
- Previews use in-memory containers to avoid affecting real data

**Testing**
- Unit tests use Swift Testing framework (`@Test` macro)
- UI tests use XCTest for automation
- PoC validation tests ensure sandbox is disabled for terminal functionality

**Schema & Data**
- SwiftData schema is defined in `Tenrec_TerminalApp`—changes to models must be reflected there
- Previews use in-memory data stores to avoid affecting real data during development
- Model context is automatically provided by SwiftUI's environment

## Architectural Decisions

Refer to `docs/ADR/` for detailed Architecture Decision Records:
- **ADR-001**: App Sandbox vs. Terminal Functionality
- **ADR-002**: MVVM Architecture with SwiftData

## AI Agent Guidelines

- NEVER include AI attribution in commit messages
- Use GitHub MCP tools for issues/PRs (not manual commands)
- Prefer specialized tools (Read, Edit, Grep) over Bash for file operations

## Maintenance

Keep this file concise and token-efficient:
- **Redundancy**: Remove duplicate explanations or alternative commands (keep one recommended approach)
- **Organization**: Group similar information; use tables for quick reference
- **Clarity**: Preserve critical guidance; remove verbose prose
- **Future Content**: Remove placeholder sections for future features or empty directories

Review this file when:
- It exceeds 150 lines and contains 3+ similar sections
- New technologies are adopted (update tech stack/architecture sections)
- Workflow or process changes (update Development Workflow)
- New architectural decisions are documented (reference in docs/, not embed in CLAUDE.md)

Token efficiency matters—every line in CLAUDE.md is loaded into Claude Code's system prompt on every interaction.
