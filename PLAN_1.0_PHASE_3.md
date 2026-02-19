# Phase 3: Shell Integration & Buffer Monitoring

## Summary

Detect command boundaries in terminal output, parse the terminal buffer for prompts and input requests, and build the foundation for the input queue system. This is critical infrastructure for monitoring Claude Code sessions and surfacing "input needed" state to the user.

## Prerequisites

- Phase 1 complete (multi-session lifecycle, `TerminalManagerViewModel`, cached terminal views)
- Phase 2 recommended but not strictly required (no dependency on profiles/search)
- Working `TerminalViewWrapper` with `LocalProcessTerminalView` and `Coordinator` delegate

## Deliverables

### 1. `ShellIntegrationService`

Detect command start/end boundaries using OSC escape sequences (iTerm2/FinalTerm-compatible shell integration protocol):

- **OSC 133;A** — prompt start (FinalTerm)
- **OSC 133;B** — command start (user pressed Enter)
- **OSC 133;C** — command output start
- **OSC 133;D;exitcode** — command finished with exit code

Implementation:
- Hook into SwiftTerm's terminal data stream (via `TerminalDelegate` or by intercepting data before/after the terminal processes it)
- Parse OSC sequences from the byte stream
- Emit structured events: `CommandStarted`, `CommandFinished(exitCode: Int32, duration: TimeInterval)`
- Maintain a `commandHistory: [CommandRecord]` with command text, exit code, start/end timestamps
- Shell integration requires user's shell to emit these sequences (document setup for zsh/bash/fish)

### 2. `BufferMonitorService`

Periodically scan the terminal buffer for known prompt patterns:

- Scan interval: configurable, default 500ms
- Uses SwiftTerm's `terminal.getLine(row:)` to read buffer content
- Strips ANSI escape codes before pattern matching
- Scans only the last N lines (default 10) for efficiency
- Publishes state changes via `@Observable` or `AsyncStream`

Key design decisions:
- Scan from bottom of visible buffer upward
- Debounce: don't re-fire for the same prompt if buffer hasn't changed
- Track a content hash of scanned lines to avoid redundant scans

### 3. `PromptPatternMatcher`

Regex-based detection engine for common input prompts:

**Built-in patterns** (ordered by specificity):
| Pattern | Regex | Category |
|---------|-------|----------|
| Yes/No prompt | `\(y(?:es)?/n(?:o)?\)` (case-insensitive) | confirmation |
| Y/N prompt | `\[Y/n\]` or `\[y/N\]` | confirmation |
| Proceed prompt | `(?i)do you want to (proceed\|continue)` | confirmation |
| Allow/Deny | `(?i)(allow\|deny\|permit\|reject)` | authorization |
| Press Enter | `(?i)press (enter\|return) to continue` | continuation |
| Claude Code tool | `Do you want to run` | claude-code |
| Password prompt | `(?i)(password\|passphrase):?\s*$` | credential |
| Overwrite prompt | `(?i)overwrite.*\?` | confirmation |

**User-defined patterns**:
- Stored in `UserDefaults` as array of `{pattern: String, category: String, label: String}`
- Loaded at service startup, refreshed on `UserDefaults` change notification
- Validated as compilable regex on save

**API**:
- `match(line: String) -> PromptMatch?` — returns first match with pattern category and matched text
- `matchAll(lines: [String]) -> [PromptMatch]` — scan multiple lines
- `PromptMatch`: `line: Int`, `matchedText: String`, `category: PromptCategory`, `patternLabel: String`

### 4. `TerminalBufferState` (@Observable)

Published state object consumed by ViewModels:
- `hasPendingInput: Bool` — true when an unresolved prompt is detected
- `pendingPromptText: String?` — the matched prompt text
- `pendingPromptCategory: PromptCategory?` — classification of the prompt
- `lastCommand: CommandRecord?` — most recent command from shell integration
- `commandHistory: [CommandRecord]` — recent command history (capped at 100)
- `isMonitoring: Bool` — whether buffer scanning is active

### 5. Wire into `TerminalSessionViewModel`

Expose buffer monitoring state to the view layer:
- Add `bufferState: TerminalBufferState` property
- Expose convenience accessors: `hasPendingInput`, `pendingPromptText`, `lastCommand`
- Start `BufferMonitorService` when session becomes active
- Stop monitoring when session is terminated or inactive

### 6. Sidebar input badges

- Show a small badge (orange dot or "!" indicator) on sidebar terminal items that have `hasPendingInput == true`
- Badge clears when the prompt is no longer detected in the buffer (user responded)
- Use SwiftUI `.badge()` modifier or custom overlay

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Services/ShellIntegrationService.swift` | OSC sequence parser, command boundary detection, command history |
| **Create** | `Tenrec Terminal/Services/BufferMonitorService.swift` | Periodic buffer scanning, ANSI stripping, debounced state updates |
| **Create** | `Tenrec Terminal/Services/PromptPatternMatcher.swift` | Regex engine, built-in patterns, user-defined pattern loading |
| **Create** | `Tenrec Terminal/Models/TerminalBufferState.swift` | Observable state: pending input, command history, monitoring status |
| **Create** | `Tenrec Terminal/Models/CommandRecord.swift` | Data struct: command text, exit code, timestamps |
| **Create** | `Tenrec Terminal/Models/PromptMatch.swift` | Match result struct and `PromptCategory` enum |
| **Modify** | `Tenrec Terminal/ViewModels/TerminalSessionViewModel.swift` | Add `bufferState`, start/stop monitoring, expose convenience accessors |
| **Modify** | `Tenrec Terminal/Views/Terminal/TerminalViewWrapper.swift` | Pass terminal data stream to `ShellIntegrationService`; provide buffer access to `BufferMonitorService` |
| **Modify** | `Tenrec Terminal/Views/SidebarView.swift` | Add input-needed badge to terminal items |
| **Create** | `Tenrec TerminalTests/BufferMonitorServiceTests.swift` | Buffer scanning and debounce tests |
| **Create** | `Tenrec TerminalTests/PromptPatternMatcherTests.swift` | Pattern matching with ANSI codes, edge cases, false positive/negative suite |
| **Create** | `Tenrec TerminalTests/ShellIntegrationServiceTests.swift` | OSC parsing tests with mock byte streams |

## Acceptance Criteria

- [ ] Detects "Do you want to proceed? (Y/n)" pattern within 1 second of it appearing in the buffer
- [ ] Detects command completion with exit code when shell integration OSC sequences are present
- [ ] Sidebar shows orange badge on terminals awaiting input; badge clears when user responds
- [ ] Pattern matcher correctly strips ANSI escape codes before matching
- [ ] No false positives on common command output (e.g., `grep` results containing "yes", log lines)
- [ ] Buffer scanning does not block the main thread (runs on background queue/actor)
- [ ] User-defined patterns load from `UserDefaults` and function correctly
- [ ] Monitoring starts automatically for active sessions and stops for terminated ones
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests

**`PromptPatternMatcherTests.swift`** (highest priority):
- Each built-in pattern matches its target string
- Case insensitivity works for confirmation patterns
- ANSI escape codes in input are stripped before matching (e.g., `\e[1m(Y/n)\e[0m` matches)
- Partial lines do not false-positive (e.g., `"The system says yes"` should NOT match Y/N prompt)
- Multi-line scanning returns correct line numbers
- User-defined patterns compile and match correctly
- Invalid regex in user-defined patterns fails gracefully (skipped, not crash)
- Empty input returns no matches

**`BufferMonitorServiceTests.swift`**:
- Scanning last N lines from mock buffer data
- Debounce: same prompt detected twice does not re-fire notification
- Buffer content hash prevents redundant scans
- State transitions: no prompt -> prompt detected -> prompt cleared
- Scan interval configuration works

**`ShellIntegrationServiceTests.swift`**:
- Parse `OSC 133;A` through `OSC 133;D;0` sequence correctly
- Extract exit code from `OSC 133;D` variant
- Command duration calculated from B->D timestamps
- Incomplete/malformed OSC sequences handled gracefully (ignored, not crash)
- Command history capped at configured limit

### Performance
- Buffer scan of 1000 lines completes in < 50ms
- Pattern matching of 10 lines against all built-in patterns completes in < 5ms
- No UI jank during continuous monitoring (verify with Instruments if possible)

## Estimated Complexity

**High** — This phase involves three interconnected services with nontrivial challenges:
1. **OSC parsing**: Requires intercepting SwiftTerm's data stream at the right point in the pipeline. SwiftTerm may or may not expose hooks for this; may need to subclass or use `TerminalDelegate` methods.
2. **Buffer reading**: SwiftTerm's `getLine()` API returns attributed content that needs ANSI stripping. Edge cases around wrapped lines, partial updates, and Unicode.
3. **False positive avoidance**: The prompt pattern matcher must be precise enough to avoid flagging normal command output while catching actual prompts. This requires careful regex design and testing.
4. **Concurrency**: Buffer scanning must run off the main thread but publish state changes back to `@Observable` on the main thread. Requires proper actor isolation or `@MainActor` annotations.
