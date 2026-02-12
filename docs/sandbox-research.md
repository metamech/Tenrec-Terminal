# Sandbox Research: Terminal Functionality in macOS App Sandbox

## Executive Summary

Tenrec Terminal requires PTY allocation and shell process execution to function as a terminal emulator. The macOS App Sandbox (currently enabled) **blocks both** `posix_openpt()` and unrestricted `Process` execution. After evaluating all four approaches, **disabling the App Sandbox is the only viable path** and matches industry practice across all major terminal emulators.

## Problem Statement

Terminal emulator functionality requires two core capabilities:
1. **PTY Allocation:** `posix_openpt()`, `grantpt()`, `unlockpt()` syscalls
2. **Shell Process Execution:** Unrestricted spawning of `/bin/zsh`, `/bin/bash`, etc.

The macOS App Sandbox is a security mechanism that restricts these operations. It cannot be partially disabled for just these operations.

## Approach Comparison

| Approach | Viable? | App Store? | Complexity | Industry Standard? |
|---|---|---|---|---|
| **Disable Sandbox** | ✅ Yes | ❌ No | Low | ✅ Yes (all emulators) |
| XPC + SMAppService Helper | ⚠️ Partial* | ❌ No | High | ❌ No |
| NSTask + Sandbox Exceptions | ❌ No | ❌ No | Medium | ❌ No |
| Keep Sandbox Enabled | ❌ No | ✅ Yes | N/A | ❌ No |

*XPC helper approach technically possible but adds significant complexity without solving the core PTY issue; not used by any shipping terminal emulator.

## Detailed Approach Analysis

### 1. Disable App Sandbox (Recommended)

**Summary:** Remove `ENABLE_APP_SANDBOX = YES` from build configuration and enable Hardened Runtime instead.

**Pros:**
- Full, unrestricted terminal functionality
- Lowest implementation complexity
- Standard practice across the industry
- Clear path to code signing and notarization
- No XPC/IPC complexity
- SwiftTerm documentation recommends this approach

**Cons:**
- App cannot be distributed via Mac App Store
- Requires code signing and notarization for distribution
- User must accept security permissions at first launch

**Implementation:**
- Modify `project.pbxproj`: change `ENABLE_APP_SANDBOX = YES` to `NO` (lines 398, 428)
- Remove `ENABLE_USER_SELECTED_FILES = readonly` (sandbox-only setting)
- Add `ENABLE_HARDENED_RUNTIME = YES` for code signing/notarization
- No code changes required

### 2. XPC + SMAppService Helper

**Summary:** Create a privileged helper process via `SMAppService` that runs outside sandbox and communicates via XPC.

**Pros:**
- Main app can technically remain sandboxed (though still ineligible for App Store)
- Demonstrates privilege separation

**Cons:**
- **PTY allocation still impossible in sandboxed main app** — helper can allocate PTY but main app cannot read/write it
- Requires implementing bi-directional XPC communication
- Complex state management between processes
- Helper needs elevation (SMAppService)
- Significant code complexity; no shipping terminal uses this
- Not viable for true terminal functionality

**Why It Fails:**
Even with an XPC helper allocating the PTY, the sandboxed main app cannot access `/dev/tty*` devices. The sandbox restrictions apply regardless of who allocates the PTY.

### 3. NSTask + Sandbox Exceptions

**Summary:** Request sandbox exception entitlements for `posix_openpt` and process execution.

**Pros:**
- Keeps App Sandbox enabled
- Could theoretically work for simple use cases

**Cons:**
- **No public sandbox exceptions exist for PTY allocation** — `posix_openpt()` cannot be sandboxed safely
- `NSTask` / `Process` restrictions cannot be individually exempted
- Exceptions are typically for file system access, not low-level syscalls
- No shipping app uses this approach
- Apple does not provide entitlements for these operations

**Verdict:** Not a viable technical path.

### 4. Keep Sandbox Enabled

**Summary:** Implement a limited terminal without full shell access (e.g., read-only file browser, preset commands only).

**Pros:**
- Eligible for Mac App Store
- Full sandbox security

**Cons:**
- **Not a terminal emulator** — defeats the purpose of the project
- Contradicts core functionality requirements
- Severely limits user experience and use cases

## Real-World Implementations

Every major macOS terminal emulator disables the sandbox:

| Product | Sandbox Disabled? | Notes |
|---|---|---|
| **Terminal.app** | ✅ Yes | System app, never sandboxed |
| **iTerm2** | ✅ Yes | Industry standard; explicitly disabled |
| **Warp** | ✅ Yes | Modern Rust-based terminal |
| **CodeEdit** | ✅ Yes | Open-source macOS editor with integrated terminal |
| **Alacritty** | ✅ Yes | Cross-platform terminal emulator |
| **kitty** | ✅ Yes | Fast GPU-based terminal |

**SwiftTerm Library:** The industry-standard Swift framework for terminal emulation explicitly states in its documentation:
> "You will generally want to disable the sandbox in your application to allow PTY allocation and shell execution."

## Security Considerations

**Disabling the sandbox does NOT eliminate security:**
- Hardened Runtime provides code-signing and memory protections
- Code signing prevents unauthorized modification
- Notarization scans for malware
- Modern macOS security features (ASLR, DEP, SIP) remain active
- Users control what shell code executes; they control their terminal input

**This is the same security model used by:**
- Terminal.app (system)
- All commercial/open-source terminal emulators
- IDEs like Xcode, VS Code, JetBrains products

## Recommendation

**Disable App Sandbox and enable Hardened Runtime.**

**Rationale:**
1. Only viable path to full terminal functionality
2. Industry standard across all shipping terminal emulators
3. Clear technical precedent (SwiftTerm docs, iTerm2, etc.)
4. Enables direct distribution + Sparkle updates
5. Code signing + notarization provide sufficient security
6. No architectural complexity or workarounds needed

**Path Forward:**
1. Modify `project.pbxproj` (lines 398-400, 428-430)
2. Create PoC shell execution test to validate
3. Document architectural decision in `CLAUDE.md`
4. Plan distribution strategy (direct, Homebrew, Sparkle)

## References

- [SwiftTerm GitHub](https://github.com/migueldeicaza/SwiftTerm) — "you will generally want to disable the sandbox"
- [App Sandbox Overview](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/) — Apple's sandbox documentation
- [Hardened Runtime Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements) — Code signing protections
- [Notarization Overview](https://developer.apple.com/documentation/notarytool) — App notarization and security
