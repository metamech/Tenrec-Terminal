# Remote Tenrec Terminals

## Use Case

Indie developer with MacBook + Mac Minis. Run Claude Code on all machines, monitor and interact from the MacBook only. Remote machines run Tenrec Terminal in "server" mode.

## Architecture

### Discovery — Bonjour/mDNS
- Tenrec Terminal registers `_tenrec._tcp` service on local network (opt-in)
- Service TXT record: machine name, Tenrec version, terminal count
- Primary machine discovers remote instances automatically
- Manual connection via IP:port also supported

### Authentication
- First connection: display pairing code on both machines (like Bluetooth)
- After pairing: mutual TLS with pinned certificates
- Certificates stored in Keychain
- Revoke pairing from either machine

### Protocol — TenrecSync
WebSocket-based bidirectional protocol over TLS:

| Message Type | Direction | Content |
|-------------|-----------|---------|
| `terminal.list` | server → client | Available terminal sessions |
| `terminal.buffer` | server → client | Terminal buffer updates (incremental) |
| `terminal.input` | client → server | Keystrokes, paste, input queue responses |
| `hook.event` | server → client | Claude Code hook events |
| `state.sync` | bidirectional | Claude session state, pending inputs |
| `heartbeat` | bidirectional | Connection health |

### Terminal Buffer Sync
- Full buffer sent on initial connection
- Incremental updates (new lines, cursor position) streamed
- Compression: zstd for buffer data
- Latency target: <100ms for keystroke echo on LAN

### Input Queue Federation
- Remote pending inputs appear in local input queue
- Responses sent back to remote machine, written to terminal stdin
- Clear indication of which machine each item is from

## Security Considerations

- All traffic encrypted (TLS 1.3)
- No cloud relay — direct LAN/VPN connection only
- Certificate pinning prevents MITM on local network
- Firewall guidance in documentation
- Option to require re-authentication after inactivity

## UX

- Sidebar groups: "Local" and "Remote (MacMini-1)" etc.
- Remote terminals have subtle network indicator icon
- Connection status shown per remote machine
- Latency indicator (green/yellow/red)
- Graceful disconnect: remote terminals show "disconnected" state
