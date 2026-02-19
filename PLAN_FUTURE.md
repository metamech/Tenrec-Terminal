# Tenrec Terminal — Post-1.0 Plans

Features deferred from 1.0 MVP, organized by theme. Each major feature links to a detailed sub-document.

## Local AI / MLX Integration (GitHub Issues #8, #9)

On-device LLM inference via Apple MLX for prompt analysis, effectiveness rating, and rewrite suggestions. No cloud dependency.

- **MLX Framework Setup**: mlx-swift SPM dependency, model download manager (qwen3-coder from HF), storage in ~/Library/Application Support, progress UI
- **AI Prompt Tools**: rate effectiveness, suggest rewrites, simplify/expand, template parameter suggestions
- **Streaming UI**: generation progress, cancellation, accept/reject results

Details: [docs/future/mlx-integration.md](docs/future/mlx-integration.md)

## Remote Tenrec Terminals (GitHub Issue #22)

Connect multiple Macs running Tenrec Terminal. Control Claude Code sessions on remote machines from a primary machine.

- **Discovery**: Bonjour/mDNS announcement (opt-in)
- **Authentication**: TLS mutual auth with certificate pinning, or SSH key-based
- **Protocol**: terminal buffer sync, hook event relay, input queue federation
- **UX**: remote terminals appear in sidebar with machine indicator, latency display

Details: [docs/future/remote-terminals.md](docs/future/remote-terminals.md)

## Usage Tracking Panel (GitHub Issue #15)

Collapsible sidebar panel showing Claude Code usage metrics parsed from stats-cache.json.

- Session/daily/monthly token totals, rate limit status, progress bars
- "Details" sheet with full breakdown
- Show/hide preference persisted

## iOS Support

iPad companion app connecting to remote Tenrec instances (no local PTY on iOS).

- SwiftUI shared views where possible
- Remote-only terminal sessions via Tenrec remote protocol
- Adapted keyboard handling for touch + hardware keyboards
- Catalyst vs native iPad app decision needed

## Additional Post-1.0 Features

| Feature | Description | Priority |
|---------|-------------|----------|
| **Tab groups** | Group related terminals (e.g., by project) | Medium |
| **Session recording/replay** | Record terminal sessions as asciicast, replay | Low |
| **Snippet sync** | iCloud sync for prompts/templates across machines | Medium |
| **Plugin system** | Swift-based plugins for custom monitors, actions | Low |
| **Custom shell integrations** | Fish, Nushell, PowerShell integration markers | Medium |
| **Terminal multiplexer awareness** | Detect and surface tmux/screen sessions | Low |
| **Git integration** | Show branch/status in terminal title bar | Medium |
| **Advanced search** | Regex search, search across all terminal sessions | Medium |
| **Touch Bar support** | Quick actions on MacBook Pro Touch Bar (if still relevant) | Low |
| **Siri Shortcuts** | "Open Claude Code in project X" via Shortcuts.app | Low |

## Website & License Infrastructure (Separate Repo)

- Landing page with features, screenshots, pricing
- Stripe checkout integration
- License key generator (Ed25519 signing)
- Appcast XML hosting for Sparkle updates
- Download page with .dmg hosting

Details: [docs/future/website-plan.md](docs/future/website-plan.md)
