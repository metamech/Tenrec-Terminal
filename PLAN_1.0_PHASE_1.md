# Phase 1: Multi-Session Terminal Lifecycle (GitHub Issue #5)

## Summary

Support multiple concurrent terminal sessions with independent PTY processes. Create/switch/close sessions with preserved scrollback. Foundation for all subsequent phases.

## Prerequisites

- Issues #1-4 complete (current state)
- Single terminal working with SwiftTerm via `TerminalViewWrapper` + `LocalProcessTerminalView`
- SwiftData persistence for `TerminalSession` model operational
- Sidebar already renders sessions from `@Query` and supports creating new ones

## Deliverables

### 1. Expand `TerminalSession` model

Add fields to support multi-session management:
- `lastActiveAt: Date` — updated on session switch, used for sorting
- `colorTag: String?` — optional sidebar color dot for visual organization

### 2. `TerminalManagerViewModel` (@Observable)

Central coordinator for multi-session state:
- `activeSessionId: UUID?` — currently focused session
- `sessions` — backed by SwiftData `@Query`
- `createSession() -> TerminalSession` — auto-names "Terminal 1", "Terminal 2" etc. (finds next available number)
- `closeSession(id:)` — terminates PTY, updates SwiftData status, selects adjacent session
- `switchToSession(id:)` — updates `activeSessionId`, sets `lastActiveAt`
- `renameSession(id:, name:)` — updates session name

### 3. Refactor sidebar terminal list

- Status indicators: green circle (`.active`), gray circle (`.inactive`), red circle (`.terminated`)
- Double-click label to rename inline (use `TextField` with `onSubmit`)
- Sort by `lastActiveAt` descending (most recent first)
- Right-click context menu: Rename, Close, Copy Session ID

### 4. Terminal view caching

When switching sessions, hide/show terminal views rather than recreating them. Current implementation in `ContentPaneView` creates a new `TerminalViewWrapper` on each selection change, which destroys the PTY.

Strategy:
- Maintain a `Dictionary<UUID, TerminalViewWrapper>` (or backing `LocalProcessTerminalView`) keyed by session ID
- Use `ZStack` with `.opacity(0)` / `.opacity(1)` to show/hide, or `NSViewRepresentable` lifecycle management
- Only create the terminal view on first access; cache thereafter
- Remove from cache when session is closed

### 5. Session naming

- Auto-name: "Terminal 1", "Terminal 2" based on next available sequential number
- Double-click sidebar label to rename (inline `TextField`)

### 6. Close confirmation

- `Cmd+W` on an active session shows confirmation alert: "Terminal is running a process. Close anyway?"
- If session is already terminated, close immediately without confirmation

### 7. Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New terminal session |
| `Cmd+W` | Close current session (with confirmation if running) |
| `Cmd+1` through `Cmd+9` | Switch to session by sidebar index |

### 8. Persistence across relaunch

- Sessions persist in SwiftData across app relaunch
- On relaunch, previously-active sessions show as `.inactive` (not `.active`) since PTY processes are gone
- User can see stopped sessions and optionally restart them (stretch goal — minimum is display)

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Modify** | `Tenrec Terminal/Models/TerminalSession.swift` | Add `lastActiveAt`, `colorTag` fields; update `init` |
| **Create** | `Tenrec Terminal/ViewModels/TerminalManagerViewModel.swift` | New file: session CRUD, switching, naming logic |
| **Modify** | `Tenrec Terminal/Views/SidebarView.swift` | Status indicators, inline rename, context menu, sort order, keyboard shortcuts |
| **Modify** | `Tenrec Terminal/Views/ContentPaneView.swift` | Replace per-selection `TerminalViewWrapper` creation with cached view dictionary; `ZStack`-based show/hide |
| **Modify** | `Tenrec Terminal/Views/Terminal/TerminalViewWrapper.swift` | Support identity-based caching; ensure `dismantleNSView` only fires on explicit close |
| **Modify** | `Tenrec Terminal/Tenrec_TerminalApp.swift` | Schema update if needed for new fields |
| **Modify** | `Tenrec Terminal/ViewModels/SidebarViewModel.swift` | Wire to `TerminalManagerViewModel` or replace with it |
| **Create** | `Tenrec TerminalTests/TerminalManagerViewModelTests.swift` | Unit tests for all ViewModel logic |

## Acceptance Criteria

- [ ] Multiple independent terminal sessions run simultaneously (at least 3 concurrent)
- [ ] Switching sessions preserves scrollback and running process state
- [ ] Closing a session terminates its shell process and updates SwiftData status to `.terminated`
- [ ] Keyboard shortcuts `Cmd+T`, `Cmd+W`, `Cmd+1-9` all functional
- [ ] Status indicators show correct state (green/gray/red) in sidebar
- [ ] Auto-naming produces sequential names; rename via double-click works
- [ ] Close confirmation appears for active sessions, not for terminated ones
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests (`TerminalManagerViewModelTests.swift`)
- `createSession()` produces correct sequential names
- `closeSession(id:)` updates status to `.terminated`
- `switchToSession(id:)` updates `activeSessionId` and `lastActiveAt`
- `renameSession(id:, name:)` persists new name
- Closing last session leaves `activeSessionId` as `nil`
- Closing middle session selects adjacent session

### Integration Considerations
- Use in-memory SwiftData container for all tests
- Session lifecycle state transitions: `.active` -> `.terminated` on close
- Persistence round-trip: create session, save, fetch, verify fields

## Estimated Complexity

**Medium** — The core logic is straightforward CRUD + state management. The main challenge is terminal view caching (keeping `LocalProcessTerminalView` instances alive across SwiftUI view updates without recreating them). This requires careful `NSViewRepresentable` lifecycle management.
