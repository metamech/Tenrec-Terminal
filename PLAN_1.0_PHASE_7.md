# Phase 7: Input Queue & Notifications (GitHub Issues #13, Feature #10)

## Summary

The key differentiator — consolidated pending input queue and macOS notifications. Developers working across multiple Claude Code sessions can see all "Do you want to proceed?" prompts in one place and respond without switching terminals. Notifications alert about events in non-focused terminals.

## Prerequisites

- Phase 5 complete (hooks infrastructure, `HookEventProcessor`)
- Phase 3 complete (buffer monitoring, `BufferMonitorService`, `PromptPatternMatcher`)
- Phase 6 recommended (Claude session intelligence provides richer context)

## Deliverables

### 1. `PendingInput` SwiftData Model

`Tenrec Terminal/Models/PendingInput.swift`:
- `id: UUID`
- `terminalSessionId: UUID`
- `promptText: String` (the detected question)
- `detectedAt: Date`
- `resolvedAt: Date?`
- `source: PendingInputSource` (enum: `.bufferParsing`, `.hookEvent`)
- `contextSnippet: String` (surrounding terminal output for context)
- `responseOptions: [String]?` (parsed Y/n options)

### 2. `PendingInputViewModel` (@Observable)

- Manages the consolidated input queue across all terminal sessions
- `pendingInputs: [PendingInput]` — all unresolved items, sorted by `detectedAt`
- `pendingCount: Int` — badge count for toolbar/sidebar
- `addFromBufferMonitor(sessionId:, match: PromptMatch, context: String)` — creates `PendingInput` from buffer detection
- `addFromHookEvent(sessionId:, event: HookEvent)` — creates `PendingInput` from Claude hook
- `resolve(inputId:)` — marks as resolved with timestamp
- `respond(inputId:, response: String)` — writes response to correct terminal's PTY stdin, then resolves
- `autoResolveStale()` — checks if terminal buffer changed (user typed response directly), marks resolved
- Subscribes to `BufferMonitorService` and `HookEventProcessor` for new items

### 3. Sidebar "Pending Input" Section

`Tenrec Terminal/Views/Sidebar/PendingInputSection.swift`:
- Collapsible section in sidebar showing pending input count
- List of pending items: terminal name + prompt text preview (truncated)
- Tap item to open `PendingInputPopoverView`
- Badge on sidebar terminal entries showing per-terminal pending input count

### 4. `PendingInputPopoverView`

`Tenrec Terminal/Views/PendingInputPopoverView.swift`:
- Terminal name and working directory header
- Full prompt text with surrounding context (contextSnippet)
- Parsed response options as buttons (e.g., "Yes" / "No" for Y/n prompts)
- "View in Terminal" button — switches to the terminal session
- Smart response: clicking a button writes the response to the terminal's stdin via `PendingInputViewModel.respond()` and marks resolved

### 5. Input Detection Sources

Two sources feed into the same `PendingInput` queue:
- **Buffer monitor** (Phase 3): `BufferMonitorService` detects prompt patterns, calls `PendingInputViewModel.addFromBufferMonitor()`
- **Hook events** (Phase 5): `HookEventProcessor` receives `PreToolUse` events requiring approval, calls `PendingInputViewModel.addFromHookEvent()`

### 6. Auto-Resolve

- When terminal buffer changes after a `PendingInput` was created (user typed a response directly in terminal), mark as resolved
- Poll-based: `BufferMonitorService` already scans periodically — on each scan, check if pending prompts are still visible in the buffer
- If the prompt line is no longer in the last N lines, resolve the corresponding `PendingInput`

### 7. Toolbar Popover

- Toolbar button with badge count showing total pending inputs
- Popover lists all pending items across all terminals for quick access

### 8. `NotificationService`

`Tenrec Terminal/Services/NotificationService.swift`:
- Uses `UNUserNotificationCenter`
- Request permission lazily on first relevant event, not on app launch
- Notification triggers:
  - Claude session completed (`Stop` hook event)
  - Claude session waiting for input (new `PendingInput` created)
  - Tool use blocked / error events from hooks
  - Custom `Notification` hook events
- Notification categories with actionable buttons:
  - "Show Terminal" — foregrounds app, selects correct terminal
  - "Approve" — writes approval response to terminal stdin
  - "Dismiss" — dismisses without action
- Deep linking: `UNNotificationContent.userInfo` contains `terminalSessionId`, used to navigate on tap

### 9. Notification Preferences

`Tenrec Terminal/Views/Settings/NotificationPreferencesView.swift`:
- Per-event-type toggles: session completed, input waiting, tool error, custom hook
- Persisted in `UserDefaults`
- Debounce: max 1 notification per terminal per 5 seconds (configurable)
- Accessible from Settings > Notifications tab

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Models/PendingInput.swift` | SwiftData @Model + `PendingInputSource` enum |
| **Create** | `Tenrec Terminal/ViewModels/PendingInputViewModel.swift` | Queue management, response delivery, auto-resolve |
| **Create** | `Tenrec Terminal/Views/Sidebar/PendingInputSection.swift` | Sidebar section with count badge and item list |
| **Create** | `Tenrec Terminal/Views/PendingInputPopoverView.swift` | Detail view with context, response buttons, "View in Terminal" |
| **Create** | `Tenrec Terminal/Services/NotificationService.swift` | UNUserNotificationCenter wrapper, triggers, deep linking |
| **Create** | `Tenrec Terminal/Views/Settings/NotificationPreferencesView.swift` | Per-event toggles, debounce config |
| **Modify** | `Tenrec Terminal/Views/SidebarView.swift` | Add PendingInputSection, per-terminal badges |
| **Modify** | `Tenrec Terminal/Services/BufferMonitorService.swift` | Feed detected prompts into PendingInputViewModel |
| **Modify** | `Tenrec Terminal/Services/HookEventProcessor.swift` | Feed approval-required events into PendingInputViewModel |
| **Modify** | `Tenrec Terminal/Tenrec_TerminalApp.swift` | Add `PendingInput` to SwiftData schema, register notification delegate |
| **Create** | `Tenrec TerminalTests/PendingInputViewModelTests.swift` | Queue lifecycle, response delivery, auto-resolve |
| **Create** | `Tenrec TerminalTests/NotificationServiceTests.swift` | Trigger conditions, debounce, preference respect |

## Acceptance Criteria

- [ ] Pending inputs from both buffer parsing and hooks appear in queue within 1-2 seconds
- [ ] One-click response from queue writes to correct terminal's PTY stdin
- [ ] Queue items auto-resolve when user responds directly in terminal
- [ ] Sidebar shows pending input section with count; per-terminal badges visible
- [ ] Toolbar popover provides quick access to entire queue
- [ ] Notifications appear for key events when app is in background
- [ ] Clicking notification foregrounds app and selects correct terminal
- [ ] Notification preferences persist and are respected
- [ ] No notification spam (debounce: max 1 per terminal per 5 seconds)
- [ ] Permission requested lazily on first relevant event, not on launch
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests (`PendingInputViewModelTests.swift`)
- Create PendingInput from buffer monitor, verify fields
- Create PendingInput from hook event, verify fields
- Respond to PendingInput: verify response string written to correct terminal's stdin (mock PTY)
- Resolve PendingInput: verify `resolvedAt` set
- Auto-resolve: simulate buffer change, verify stale items resolved
- Queue ordering: newest items first
- Multiple terminals: inputs correctly associated with their terminal session

### Unit Tests (`NotificationServiceTests.swift`)
- Notification triggered for session complete event
- Notification triggered for new PendingInput
- Notification NOT triggered when preference disabled for that event type
- Debounce: rapid events within 5 seconds produce only one notification per terminal
- Deep link userInfo contains correct `terminalSessionId`
- Permission not requested until first trigger event

### Integration Considerations
- Use in-memory SwiftData container for all tests
- Mock `UNUserNotificationCenter` for notification tests
- Mock PTY service for response delivery verification
- Test both input sources (buffer + hooks) feeding into the same queue

## Estimated Complexity

**High** — Multiple interconnected systems: two input sources feeding one queue, response delivery back to terminals, auto-resolve logic, macOS notification integration with deep linking, and preferences. The main challenges are: (1) correctly routing responses to the right terminal's stdin, (2) auto-resolve logic that avoids false positives, (3) notification deep linking and category actions, and (4) debounce logic across rapid hook events.
