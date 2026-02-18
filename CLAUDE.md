# Project: Tenrec Terminal

## Purpose

Tenrec Terminal is a native macOS and iOS terminal emulator built with SwiftUI and SwiftTerm. It provides PTY-based shell execution, session persistence via SwiftData, and a first-class Apple platform experience. The App Sandbox is disabled by necessity for terminal functionality — this is a deliberate architectural decision (see ADR-001).

## Platform & Targets

- **Language**: Swift (latest, targeting strict concurrency)
- **Platforms**: macOS 26.2+, iOS 26.2+
- **Distribution**: App Store (or direct distribution — TBD)
- **UI**: SwiftUI
- **Terminal Engine**: SwiftTerm v1.10.1+
- **Persistence**: SwiftData

## Tech Stack

| Component | Details |
|-----------|---------|
| **Language** | Swift |
| **OS Targets** | macOS 26.2+, iOS 26.2+ |
| **Architecture** | MVVM |
| **UI Framework** | SwiftUI |
| **Terminal Engine** | SwiftTerm v1.10.1+ |
| **Persistence** | SwiftData |
| **Testing (unit)** | Swift Testing (`@Test`, `@Suite`, `#expect`) |
| **Testing (UI)** | XCTest / XCUITest |
| **Build System** | Xcode + Make |

## Architectural Guidelines

### MVVM Structure
```
Tenrec Terminal/
  Models/          — SwiftData @Model classes (TerminalSession, etc.)
  ViewModels/      — @Observable view-specific logic
  Views/           — SwiftUI components, organized by feature
    Terminal/      — Terminal-specific views (emulator surface, scrollback)
  Services/        — PTY management, shell execution, SwiftTerm bridge
  Utilities/       — Shared helpers
```

### Key Domain Models
- **TerminalSession**: `id`, `name`, `createdAt`, `status` (active/inactive/terminated), `workingDirectory`
- **SessionStatus**: `active`, `inactive`, `terminated`

### Critical Rules
- App Sandbox **must remain disabled** — required for PTY/shell access (ADR-001).
- SwiftData schema changes must be reflected in the schema definition in `Tenrec_TerminalApp`.
- Previews use in-memory SwiftData containers — never affect real data.
- PTY lifecycle (creation, signaling, cleanup) must be handled in Services, not ViewModels.
- Use `async/await` for all shell I/O streaming; no blocking calls on the main thread.

## Commands

| Task | Command |
|------|---------|
| Build | `make build` |
| Run | `make run` |
| Test | `make test` |
| Clean | `make clean` |

## Subagents and Roles

Use subagents for large refactors or multi-step features:

- **architect** — Owns project structure, MVVM boundaries, SwiftTerm integration strategy, sandbox decisions, and this CLAUDE.md.
- **swiftui-specialist** — Owns SwiftUI views, terminal rendering surface, keyboard handling, session management UI, and platform-adaptive layouts.
- **terminal-backend-engineer** — Owns PTY management, SwiftTerm bridge, shell execution, session lifecycle, and async I/O streaming.
- **test-engineer** — Owns all test suites (Swift Testing unit + XCTest UI, including sandbox PoC validation) and ensures they pass.
- **feature-implementer** — Implements features from PLAN.md using test-first development.
- **integration-tester** — Runs tests, diagnoses failures, reports without modifying code.
- **prompt-engineer** — Owns CLAUDE.md, agent prompts, and documentation quality.
- **git-ops** — Owns all git/GitHub operations (branches, commits, PRs, issues, CI).

## Workflow Rules

- Always read this CLAUDE.md before making significant changes.
- Before starting work, propose a concrete plan and ask for approval.
- Keep a running log in `claude-progress.md`:
  - What was planned.
  - What was completed.
  - Design decisions and trade-offs made.
- Do not change without explicit approval:
  - Bundle identifier.
  - Entitlements (especially sandbox setting — see ADR-001).
  - Signing configuration.
  - Deployment targets.
- Create a feature branch before any implementation: `<type>/<issue-number>-<slug>`.
- Before each phase, output phase number + recommended model, ask "Ready to proceed?" then STOP.
- Commit after each phase; prompt for the next.

## Quality Gates (Pre-Commit)

- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] Sandbox entitlement unchanged
- [ ] No debug code left in

## Documentation References

- `docs/ADR/ADR-001.md` — App Sandbox vs. Terminal Functionality
- `docs/ADR/ADR-002.md` — MVVM Architecture with SwiftData
- `README.md` — Project overview

## AI Agent Guidelines

- NEVER include AI attribution in commit messages.
- Use GitHub MCP tools for issues/PRs (not manual gh commands unless necessary).
- Prefer dedicated tools (Read, Edit, Grep) over Bash for file operations.

## Maintenance

Keep this file concise and token-efficient (target: under 150 lines):
- Remove redundant explanations; one recommended approach per task.
- Reference `docs/ADR/` for architectural decisions; don't embed them here.
- Update when tech stack changes, architecture decisions are made, or workflow evolves.
- Every line is loaded into every Claude Code interaction — token cost is real.
