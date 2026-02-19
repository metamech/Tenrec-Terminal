# Input Queue Design

## Problem

Developers running 3-5 parallel Claude Code sessions face constant "Do you want to proceed?" interruptions. Currently they must switch to each terminal to respond. This is the #1 pain point.

## Solution

Consolidated input queue that aggregates pending inputs from all terminals into a single, actionable view.

## Input Sources

### 1. Buffer Parsing (All Terminals)
Terminal buffer scanned every 500ms for prompt patterns:
- `(Y/n)`, `(yes/no)`, `(y/N)` — binary choice
- `Do you want to proceed?`, `Allow?`, `Continue?` — confirmation
- `Press Enter to continue` — acknowledgment
- `Enter password:`, `Passphrase:` — sensitive input (flag, don't display)
- User-defined patterns (stored in UserDefaults)

ANSI escape codes stripped before pattern matching. Only the last N lines scanned (configurable, default 20).

### 2. Hook Events (Claude Code Terminals)
- `PreToolUse` events for tools requiring approval (Bash, Write, etc)
- Hook event includes tool name, input preview, session context
- Higher fidelity than buffer parsing for Claude-specific prompts

### 3. Resolution Detection
A PendingInput is auto-resolved when:
- Terminal buffer changes after the prompt line (user typed something)
- Hook event indicates tool was approved/denied
- Terminal process exits
- Manual dismissal from queue UI

## Data Model

```swift
@Model final class PendingInput {
    var id: UUID
    var terminalSessionId: UUID
    var promptText: String          // The detected prompt
    var contextSnippet: String      // 3-5 lines of surrounding output
    var detectedAt: Date
    var resolvedAt: Date?
    var source: InputSource         // .bufferParsing or .hookEvent
    var responseOptions: [String]?  // Parsed options: ["Yes", "No"]
    var inputType: InputType        // .confirmation, .choice, .freeText, .sensitive
}
```

## UX

### Sidebar Section
- "Pending Input (3)" with badge count
- List items show: terminal name, prompt preview, time ago
- Click → popover with full context and response buttons

### Quick Response
- Parsed options shown as buttons: [Yes] [No] [View Terminal]
- Clicking a button writes the response string to terminal stdin
- For `(Y/n)`: "Yes" writes "Y\n", "No" writes "n\n"
- For freetext: show text field with submit button

### Toolbar Popover
- Bell icon with badge in toolbar
- Popover shows compact queue list
- One-click approve/deny for simple prompts

## Performance

- Buffer scanning on background thread, not main actor
- Pattern matching with pre-compiled regex (created once, reused)
- Debounce: same prompt detected within 2s = single PendingInput
- Max queue size: 50 items (oldest auto-archived)
