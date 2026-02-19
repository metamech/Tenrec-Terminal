# Phase 9: Feature Flags, Licensing & Logging

## Summary

Commercialization infrastructure — simple local feature flags, cryptographic offline licensing with 3-terminal limit for unlicensed users, and comprehensive logging/metrics for debugging and support.

## Prerequisites

- Phase 1 complete (terminal session management for license enforcement)
- All feature work ideally done (feature flags gate completed features)

## Deliverables

### 1. Feature Flags

`Tenrec Terminal/Services/FeatureFlagService.swift`:
- `FeatureFlag` enum: cases for each gatable feature (`.splitPanes`, `.claudeIntegration`, `.advancedPromptTools`, `.unlimitedTerminals`)
- `FeatureFlagService`: UserDefaults-backed, `isEnabled(_ flag: FeatureFlag) -> Bool`
- Default values: all flags enabled for licensed users, subset for unlicensed
- Hidden developer menu: Opt+click on version string in About window opens flag toggle UI
- Flags checked at feature entry points (guard at top of actions, not deep in code)

### 2. `License` Model

`Tenrec Terminal/Models/License.swift`:
- `licenseKey: String`
- `email: String`
- `purchaseDate: Date`
- `expiryDate: Date` (1 year from purchase)
- `signature: Data` (Ed25519 signature over key+email+dates)

### 3. `LicenseService`

`Tenrec Terminal/Services/LicenseService.swift`:
- **Validate license**: verify Ed25519 signature against embedded public key (CryptoKit)
- **License file format**: JSON with fields: `key`, `email`, `purchaseDate`, `expiryDate`, `signature` (base64-encoded)
- **Check expiry**: license covers app versions released before `expiryDate` (compare against embedded build date)
- **Enforce limits**: unlicensed = max 3 concurrent terminal sessions
- **No server communication** — fully offline validation
- **Public key**: Ed25519 public key embedded as constant in source
- **App build date**: embedded at compile time for license-vs-version comparison

### 4. `LicenseViewModel` (@Observable)

`Tenrec Terminal/ViewModels/LicenseViewModel.swift`:
- `licenseStatus: LicenseStatus` (enum: `.unlicensed`, `.valid`, `.expired`, `.invalid`)
- `currentLicense: License?`
- `canCreateTerminal: Bool` — checks session count against limit
- `importLicense(from url: URL)` — reads `.tenrec-license` file
- `importLicense(key: String)` — parses pasted license key
- `purchaseURL: URL` — link to purchase page

### 5. License Entry UI

`Tenrec Terminal/Views/Settings/LicenseSettingsView.swift`:
- Settings > License tab
- Current license status display: email, expiry date, validity
- Text field to paste license key
- Drag-and-drop zone for `.tenrec-license` file
- "Purchase License" button linking to website
- Clear error messages for invalid/expired licenses

### 6. Upgrade Prompt

`Tenrec Terminal/Views/Onboarding/UpgradePromptView.swift`:
- Shown when creating 4th terminal without a valid license
- Friendly messaging: "You've reached the free limit of 3 terminals"
- Options: enter license key, purchase, dismiss
- Non-blocking: user can dismiss and continue using existing 3 terminals

### 7. `LoggingService`

`Tenrec Terminal/Services/LoggingService.swift`:
- Uses `os.Logger` (Apple's unified logging system)
- Subsystem: `com.metamech.tenrec-terminal`
- Categories: `terminal`, `claude`, `hooks`, `licensing`, `ui`, `general`
- Convenience methods: `LoggingService.terminal.debug(...)`, `.info(...)`, `.warning(...)`, `.error(...)`
- File-based log export: writes recent logs to `~/Library/Application Support/Tenrec Terminal/logs/` for support bundles

### 8. `MetricsService`

`Tenrec Terminal/Services/MetricsService.swift`:
- Local-only metrics (no telemetry):
  - Terminal session count and duration
  - Tool usage frequency (which Claude tools are used most)
  - Feature flag states at time of metric
- Stored in `~/Library/Application Support/Tenrec Terminal/metrics/` as JSON files
- Exportable via Help menu

### 9. Debug Bundle

Menu > Help > "Create Debug Bundle":
- Gathers: logs, metrics, app version, macOS version, system info, Claude config paths (sanitized — no secrets)
- Packages into `.zip` file
- Save dialog for user to choose location

### 10. Licensing Architecture Documentation

`docs/licensing-architecture.md`:
- Ed25519 key pair generation process
- License file format specification
- Server-side license generator design (for separate implementation)
- Public key rotation plan

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Services/FeatureFlagService.swift` | `FeatureFlag` enum, UserDefaults backing, developer menu |
| **Create** | `Tenrec Terminal/Models/License.swift` | License data model |
| **Create** | `Tenrec Terminal/Services/LicenseService.swift` | Ed25519 validation, expiry check, limit enforcement |
| **Create** | `Tenrec Terminal/ViewModels/LicenseViewModel.swift` | License status, import, purchase link |
| **Create** | `Tenrec Terminal/Views/Settings/LicenseSettingsView.swift` | License tab UI |
| **Create** | `Tenrec Terminal/Views/Onboarding/UpgradePromptView.swift` | 3-terminal limit prompt |
| **Create** | `Tenrec Terminal/Services/LoggingService.swift` | os.Logger wrapper with categories, file export |
| **Create** | `Tenrec Terminal/Services/MetricsService.swift` | Local metrics collection and export |
| **Modify** | `Tenrec Terminal/ViewModels/TerminalManagerViewModel.swift` | License enforcement on terminal creation |
| **Modify** | `Tenrec Terminal/Views/Settings/PreferencesWindow.swift` | Add License tab, developer flags menu |
| **Modify** | `Tenrec Terminal/Tenrec_TerminalApp.swift` | Wire logging service, Help menu debug bundle |
| **Create** | `Tenrec TerminalTests/LicenseServiceTests.swift` | Validation, expiry, signature verification |
| **Create** | `Tenrec TerminalTests/FeatureFlagServiceTests.swift` | Toggle behavior, default values |
| **Create** | `docs/licensing-architecture.md` | Key management, file format spec, generator design |

## Acceptance Criteria

- [ ] Feature flags gate features at runtime; toggling a flag disables the corresponding feature
- [ ] Developer menu accessible via Opt+click on version in About window
- [ ] Valid `.tenrec-license` file accepted; license status shows valid with email and expiry
- [ ] Invalid license file rejected with clear error message
- [ ] Expired license: app works for versions released during license period, shows expired for newer
- [ ] Unlicensed users limited to 3 concurrent terminals; 4th attempt shows upgrade prompt
- [ ] License validates entirely offline (no network calls)
- [ ] Logs written to unified log system with correct subsystem/category
- [ ] Log export creates readable files in Application Support
- [ ] Debug bundle creates `.zip` with logs, metrics, system info
- [ ] Metrics collected locally and exportable as JSON
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests (`LicenseServiceTests.swift`)
- Valid license with correct Ed25519 signature: accepted
- License with tampered email: signature fails
- License with tampered dates: signature fails
- Expired license with app build date after expiry: rejected
- Expired license with app build date before expiry: accepted
- Malformed license JSON: returns clear error
- Empty/nil license key: handled gracefully
- 3-terminal limit enforced when unlicensed
- 4th terminal blocked when unlicensed
- Licensed user: no terminal limit

### Unit Tests (`FeatureFlagServiceTests.swift`)
- Default flag values correct for unlicensed state
- Toggle flag on: `isEnabled` returns true
- Toggle flag off: `isEnabled` returns false
- Flag state persists across service reinstantiation (UserDefaults)
- Unknown flag name handled gracefully

### Integration Considerations
- Generate test Ed25519 key pair for unit tests (NOT the production key)
- Test license file import from both paste and file drop
- Mock `TerminalManagerViewModel` session count for limit enforcement tests
- Verify logging output appears in unified log (manual verification or `os_log` assertions)

## Estimated Complexity

**High** — Three distinct subsystems (flags, licensing, logging) each with their own concerns. The main challenges are: (1) Ed25519 cryptographic signature verification with CryptoKit — must handle key encoding/decoding correctly, (2) license-vs-build-date comparison requires embedding build date at compile time, (3) debug bundle must sanitize sensitive paths while remaining useful for debugging, and (4) integrating license enforcement into existing terminal creation flow without breaking the UX.
