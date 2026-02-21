# Phase 2: Terminal Profiles, Themes & Search — Progress

**Status**: Complete

## Plan
See [PLAN_1.0_PHASE_2.md](PLAN_1.0_PHASE_2.md)

## Tasks Completed

### 1. TerminalProfile SwiftData Model
- Created `Tenrec Terminal/Models/TerminalProfile.swift`
- Fields: id, name, fontFamily, fontSize, foregroundColor, backgroundColor, cursorColor, cursorStyle, selectionColor, ansiColors (16 hex strings), opacity, isBuiltIn
- Static `defaultAnsiColors` constant (16 xterm-style entries)

### 2. TerminalSession.profileId
- Added `profileId: UUID?` to `Tenrec Terminal/Models/TerminalSession.swift`
- Defaults to `nil` (falls back to first built-in profile)

### 3. Default Profile JSON Resources
- `Tenrec Terminal/Resources/DefaultProfiles/tenrec-default.json`
- `Tenrec Terminal/Resources/DefaultProfiles/solarized-dark.json`
- `Tenrec Terminal/Resources/DefaultProfiles/solarized-light.json`
- `Tenrec Terminal/Resources/DefaultProfiles/monokai.json`

### 4. TerminalProfileViewModel
- Created `Tenrec Terminal/ViewModels/TerminalProfileViewModel.swift`
- `seedDefaultProfilesIfNeeded()` — idempotent; loads from JSON or falls back to hard-coded
- `createProfile(name:)`, `duplicateProfile(id:)`, `deleteProfile(id:)` (protected for isBuiltIn)
- `updateProfile(id:...)` — partial updates via optional parameters
- `exportProfile(id:) -> Data?` — JSON via ProfileDTO Codable struct
- `importProfile(data:)` — validates JSON; throws `ProfileImportError` on missing fields
- `profile(for:)` — resolves session's profile with fallback to first built-in

### 5. Unit Tests (TerminalProfileTests.swift)
- 20 tests covering: model defaults, SwiftData insertion, seeding (count/idempotency/names/isBuiltIn),
  CRUD operations, import/export round-trip, invalid JSON rejection, session profileId

### 6. Profile Application to Terminal Views
- Updated `TerminalContainerView.Coordinator.applyProfile(_:to:)`:
  - Font: `NSFont(name:size:)`
  - Foreground/background: `nativeForegroundColor`/`nativeBackgroundColor`
  - ANSI palette: `installColors(_:)` with 16 SwiftTerm.Color values
  - Cursor style: `terminal.setCursorStyle(_:)` mapping "block"/"underline"/"bar"
  - Opacity: `layer.opacity`
- Profile applied at terminal creation and on subsequent `updateNSView` calls

### 7. Preferences Window
- `Tenrec Terminal/Views/Settings/PreferencesWindow.swift` — Settings scene with General + Profiles tabs
- `Tenrec Terminal/Views/Settings/ProfileListView.swift` — master-detail profile list, toolbar for add/duplicate/delete/import/export
- `Tenrec Terminal/Views/Settings/ProfileEditorView.swift` — form with font, color pickers, cursor segmented control, opacity slider, ANSI grid, live preview swatch
- Settings scene added to `Tenrec_TerminalApp.swift` (Cmd+,)
- Profile seeding on app launch via `seedDefaultProfilesIfNeeded()`

### 8. Terminal Search Bar (Cmd+F)
- Created `Tenrec Terminal/Views/Terminal/TerminalSearchBar.swift`
- TextField + Previous/Next buttons + match count label + dismiss button
- `Cmd+G` / `Shift+Cmd+G` keyboard shortcuts for next/previous
- Integrated into `ContentPaneView` via ZStack overlay on `.terminal` selection
- `NSEvent.addLocalMonitorForEvents` for `Cmd+F` to show, `Esc` to dismiss
- `TerminalManagerViewModel.searchNext/searchPrevious/clearSearch` delegate to SwiftTerm `findNext`/`findPrevious`/`clearSearch` APIs
- `activeTerminalView` reference wired through `TerminalContainerView.Coordinator`

### 9. Sidebar Color Tags
- Updated `SidebarView.swift` with `ColorTag` enum (none/red/orange/yellow/green/blue/purple)
- Right-click context menu "Color Tag" submenu with colored icons
- Colored dot shown next to session name when tag is set
- `terminalManager.setColorTag(id:tag:)` persists to `TerminalSession.colorTag`

### 10. Schema and App Updates
- `Tenrec_TerminalApp.swift`: added `TerminalProfile.self` to SwiftData schema
- `TerminalManagerViewModel.swift`: added `resolveProfile(for:)`, search methods, `activeTerminalView` weak ref
- All previews updated to include `TerminalProfile.self` in their model containers

## Test Results
- 40 unit tests passing (Swift Testing) — confirmed in first test run
- Build: `** BUILD SUCCEEDED **`
- App Sandbox: unchanged (disabled)

## Blockers
None.

## Notes
- SwiftTerm's `red8:green8:blue8:` Color init is internal; use `red:green:blue:` (UInt16, 0-65535) with `* 257` scaling from 8-bit
- `applyProfile` is called on every `updateNSView` — this is safe since SwiftTerm re-renders on property set
- The `testmanagerd` daemon occasionally hangs during CI; restart with `launchctl kickstart -k gui/$(id -u)/com.apple.testmanagerd`
