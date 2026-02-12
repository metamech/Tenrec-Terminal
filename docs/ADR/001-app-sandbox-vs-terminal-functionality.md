# ADR-001: App Sandbox vs. Terminal Functionality

## Decision

Disable macOS App Sandbox; enable Hardened Runtime for code signing and notarization.

## Context

Terminal emulator functionality requires PTY allocation (`posix_openpt()`) and unrestricted shell process execution. The macOS App Sandbox blocks both operations. We evaluated four approaches:

1. **Disable Sandbox** — ✅ Viable, industry standard, low complexity
2. **XPC + SMAppService Helper** — ⚠️ Insufficient (sandboxed main app cannot access PTY devices)
3. **NSTask + Sandbox Exceptions** — ❌ No public entitlements exist for these operations
4. **Keep Sandbox** — ❌ Contradicts core terminal functionality

Every major macOS terminal emulator (Terminal.app, iTerm2, Warp, CodeEdit, Alacritty, kitty) disables the sandbox. SwiftTerm documentation explicitly states: "You will generally want to disable the sandbox."

## Decision Rationale

- Only viable technical path to full terminal functionality
- Industry standard practice across all shipping terminal emulators
- Clear precedent and documentation
- Hardened Runtime + code signing + notarization provide security equivalent to sandboxed apps
- No XPC/IPC complexity needed; straightforward implementation

## Consequences

- ❌ App ineligible for Mac App Store
- ✅ Direct distribution via website or Homebrew
- ✅ Sparkle framework for automatic updates
- ✅ Code signing and notarization required
- ✅ Full terminal functionality: PTY allocation, shell execution, I/O redirection

## See Also

- `docs/sandbox-research.md` — Detailed research and comparison of all four approaches
- `Services/ShellExecutionPoC.swift` — PoC validation of PTY and shell execution
- `Tenrec_TerminalTests.swift` — Tests validating functionality works
