# Tenrec Terminal — 1.0 MVP Plan

## Vision

A native macOS terminal emulator purpose-built for parallel Claude Code development. Monitors Claude Code sessions via hooks and filesystem watching, consolidates pending input across sessions, and provides prompt/template tooling — all in a polished SwiftUI app with commercial licensing.

## Scope

**In 1.0**: Multi-session terminals, split panes, profiles/themes, terminal search, shell integration, buffer parsing, prompts/templates, Claude Code hooks + directory monitoring, session intelligence dashboard, consolidated input queue, notifications, feature flags, licensing (cryptographic offline), Sparkle auto-updates, .dmg distribution, comprehensive logging/metrics.

**Post-1.0**: MLX local LLM, AI prompt analysis, remote Tenrec terminals (Bonjour), usage tracking panel, iOS support. See [PLAN_FUTURE.md](PLAN_FUTURE.md).

**Platform**: macOS 26.2+ only. macOS-first, iOS deferred.

## Phases (10)

| # | Phase | Key Deliverables | GitHub Issues |
|---|-------|-----------------|---------------|
| 1 | [Multi-Session Terminal Lifecycle](PLAN_1.0_PHASE_1.md) | Concurrent PTYs, create/close/switch, view caching, session persistence | #5 |
| 2 | [Terminal Profiles, Themes & Search](PLAN_1.0_PHASE_2.md) | Color schemes, fonts, Cmd+F search, terminal preferences | — |
| 3 | [Shell Integration & Buffer Monitoring](PLAN_1.0_PHASE_3.md) | Command boundaries, prompt detection, buffer parsing service | — |
| 4 | [Prompts & Templates](PLAN_1.0_PHASE_4.md) | SwiftData models, CRUD, editor UI, template parameters, send-to-terminal | #6, #7 |
| 5 | [Claude Code Integration Foundation](PLAN_1.0_PHASE_5.md) | ~/.claude monitoring, hooks registration, event processing, session association | #10, #12 |
| 6 | [Claude Code Session Intelligence](PLAN_1.0_PHASE_6.md) | Dashboard, settings UI, auto-detect + designated terminals, sidebar status | #11, #14 |
| 7 | [Input Queue & Notifications](PLAN_1.0_PHASE_7.md) | Consolidated pending input queue, macOS notifications, deep linking | #13, feature #10 |
| 8 | [Split Panes](PLAN_1.0_PHASE_8.md) | Horizontal/vertical splits, pane management, keyboard navigation | — |
| 9 | [Feature Flags, Licensing & Logging](PLAN_1.0_PHASE_9.md) | Local feature flags, cryptographic licensing, 3-session limit, logging/metrics | — |
| 10 | [Keyboard Shortcuts, Menus & Distribution](PLAN_1.0_PHASE_10.md) | App menu, shortcuts, .dmg, Sparkle, notarization, final testing | #16, #17, #18 |

## SwiftData Models

| Model | Key Fields | Notes |
|-------|-----------|-------|
| `TerminalSession` | id, name, status, workingDirectory, profileId, lastActiveAt, colorTag, splitConfig | Expand existing model |
| `TerminalProfile` | id, name, fontFamily, fontSize, colorScheme, cursorStyle, opacity | Reusable terminal appearance |
| `Prompt` | id, title, content, category, isFavorite, createdAt, updatedAt | Markdown text snippets |
| `PromptTemplate` | id, title, templateBody, parameters, category, createdAt, updatedAt | Parameterized prompt generators |
| `HookEvent` | id, sessionId, type, timestamp, payload, terminalSessionId | Claude Code hook events |
| `ClaudeSession` | id, claudeSessionId, terminalSessionId, status, workingDirectory, planPath | Tracks Claude Code session state |
| `PendingInput` | id, terminalSessionId, promptText, detectedAt, resolvedAt, source | Input queue items |
| `License` | key, email, purchaseDate, expiryDate, isValid | Offline license validation |

## Component Hierarchy

```
Tenrec_TerminalApp
├── MainWindowView
│   └── NavigationSplitView
│       ├── SidebarView
│       │   ├── TerminalListSection (status badges, input queue count)
│       │   ├── PendingInputSection (consolidated queue)
│       │   ├── PromptLibrarySection
│       │   └── TemplateLibrarySection
│       ├── ContentPaneView
│       │   ├── TerminalContainerView (manages splits)
│       │   │   └── TerminalSurfaceView (SwiftTerm wrapper)
│       │   ├── PromptEditorView
│       │   └── TemplateEditorView
│       └── InspectorPaneView
│           ├── TerminalInspectorView (session metadata)
│           ├── ClaudeSessionDashboard (activity, plan, history, stats)
│           ├── PromptDetailView
│           └── TemplateDetailView
├── PendingInputPopoverView
├── PreferencesWindow (profiles, licensing, feature flags)
└── OnboardingWindow (license entry, Sparkle opt-in)
```

## File Structure

```
Tenrec Terminal/
├── Models/                    — SwiftData @Model classes
│   ├── TerminalSession.swift
│   ├── TerminalProfile.swift
│   ├── Prompt.swift
│   ├── PromptTemplate.swift
│   ├── ClaudeSession.swift
│   ├── HookEvent.swift
│   ├── PendingInput.swift
│   └── License.swift
├── ViewModels/                — @Observable view logic
│   ├── TerminalManagerViewModel.swift
│   ├── TerminalSessionViewModel.swift
│   ├── SidebarViewModel.swift
│   ├── PromptViewModel.swift
│   ├── TemplateViewModel.swift
│   ├── ClaudeSessionViewModel.swift
│   ├── PendingInputViewModel.swift
│   └── LicenseViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── Sidebar/
│   ├── Terminal/
│   │   ├── TerminalViewWrapper.swift
│   │   ├── TerminalContainerView.swift
│   │   ├── TerminalSearchBar.swift
│   │   └── SplitPaneView.swift
│   ├── Prompts/
│   ├── Claude/
│   ├── Settings/
│   └── Onboarding/
├── Services/
│   ├── PTYService.swift
│   ├── ShellIntegrationService.swift
│   ├── BufferMonitorService.swift
│   ├── ClaudeDirectoryMonitor.swift
│   ├── HookManager.swift
│   ├── HookEventProcessor.swift
│   ├── NotificationService.swift
│   ├── LicenseService.swift
│   ├── FeatureFlagService.swift
│   ├── LoggingService.swift
│   └── MetricsService.swift
├── Utilities/
└── Resources/
    └── DefaultProfiles/
```

## Testing Strategy

| Phase | Testing Focus |
|-------|--------------|
| 1 | TerminalManagerVM unit tests, session lifecycle, PTY cleanup |
| 2 | Profile persistence, theme application, search in buffer |
| 3 | Buffer parsing accuracy, command boundary detection, prompt pattern matching |
| 4 | CRUD operations, template rendering, parameter substitution |
| 5 | File change detection, hook event parsing, session association |
| 6 | Dashboard data flow, auto-detection logic, settings round-trip |
| 7 | Input queue lifecycle, notification delivery, deep linking |
| 8 | Split creation/removal, focus traversal, pane resize |
| 9 | License validation, feature flag gates, log export |
| 10 | UI tests (XCTest), keyboard shortcuts, menu commands, >70% coverage |

**Framework**: Swift Testing (`@Test`, `@Suite`, `#expect`) for unit tests. XCTest for UI tests.

## Key Architecture Documents

- [ADR-001: App Sandbox Disabled](docs/ADR/001-app-sandbox-vs-terminal-functionality.md)
- [ADR-002: MVVM with SwiftData](docs/ADR/002-mvvm-architecture-with-swiftdata.md)
- [Claude Code Integration Architecture](docs/claude-integration-architecture.md)
- [Input Queue Design](docs/input-queue-design.md)
- [Licensing Architecture](docs/licensing-architecture.md)

## Progress

See [PROGRESS.md](PROGRESS.md) for current implementation status.
