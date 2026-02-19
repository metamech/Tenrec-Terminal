# Phase 6: Claude Code Session Intelligence (GitHub Issues #11, #14)

## Summary

Rich Claude Code session dashboard in the inspector pane, Claude settings editor, auto-detection of Claude Code in terminals, and a designated "Claude Code Terminal" type that auto-launches `claude`. Builds on Phase 5's monitoring and hooks infrastructure to provide a first-class Claude Code development experience.

## Prerequisites

- Phase 5 complete (`ClaudeDirectoryMonitor`, `HookManager`, `HookEventProcessor`, `ClaudeSession` model all operational)
- Phase 1 complete (multi-session terminals, sidebar, inspector pane)

## Deliverables

### 1. Auto-Detection of Claude Code in Terminals

- When hooks fire or `claude` process detected in a terminal's PTY process tree, automatically create/update `ClaudeSession` and upgrade sidebar display
- Detection sources: (a) hook events with matching working directory, (b) process name monitoring via PTY child process inspection
- Debounced detection to avoid flicker on rapid process starts/stops

### 2. Designated "Claude Code Terminal" Type

- New terminal creation option: "New Claude Code Terminal"
- Sets `workingDirectory` from user selection (directory picker) and auto-runs `claude` on shell start
- `TerminalSession.terminalType` field: enum `.standard`, `.claudeCode(directory: String)`
- On session creation, shell command sequence: `cd <directory> && claude`

### 3. Sidebar Distinction

- Claude terminals show Claude icon + session status badge vs plain terminal icon for standard terminals
- Status badge colors: blue (`.starting`), green (`.running`), yellow (`.waitingInput`), gray (`.idle`), red (`.stopped`)
- Non-Claude terminals unchanged

### 4. Claude Session Dashboard (Issue #14)

`ClaudeSessionDashboard` view in inspector pane with tabs/sections:

- **Activity**: live hook event feed — tool calls with timestamps, relative time ("2 min ago"), tool name + input summary, color-coded by event type
- **Plan**: rendered markdown from plan files (auto-refreshed on file change via `ClaudeDirectoryMonitor`)
- **History**: past sessions from `history.jsonl` filtered by the active terminal's working directory
- **Stats**: token counts and usage from `stats-cache.json`, displayed as simple metric cards

### 5. `ClaudeSessionViewModel` (@Observable)

- Aggregates data from `ClaudeDirectoryState` + `HookEventProcessor`
- Filters by active terminal's `ClaudeSession`
- Publishes: `activityFeed: [HookEvent]`, `currentPlan: ClaudePlan?`, `history: [ClaudeSessionHistory]`, `stats: ClaudeStatsCache?`
- Real-time updates as hook events arrive

### 6. Claude Settings UI (Issue #11)

`ClaudeSettingsView`:
- **Form tab**: section-based editor for permissions, environment variables, hooks overview (read-only display of registered hooks)
- **Raw JSON tab**: full JSON viewer/editor as fallback for advanced users
- Unsaved changes indicator (dot on tab or toolbar badge)
- Undo support via standard `UndoManager`

`ClaudeSettingsViewModel`:
- Reads from `ClaudeDirectoryState`
- Writes back atomically to `~/.claude/settings.json`
- Validation before write (JSON validity, required fields)
- Ignores self-initiated file changes to prevent feedback loops

### 7. Inspector Routing

- When selected terminal has an associated `ClaudeSession`: show `ClaudeSessionDashboard`
- When selected terminal has no `ClaudeSession`: show generic terminal inspector (existing behavior)
- When prompt/template selected: show respective detail view (Phase 4)

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Views/Claude/ClaudeSessionDashboard.swift` | Tab view with Activity, Plan, History, Stats |
| **Create** | `Tenrec Terminal/Views/Claude/ActivityFeedView.swift` | Live event feed with relative timestamps |
| **Create** | `Tenrec Terminal/Views/Claude/PlanView.swift` | Rendered markdown plan, auto-refresh |
| **Create** | `Tenrec Terminal/Views/Claude/HistoryView.swift` | Past sessions filtered by working directory |
| **Create** | `Tenrec Terminal/Views/Claude/StatsView.swift` | Token counts and usage metric cards |
| **Create** | `Tenrec Terminal/Views/Claude/ClaudeSettingsView.swift` | Form editor + raw JSON tab |
| **Create** | `Tenrec Terminal/ViewModels/ClaudeSessionViewModel.swift` | Data aggregation, filtering, real-time updates |
| **Create** | `Tenrec Terminal/ViewModels/ClaudeSettingsViewModel.swift` | Read/write settings, validation, undo |
| **Modify** | `Tenrec Terminal/Models/TerminalSession.swift` | Add `terminalType` enum field |
| **Modify** | `Tenrec Terminal/Views/SidebarView.swift` | Claude icon + status badge for Claude terminals |
| **Modify** | `Tenrec Terminal/Views/DetailPaneView.swift` | Route to `ClaudeSessionDashboard` when Claude session active |
| **Modify** | `Tenrec Terminal/Views/ContentPaneView.swift` | Auto-launch `claude` for designated Claude Code terminals |
| **Create** | `Tenrec TerminalTests/ClaudeSessionViewModelTests.swift` | Data aggregation and filtering tests |
| **Create** | `Tenrec TerminalTests/ClaudeSettingsViewModelTests.swift` | Settings read/write round-trip tests |

## Acceptance Criteria

- [ ] Claude process auto-detected in terminal — sidebar shows Claude icon + status badge
- [ ] "New Claude Code Terminal" creates terminal that auto-launches `claude` in selected directory
- [ ] Dashboard Activity tab shows live event feed updating within 1-2s of hook events
- [ ] Dashboard Plan tab auto-refreshes when plan file changes on disk
- [ ] Dashboard History tab filtered correctly by working directory
- [ ] Dashboard Stats tab displays token counts from stats-cache.json
- [ ] Settings editor reads valid JSON and displays in form sections
- [ ] Settings editor writes modified settings atomically without clobbering unedited fields
- [ ] Non-Claude terminals show generic inspector (no dashboard)
- [ ] Graceful handling when Claude data is missing (empty states, not crashes)
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests (`ClaudeSessionViewModelTests.swift`)
- Activity feed populates from mock hook events in correct order
- Plan updates when `ClaudeDirectoryState` publishes new plan
- History filters by working directory (only matching sessions shown)
- Stats reflect current `ClaudeStatsCache` values
- Empty state when no Claude session associated

### Unit Tests (`ClaudeSettingsViewModelTests.swift`)
- Read settings from mock `ClaudeDirectoryState`
- Modify permission, write back, verify JSON output
- Add environment variable, verify in written JSON
- Validation rejects malformed JSON
- Self-initiated change detection prevents feedback loop

### Auto-Detection Tests
- Hook event with matching working directory creates `ClaudeSession` association
- Process name detection identifies `claude` in PTY child processes
- Multiple terminals with same working directory correctly disambiguated (or associated)
- Detection debouncing: rapid process start/stop doesn't cause flicker

### Activity Feed Tests
- Events displayed in reverse chronological order
- Relative timestamps update correctly ("just now" -> "1 min ago")
- Color coding matches event type

### Integration Considerations
- Use in-memory SwiftData container for all tests
- Mock `ClaudeDirectoryState` and `HookEventProcessor` for ViewModel tests
- Test settings write with temp file (not actual `~/.claude/settings.json`)

## Estimated Complexity

**High** — This phase integrates multiple data sources (hooks, filesystem state, process monitoring) into a cohesive UI. The main challenges are: (1) real-time data flow from three different sources into the dashboard, (2) auto-detection reliability across edge cases (multiple terminals, same directory), (3) settings editor that correctly handles partial edits without data loss, and (4) designated terminal type requiring shell command injection at session start.
