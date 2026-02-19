# Phase 5: Claude Code Integration Foundation (GitHub Issues #10, #12)

## Summary

Build the two foundational services for Claude Code awareness: filesystem monitoring of `~/.claude` directory and hooks registration with event processing. These services are agent-agnostic (designed for future extensibility to Gemini CLI, etc.).

## Prerequisites

- Phase 1 complete (multi-session terminals with PTY management)
- Phase 3 (buffer monitoring) recommended for full input detection
- Familiarity with Claude Code's `~/.claude` directory structure and hooks system

## Deliverables

### 1. `CodingAgentDirectoryMonitor` Protocol

`Tenrec Terminal/Services/Protocols/CodingAgentDirectoryMonitor.swift`:
- Agent-agnostic interface for directory monitoring
- Methods: `startMonitoring()`, `stopMonitoring()`
- Published state object conforming to a common protocol

### 2. `ClaudeDirectoryMonitor` Implementation

`Tenrec Terminal/Services/ClaudeDirectoryMonitor.swift`:
- Uses `DispatchSource.makeFileSystemObjectSource` / FSEvents for recursive watching of `~/.claude`
- Publishes parsed state via `ClaudeDirectoryState` (@Observable)
- Debounced updates (500ms coalescing to avoid rapid-fire notifications)
- Graceful handling: missing files, parse errors, `~/.claude` not existing yet

### 3. Parsed Codable Models

| File | Model | Source |
|------|-------|--------|
| `ClaudeSettings.swift` | `ClaudeSettings` | `~/.claude/settings.json` — permissions, environment variables, hooks config |
| `ClaudeStatsCache.swift` | `ClaudeStatsCache` | `~/.claude/stats-cache.json` — token counts, usage stats |
| `ClaudeSessionHistory.swift` | `ClaudeSessionHistory` | `~/.claude/projects/*/history.jsonl` — past session records |
| `ClaudePlan.swift` | `ClaudePlan` | `~/.claude/projects/*/plans/` — markdown plan files |

All models use `Codable` with lenient decoding (unknown keys ignored, optional fields for forward compatibility).

### 4. `ClaudeDirectoryState` (@Observable)

- `settings: ClaudeSettings?`
- `statsCache: ClaudeStatsCache?`
- `sessionHistories: [String: [ClaudeSessionHistory]]` (keyed by project path)
- `plans: [String: [ClaudePlan]]` (keyed by project path)
- `lastUpdated: Date`
- `errors: [ClaudeDirectoryError]` (non-fatal parse/access errors)

### 5. `HookManager` Service

`Tenrec Terminal/Services/HookManager.swift`:
- Registers hooks in `~/.claude/settings.json` for: `PreToolUse`, `PostToolUse`, `Notification`, `Stop` (at minimum)
- Generates executable hook scripts in `~/Library/Application Support/Tenrec Terminal/hooks/`
- Hook scripts: read stdin JSON, forward to Unix domain socket, exit 0
- Registration is additive: does not clobber existing hooks in settings.json
- Provides `unregisterHooks()` for clean removal

### 6. Unix Domain Socket Listener

Part of `HookManager` or separate service:
- Listens on `~/Library/Application Support/Tenrec Terminal/tenrec.sock`
- Accepts connections from hook scripts
- Parses incoming JSON into `HookEvent` objects
- Thread-safe event dispatch to `HookEventProcessor`

### 7. `HookEvent` Codable Model

`Tenrec Terminal/Models/HookEvent.swift`:
- `sessionId: String`
- `eventType: HookEventType` (enum: preToolUse, postToolUse, notification, stop)
- `timestamp: Date`
- `toolName: String?`
- `toolInput: [String: AnyCodable]?`
- `workingDirectory: String?`
- `rawPayload: Data` (original JSON for forward compatibility)

### 8. `HookEventProcessor`

`Tenrec Terminal/Services/HookEventProcessor.swift`:
- Matches Claude `session_id` to `TerminalSession` by working directory + process environment
- Creates/updates `ClaudeSession` SwiftData records
- Publishes events for UI consumption

### 9. `ClaudeSession` SwiftData Model

`Tenrec Terminal/Models/ClaudeSession.swift`:
- `id: UUID`
- `claudeSessionId: String`
- `terminalSessionId: UUID`
- `status: ClaudeSessionStatus` (enum: `.starting`, `.running`, `.waitingInput`, `.idle`, `.stopped`)
- `workingDirectory: String`
- `currentPlanPath: String?`

### 10. Graceful Degradation

- Hook scripts exit 0 cleanly when app is not running (don't block Claude Code)
- Socket errors logged but don't crash the app
- Missing `~/.claude` directory handled — monitor waits for creation
- Malformed JSON files logged as warnings, not errors

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Services/Protocols/CodingAgentDirectoryMonitor.swift` | Protocol definition |
| **Create** | `Tenrec Terminal/Services/ClaudeDirectoryMonitor.swift` | FSEvents watcher, state publisher |
| **Create** | `Tenrec Terminal/Models/Claude/ClaudeSettings.swift` | Codable model for settings.json |
| **Create** | `Tenrec Terminal/Models/Claude/ClaudeStatsCache.swift` | Codable model for stats-cache.json |
| **Create** | `Tenrec Terminal/Models/Claude/ClaudeSessionHistory.swift` | Codable model for history.jsonl |
| **Create** | `Tenrec Terminal/Models/Claude/ClaudePlan.swift` | Codable model for plan markdown |
| **Create** | `Tenrec Terminal/Services/HookManager.swift` | Hook registration, script generation, socket listener |
| **Create** | `Tenrec Terminal/Services/HookEventProcessor.swift` | Event matching, session association, state updates |
| **Create** | `Tenrec Terminal/Models/HookEvent.swift` | Codable event model |
| **Create** | `Tenrec Terminal/Models/ClaudeSession.swift` | SwiftData @Model for Claude session tracking |
| **Modify** | `Tenrec Terminal/Tenrec_TerminalApp.swift` | Add `ClaudeSession` to SwiftData schema, initialize services |
| **Create** | `Tenrec TerminalTests/ClaudeDirectoryMonitorTests.swift` | File change detection tests |
| **Create** | `Tenrec TerminalTests/HookEventProcessorTests.swift` | Event parsing, session association tests |
| **Create** | `Tenrec TerminalTests/ClaudeSettingsParsingTests.swift` | JSON parsing with fixtures |
| **Create** | `Tenrec TerminalTests/Fixtures/sample-settings.json` | Valid settings fixture |
| **Create** | `Tenrec TerminalTests/Fixtures/sample-stats-cache.json` | Valid stats fixture |
| **Create** | `Tenrec TerminalTests/Fixtures/sample-history.jsonl` | Valid history fixture |
| **Create** | `Tenrec TerminalTests/Fixtures/malformed-settings.json` | Malformed JSON fixture |

## Acceptance Criteria

- [ ] File changes in `~/.claude` detected within 1-2 seconds
- [ ] `settings.json`, `stats-cache.json`, `history.jsonl`, `plans/` all parsed correctly
- [ ] Missing or malformed files don't crash — errors logged to `ClaudeDirectoryState.errors`
- [ ] Hook registration adds correct entries to `settings.json` without clobbering existing hooks
- [ ] Hook scripts are executable (`chmod +x`), forward JSON correctly to socket
- [ ] Socket listener receives and parses `HookEvent` objects
- [ ] Session start event associates Claude session with correct `TerminalSession`
- [ ] Tool events update observable `ClaudeSession` status
- [ ] Hook scripts exit 0 when app is not running (don't block Claude Code)
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests (`ClaudeSettingsParsingTests.swift`)
- Parse valid `settings.json` fixture — all fields populated
- Parse `settings.json` with unknown keys — no crash, known fields parsed
- Parse malformed JSON — returns nil or error, no crash
- Parse `stats-cache.json` fixture — token counts correct
- Parse `history.jsonl` — multiple records parsed in order
- Missing optional fields use defaults

### Unit Tests (`ClaudeDirectoryMonitorTests.swift`)
- File creation in temp directory detected
- File modification detected
- File deletion detected
- Debouncing: rapid changes coalesce into single update
- Missing directory handled gracefully (no crash, monitor waits)

### Unit Tests (`HookEventProcessorTests.swift`)
- Parse valid hook event JSON
- Match session by working directory
- Create `ClaudeSession` on first event for new `session_id`
- Update existing `ClaudeSession` status on subsequent events
- Handle unknown event types gracefully

### Integration Considerations
- Use temp directories for filesystem tests (not actual `~/.claude`)
- Socket communication round-trip test (write JSON to socket, verify parsed event)
- In-memory SwiftData container for `ClaudeSession` persistence tests
- Graceful degradation: permission errors, full disk, etc.

## Estimated Complexity

**High** — This phase involves multiple interacting systems: filesystem monitoring with FSEvents, Unix domain socket IPC, JSON parsing of external data formats, and cross-referencing Claude sessions with terminal sessions. The main risks are: (1) FSEvents reliability and debouncing correctness, (2) socket lifecycle management (app start/stop/crash), (3) correctly associating Claude sessions with terminals when multiple sessions share working directories.
