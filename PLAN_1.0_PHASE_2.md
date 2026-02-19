# Phase 2: Terminal Profiles, Themes & Search

## Summary

Terminal customization via reusable profiles (color schemes, fonts, cursor styles) and in-terminal search (`Cmd+F`). Makes Tenrec feel like a proper terminal app rather than a bare-bones emulator.

## Prerequisites

- Phase 1 complete (multi-session lifecycle working)
- `TerminalManagerViewModel` managing sessions
- `TerminalViewWrapper` supporting cached multi-instance terminal views

## Deliverables

### 1. `TerminalProfile` SwiftData model

New `@Model` class with fields:
- `id: UUID`
- `name: String`
- `fontFamily: String` (default: "Menlo")
- `fontSize: Double` (default: 13.0)
- `foregroundColor: String` (hex, e.g. "#C7C7C7")
- `backgroundColor: String` (hex, e.g. "#1E1E1E")
- `cursorColor: String` (hex)
- `cursorStyle: String` — "block", "underline", or "bar"
- `selectionColor: String` (hex with alpha)
- `ansiColors: [String]` — array of 16 hex strings (standard 8 + bright 8)
- `opacity: Double` (0.0-1.0, default 1.0)
- `isBuiltIn: Bool` — protects default profiles from deletion

### 2. Default profiles

Ship 4 built-in profiles, seeded on first launch:
- **Tenrec Default** — dark theme, Menlo 13pt
- **Solarized Dark** — standard Solarized Dark palette
- **Solarized Light** — standard Solarized Light palette
- **Monokai** — Monokai color scheme

Store defaults as JSON in `Resources/DefaultProfiles/`. Load and insert into SwiftData on first launch (check for existing built-in profiles before inserting).

### 3. Profile assignment to sessions

- Add `profileId: UUID?` to `TerminalSession` model
- `nil` falls back to the default profile (first built-in, or user-designated default)
- Profile changes apply immediately to the terminal view

### 4. `TerminalProfileViewModel` (@Observable)

- `profiles` — all profiles from SwiftData
- `createProfile(name:)` — new profile with default values
- `duplicateProfile(id:)` — copy with "Copy of ..." name
- `deleteProfile(id:)` — only if not built-in
- `updateProfile(id:, ...)` — update any field
- `exportProfile(id:) -> Data` — JSON export
- `importProfile(data:)` — JSON import, validates schema

### 5. Preferences window with Profiles tab

- macOS Settings/Preferences window (use `.settings` scene or `Window` scene with `SettingsLink`)
- Profiles tab: master-detail layout
  - Left: list of profiles with add/remove buttons
  - Right: editor form with color pickers, font picker, cursor style segmented control, opacity slider
- Live preview swatch showing a sample terminal appearance

### 6. Apply profile to terminal view

In `TerminalViewWrapper`, after creating `LocalProcessTerminalView`:
- Set font: `terminalView.font = NSFont(name:size:)`
- Set colors: use SwiftTerm's `installColors()` or direct attribute setting
- Set cursor style: `terminalView.cursorStyleChanged(source:newStyle:)`
- Set background opacity

Profile changes mid-session: update the existing `LocalProcessTerminalView` without restarting the process.

### 7. Terminal search bar (`Cmd+F`)

- Overlay bar at top of terminal content area
- Text field + "Previous" / "Next" buttons + match count label + "Done" (Esc)
- Use SwiftTerm's `search(for:from:caseSensitive:regex:)` API
- Highlight matches in terminal view
- `Cmd+G` for next match, `Shift+Cmd+G` for previous
- `Esc` dismisses search bar and returns focus to terminal

### 8. Sidebar color tag

- Each session can have a color tag (small colored dot next to name)
- User picks from a fixed palette (red, orange, yellow, green, blue, purple, none)
- Set via right-click context menu on sidebar session item
- Stored in `TerminalSession.colorTag` (added in Phase 1)

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Models/TerminalProfile.swift` | New SwiftData model |
| **Modify** | `Tenrec Terminal/Models/TerminalSession.swift` | Add `profileId: UUID?` field |
| **Create** | `Tenrec Terminal/ViewModels/TerminalProfileViewModel.swift` | Profile CRUD, import/export |
| **Create** | `Tenrec Terminal/Views/Terminal/TerminalSearchBar.swift` | Search overlay view |
| **Create** | `Tenrec Terminal/Views/Settings/ProfileEditorView.swift` | Profile editing form |
| **Create** | `Tenrec Terminal/Views/Settings/ProfileListView.swift` | Profile list sidebar in preferences |
| **Create** | `Tenrec Terminal/Views/Settings/PreferencesWindow.swift` | Settings scene wrapper |
| **Modify** | `Tenrec Terminal/Views/Terminal/TerminalViewWrapper.swift` | Apply profile colors/font, wire search API |
| **Modify** | `Tenrec Terminal/Views/ContentPaneView.swift` | Add search bar overlay, `Cmd+F` handler |
| **Modify** | `Tenrec Terminal/Views/SidebarView.swift` | Color tag display, color picker in context menu |
| **Create** | `Tenrec Terminal/Resources/DefaultProfiles/tenrec-default.json` | Default profile JSON |
| **Create** | `Tenrec Terminal/Resources/DefaultProfiles/solarized-dark.json` | Solarized Dark JSON |
| **Create** | `Tenrec Terminal/Resources/DefaultProfiles/solarized-light.json` | Solarized Light JSON |
| **Create** | `Tenrec Terminal/Resources/DefaultProfiles/monokai.json` | Monokai JSON |
| **Modify** | `Tenrec Terminal/Tenrec_TerminalApp.swift` | Add `TerminalProfile` to schema; add Settings scene |
| **Create** | `Tenrec TerminalTests/TerminalProfileTests.swift` | Profile model and ViewModel tests |

## Acceptance Criteria

- [ ] At least 4 built-in color schemes selectable from Preferences
- [ ] Font family and size configurable; changes apply immediately to the terminal view
- [ ] `Cmd+F` opens search overlay; finds and highlights text in scrollback
- [ ] Search shows match count; Prev/Next navigate between matches
- [ ] `Esc` dismisses search and returns focus to terminal
- [ ] Profiles persist across relaunch
- [ ] Each terminal session can use a different profile independently
- [ ] Built-in profiles cannot be deleted (only duplicated/customized)
- [ ] Profile import/export produces valid JSON
- [ ] Color tags appear in sidebar next to session names
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests (`TerminalProfileTests.swift`)
- Profile CRUD: create, read, update, delete
- Built-in profile protection (delete attempt fails gracefully)
- Default profile seeding on first launch (in-memory container starts empty, seed runs, verify 4 profiles)
- `duplicateProfile` produces correct name and copied values
- JSON export/import round-trip preserves all fields
- Invalid JSON import fails gracefully with error

### Integration Considerations
- Profile application to `LocalProcessTerminalView`: verify font and color changes take effect (may need UI test or manual verification)
- Search API integration: verify SwiftTerm `search()` is called with correct parameters
- In-memory SwiftData container for all persistence tests

## Estimated Complexity

**Medium** — Profile model and CRUD are straightforward. The main challenges are: (1) correctly applying colors to SwiftTerm's `TerminalView` (requires understanding SwiftTerm's color/attribute API), (2) getting the search overlay to coexist with the terminal view without stealing keyboard focus, and (3) building a clean Preferences UI with live preview.
