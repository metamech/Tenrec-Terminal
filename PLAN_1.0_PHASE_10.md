# Phase 10: Keyboard Shortcuts, Menus & Distribution (GitHub Issues #16, #17, #18)

## Summary

Final polish — comprehensive keyboard shortcuts, application menu bar, accessibility, .dmg distribution with Sparkle auto-updates, Apple notarization, and comprehensive testing. Ship it.

## Prerequisites

- All previous phases (1-9) complete
- Developer ID certificate available for code signing
- Appcast hosting location determined (for Sparkle updates)

## Deliverables

### 1. App Menu Bar (Issue #16)

`Tenrec Terminal/Views/AppMenu.swift` (SwiftUI `Commands` struct):

| Menu | Item | Shortcut |
|------|------|----------|
| **File** | New Terminal | Cmd+T |
| | New Claude Terminal | Cmd+Shift+T |
| | New Prompt | Cmd+N |
| | Close Tab | Cmd+W |
| | Close Pane | Cmd+Shift+W |
| **Edit** | Cut | Cmd+X |
| | Copy | Cmd+C |
| | Paste | Cmd+V |
| | Select All | Cmd+A |
| **View** | Toggle Sidebar | Cmd+Opt+S |
| | Toggle Inspector | Cmd+Opt+I |
| | Toggle Pending Input | Cmd+Opt+P |
| **Terminal** | Clear | Cmd+K |
| | Send Prompt | Cmd+Return |
| | Stop Process | Cmd+. |
| | Split Vertical | Cmd+D |
| | Split Horizontal | Cmd+Shift+D |
| | Find | Cmd+F |
| **Window** | Standard macOS window management | (system defaults) |

### 2. Focus Management

- `@FocusState` for terminal keyboard capture
- Terminal captures all keyboard input when focused
- Focus releases correctly when switching to sidebar, inspector, or other UI
- Focus follows split pane navigation (Cmd+Opt+Arrow)
- Focus transfers to new terminal on creation, to sibling on close

### 3. Copy/Paste

- Cmd+C: copies current terminal text selection to system clipboard
- Cmd+V: pastes system clipboard content to terminal's PTY stdin
- Integration with SwiftTerm's selection and clipboard APIs

### 4. Window Restoration

- `NSWindow` state restoration: position, size, sidebar visibility
- Remembered across relaunch via `NSWindowRestoration` or SwiftUI scene storage
- Active terminal session restored (selected in sidebar)

### 5. Accessibility

Applied across all views:
- VoiceOver labels and hints on all interactive elements (buttons, lists, toggles)
- `accessibilityLabel` on terminal panes (e.g., "Terminal: session name")
- Keyboard navigation through all UI elements (Tab, Shift+Tab)
- High contrast support: respect `accessibilityContrast` environment value
- Reduced motion: respect `accessibilityReduceMotion` for animations
- Dynamic Type support where applicable (sidebar, settings, prompts)

### 6. Sparkle Auto-Updates (Issue #18)

- Add Sparkle as SPM dependency
- `SparkleOptInView`: shown on first launch or in Settings > Updates
- User opt-in for automatic update checks
- Appcast URL configured (documented, not hardcoded for development)
- Manual "Check for Updates" in app menu

### 7. .dmg Distribution (Issue #18)

Makefile targets:
- `make dmg` — creates .dmg installer using `create-dmg` or `hdiutil`
  - Background image with install instructions
  - Applications folder shortcut
  - Icon positioning
  - Volume name: "Tenrec Terminal"
- `make sign` — code signs with Developer ID certificate
- `make notarize` — submits to Apple notarization via `notarytool`, staples ticket
- `make release` — orchestrates: clean, build, test, sign, notarize, dmg

### 8. Final Testing (Issue #17)

#### UI Tests (XCTest/XCUITest)
- `TerminalCRUDUITests.swift`: app launch, create terminal, rename, close, verify sidebar state
- `PromptWorkflowUITests.swift`: create prompt, edit content, send to terminal, create template, fill parameters, generate prompt
- `SettingsUITests.swift`: open preferences, navigate all tabs, change a setting, verify persistence

#### Integration Tests
- Hook event processing end-to-end (file write -> event parsed -> UI updated)
- File monitor change detection (modify file -> notification)
- Settings round-trip (change -> persist -> relaunch -> verify)

#### Coverage
- Unit test coverage >70% for `ViewModels/` and `Services/`
- All `@Observable` ViewModels have test coverage

#### Performance
- Multiple terminals (5+) don't degrade UI responsiveness
- Buffer monitoring doesn't cause frame drops

#### Error Handling Audit
- Verify no uncaught exceptions in standard workflows
- PTY creation failure handled gracefully
- License file parse failure shows user-friendly error
- Network-absent scenarios work (offline licensing, no Sparkle crash)

### 9. Documentation

- Update `README.md`: overview, screenshots placeholder, build instructions, architecture summary, contributing guide
- Update `CLAUDE.md`: reflect final architecture, all phases complete

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Views/AppMenu.swift` | SwiftUI `Commands` struct with all menu items and shortcuts |
| **Modify** | `Tenrec Terminal/Tenrec_TerminalApp.swift` | `.commands { AppMenu() }`, window restoration, Sparkle setup |
| **Modify** | All Views | Add `accessibilityLabel`, `accessibilityHint`, keyboard navigation |
| **Create** | `Tenrec Terminal/Views/Onboarding/SparkleOptInView.swift` | Auto-update opt-in UI |
| **Modify** | `Makefile` | Add `dmg`, `sign`, `notarize`, `release` targets |
| **Modify** | `Package.swift` or Xcode project | Add Sparkle SPM dependency |
| **Create** | `Tenrec TerminalUITests/TerminalCRUDUITests.swift` | App launch, terminal CRUD workflow |
| **Create** | `Tenrec TerminalUITests/PromptWorkflowUITests.swift` | Prompt/template creation and usage |
| **Create** | `Tenrec TerminalUITests/SettingsUITests.swift` | Settings navigation and persistence |
| **Update** | `README.md` | Build instructions, architecture, screenshots |
| **Update** | `CLAUDE.md` | Final architecture reflection |

## Acceptance Criteria

- [ ] All keyboard shortcuts in table above are functional and discoverable in menu bar
- [ ] Menu bar commands present, enabled/disabled correctly based on context
- [ ] Terminal captures keyboard when focused; releases on focus change
- [ ] Cmd+C copies terminal selection; Cmd+V pastes to stdin
- [ ] Window position, size, and sidebar state restored on relaunch
- [ ] VoiceOver can navigate all major UI elements with meaningful labels
- [ ] Reduced motion and high contrast preferences respected
- [ ] `make dmg` produces a valid .dmg installer image
- [ ] App is code-signed with Developer ID certificate
- [ ] Notarization succeeds (with valid certificate and Apple Developer account)
- [ ] Sparkle checks for updates when configured with appcast URL
- [ ] All UI tests pass
- [ ] Unit test coverage >70% on `ViewModels/` and `Services/`
- [ ] No uncaught exceptions in standard user workflows
- [ ] README enables a new developer to clone and build from scratch
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### UI Tests (`TerminalCRUDUITests.swift`)
- Launch app, verify main window appears
- Create new terminal via menu (Cmd+T), verify appears in sidebar
- Rename terminal, verify name updated
- Close terminal (Cmd+W), verify removed from sidebar
- Multiple terminals: create 3, switch between them, close middle one

### UI Tests (`PromptWorkflowUITests.swift`)
- Create prompt via menu (Cmd+N), verify editor appears
- Edit prompt title and content, verify saved
- Create template with parameters, fill form, generate prompt
- Send prompt to terminal (verify action is available)

### UI Tests (`SettingsUITests.swift`)
- Open preferences (Cmd+,)
- Navigate to each settings tab
- Change a setting, close preferences, reopen, verify persisted

### Performance Tests
- Create 5 terminals, type in each, verify no UI jank
- Open 3 split panes, verify responsive resizing

### Manual Verification Checklist
- [ ] .dmg opens correctly on clean macOS install
- [ ] Drag-to-Applications installs successfully
- [ ] App launches from Applications without Gatekeeper warning (after notarization)
- [ ] Sparkle update dialog appears when mock appcast has newer version

## Estimated Complexity

**High** (breadth of work across UI, testing, distribution) — This phase spans multiple domains: (1) SwiftUI `Commands` with correct focus and shortcut handling, (2) accessibility audit across all views, (3) Sparkle framework integration, (4) .dmg creation and Apple notarization toolchain, (5) comprehensive UI test suite, and (6) documentation. No single piece is deeply complex, but the breadth and polish requirements make this a high-effort phase. Plan for iterative testing across different macOS configurations.
