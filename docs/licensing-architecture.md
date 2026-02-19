# Licensing Architecture

## Business Model

- One-time purchase: $79-99
- Includes 1 year of updates from purchase date
- Perpetual use: any version released during license year works forever
- No server verification — fully offline
- Unlicensed: limited to 3 concurrent terminal sessions

## License File Format

JSON file with `.tenrec-license` extension:

```json
{
  "version": 1,
  "email": "user@example.com",
  "purchaseDate": "2026-02-19T00:00:00Z",
  "expiryDate": "2027-02-19T00:00:00Z",
  "features": ["full"],
  "signature": "base64-encoded-ed25519-signature"
}
```

## Cryptographic Validation

- **Algorithm**: Ed25519 (fast, small keys, no padding issues)
- **Signing key**: held by license server (private, never in app)
- **Verification key**: embedded in app binary (public key)
- **Signed payload**: canonical JSON of all fields except `signature`
- **Canonical form**: keys sorted alphabetically, no whitespace, UTF-8

### Validation Steps
1. Parse license JSON
2. Extract signature, reconstruct canonical payload
3. Verify Ed25519 signature against embedded public key
4. Check expiryDate >= app's embedded build date
5. Cache validation result for session (re-validate on app launch)

## Version Gating

Each app build embeds its build date. License check:
- `license.expiryDate >= app.buildDate` → full features
- `license.expiryDate < app.buildDate` → license expired for this version, show renewal prompt but allow previously-licensed features

## Enforcement

- Check on terminal creation: if `terminalCount >= 3 && !hasValidLicense` → show upgrade prompt
- Soft enforcement: no DRM, no obfuscation, trust-based
- Feature flags can gate additional premium features independently

## License Entry

1. Preferences > License > "Enter License"
2. Paste license key (JSON string) or drag-drop .tenrec-license file
3. Validate immediately, show result
4. Store in: `~/Library/Application Support/Tenrec Terminal/license.json`
5. Also support: `~/.config/tenrec/license.json` (XDG fallback)

## Website License Generator (Separate Repo)

- Stripe webhook receives payment confirmation
- Server generates license JSON with Ed25519 signature
- License displayed on success page + emailed to customer
- Appcast XML for Sparkle updates hosted alongside

See [PLAN_FUTURE.md](../PLAN_FUTURE.md) for website implementation details.

## Key Management

- Generate Ed25519 keypair during project setup
- Private key: stored in secure server environment (never in repo)
- Public key: embedded in Swift source as static constant
- Key rotation: new key = new app version, old licenses still valid with old key (app bundles both)
