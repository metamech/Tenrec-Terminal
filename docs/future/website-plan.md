# Website & License Infrastructure Plan

## Scope

Separate repository for the Tenrec Terminal marketing website, license generation, and update distribution. Implementation details here; actual implementation in its own repo.

## Website

### Pages
- **Landing**: hero, feature highlights, screenshots, pricing, download CTA
- **Pricing**: single tier ($79-99), feature comparison (free vs licensed)
- **Download**: .dmg download link, system requirements, changelog
- **Documentation**: getting started, Claude Code setup, FAQ
- **Blog**: release notes, tips, development updates

### Tech Stack (Suggested)
- Static site generator (Astro, Next.js, or Hugo)
- Hosted on Vercel/Netlify or S3+CloudFront
- Stripe for payments
- Edge function for license generation

## License Generator

### Flow
1. User clicks "Buy" → Stripe Checkout
2. Payment succeeds → Stripe webhook fires
3. Webhook handler generates license:
   - Create JSON payload (email, dates, features)
   - Sign with Ed25519 private key
   - Encode as `.tenrec-license` file
4. Display license on success page (copy button + download)
5. Email license to customer (via SendGrid/SES)

### Implementation
- Serverless function (Vercel Edge, AWS Lambda, or Cloudflare Worker)
- Ed25519 private key in environment variable (encrypted at rest)
- License stored in database for re-delivery (customer support)
- Admin dashboard: lookup by email, regenerate, revoke

## Appcast Hosting

### Sparkle Updates
- `appcast.xml` hosted at stable URL (e.g., updates.tenrec.app/appcast.xml)
- Each release: signed .dmg URL, version, build date, release notes (HTML)
- Delta updates if feasible
- Signed with Sparkle EdDSA key

### Release Process
1. `make release` builds signed .dmg
2. `make notarize` submits to Apple
3. Upload .dmg to CDN
4. Update appcast.xml with new entry
5. Commit and deploy website

## Domain
- `tenrec.app` or `tenrecterminal.com` (TBD)
- SSL via Let's Encrypt or CDN-provided
