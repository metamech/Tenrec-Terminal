# Claude Code Integration Architecture

## Overview

Tenrec Terminal monitors Claude Code sessions via two complementary channels: filesystem monitoring and hooks. Both feed into a unified state model that drives the UI.

## Data Flow

```
~/.claude/ files ──→ ClaudeDirectoryMonitor ──→ ClaudeDirectoryState (@Observable)
                                                        │
Claude Code hooks ──→ Unix socket ──→ HookEventProcessor ──→ ClaudeSession (SwiftData)
                                              │                       │
Terminal buffer ──→ BufferMonitorService ──────┤               SidebarView
                                              │               ClaudeSessionDashboard
                                              └──→ PendingInput ──→ PendingInputQueue
```

## Filesystem Monitoring

**Target**: `~/.claude/` directory (recursive)

| File | Model | Update Frequency |
|------|-------|-----------------|
| `settings.json` | ClaudeSettings | On change |
| `statsCache.json` | ClaudeStatsCache | On change |
| `projects/{hash}/.history.jsonl` | ClaudeSessionHistory | On change |
| `projects/{hash}/plans/*.md` | ClaudePlan | On change |

**Implementation**: `DispatchSource.makeFileSystemObjectSource` for individual files, FSEvents for directory-level recursive monitoring. Changes debounced at 500ms.

**Protocol**: `CodingAgentDirectoryMonitor` — agent-agnostic interface. Claude is the first implementation. Future: GeminiDirectoryMonitor, etc.

## Hooks System

Claude Code supports hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": "/path/to/hook.sh" }] }],
    "PostToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": "/path/to/hook.sh" }] }],
    "Notification": [{ "matcher": "", "hooks": [{ "type": "command", "command": "/path/to/hook.sh" }] }],
    "Stop": [{ "matcher": "", "hooks": [{ "type": "command", "command": "/path/to/hook.sh" }] }]
  }
}
```

Hook scripts receive JSON on stdin. Tenrec's hook scripts forward this JSON to a Unix domain socket (`~/Library/Application Support/Tenrec Terminal/tenrec.sock`).

**Session Association**: Match Claude session_id to TerminalSession by:
1. Working directory match (primary)
2. Process tree inspection (fallback)
3. PTY environment variable (if set)

## Claude Session States

```
unknown → starting → running → waiting_input → running → idle → stopped
                        ↑           │
                        └───────────┘
```

- **starting**: SessionStart hook received
- **running**: actively processing (tool use events flowing)
- **waiting_input**: PreToolUse requiring approval, or buffer prompt detected
- **idle**: no events for >30s, session still alive
- **stopped**: SessionStop hook received or process terminated

## Auto-Detection

When no hooks are registered yet, detect Claude Code by:
1. Process name monitoring on PTY child processes
2. Terminal title containing "claude" (OSC title sequences)
3. Buffer content matching Claude Code output patterns

Once detected, prompt user to register hooks for full monitoring.

## Designated Claude Terminals

`TerminalSession.terminalType = .claudeCode(directory: "/path/to/repo")`

On creation: shell starts → `cd /path/to/repo && claude` auto-executed.
