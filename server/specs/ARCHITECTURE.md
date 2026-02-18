# self-sovereign-ollama ai-server Architecture (v2.0.0)

This project is intentionally separated into two independent layers:

1. **Network Perimeter Layer** (VPN + Firewall + Router)
2. **AI Server Layer** (Ollama-based inference service)

Each layer can function independently.
The **intended deployment model combines both** for defense-in-depth.

---

## Core Principles

- Single ingress point: perimeter router
- No Wi-Fi infrastructure
- No public exposure of inference port (11434)
- WireGuard VPN for all remote access
- Firewall-based isolation for AI server
- No access to other LAN devices from VPN clients or AI server
- Zero third-party cloud dependencies
- Run Ollama exclusively on a dedicated, always-on machine (separate from clients)

---

## Intended Deployment Context

- Apple Silicon Mac (M-series) with high unified memory capacity (≥64 GB strongly recommended)
- 24/7 operation with uninterruptible power supply
- High upload bandwidth network connection (≥100 Mb/s recommended for low-latency streaming worldwide)
- The server machine is **not** the development or usage workstation — clients connect remotely
- **Wired network only** - No Wi-Fi infrastructure

---

## LAYER 1 — NETWORK PERIMETER (Router, VPN, Firewall)

### Physical Topology

```
Internet
   ↓
ISP Router (192.168.2.0/24)
   ↓
OpenWrt Router (behind ISP router)
   ↓
LAN (192.168.250.0/24)
   ↓
self-sovereign-ollama server (192.168.250.20, firewall-isolated)
```

Note:
- OpenWrt router may be behind an existing ISP router (double-NAT)
- Port forwarding at ISP level required for external VPN access

### Network Interfaces

**Router interfaces:**
- `wan` - Connection to ISP router (192.168.2.90)
- `lan` - Local network (192.168.250.0/24) including isolated AI server
- `wg0` - WireGuard VPN

**Example subnets:**
- Upstream (ISP): `192.168.2.0/24`
- LAN: `192.168.250.0/24` (all devices including isolated server)
- VPN: `10.10.10.0/24`

**AI server static IP (example):**
- `192.168.250.20` (configurable during install, isolated via firewall)

### Firewall Policy (Authoritative)

```
WAN → any: deny (except WireGuard UDP port)
WAN → LAN: deny

VPN → LAN (AI server):
  allow TCP 11434 to AI server (192.168.250.20)
  optionally allow SSH (22) if explicitly configured

VPN → LAN (other devices): deny
VPN → WAN: deny

AI server → LAN (other devices): deny
AI server → WAN: allow (outbound internet for model downloads, OS updates)

LAN (admin) → AI server: optional (admin access if needed)
```

**Critical**: Only the WireGuard UDP port is exposed publicly. Port 11434 is **never** port-forwarded.

See `NETWORK_DOCUMENTATION.md` for complete router configuration instructions.

---

## LAYER 2 — AI SERVER (Inference Service)

### Core Principles

- Provide OpenAI-compatible and Anthropic-compatible HTTP APIs
- Bind to AI server interface only (recommended) or all interfaces
- No built-in authentication layer (security via network perimeter)
- No public exposure assumed
- No knowledge of VPN or firewall topology
- Stateless inference service
- Native macOS service management via launchd

### Network Topology

```
┌─────────────────────────────────────────────────────────┐
│                  Authorized Clients                      │
│             (WireGuard VPN-connected devices)            │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              WireGuard VPN Tunnel                        │
│                   (10.10.10.0/24)                        │
│         Encrypted tunnel + per-peer keys                 │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              OpenWrt Router (Perimeter)                  │
│      Firewall: VPN → AI server (port 11434 only)        │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                LAN Network (192.168.250.0/24)            │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  self-sovereign-ollama server (192.168.250.20)       │ │
│  │  • Bind: 192.168.250.20:11434 (dedicated LAN IP)   │ │
│  │  • Serves: OpenAI + Anthropic APIs                 │ │
│  │  • Outbound: Internet allowed (model pulls, updates)│ │
│  │  • Inbound: Only from VPN (firewall controlled)    │ │
│  │  • Isolated: Cannot reach other LAN devices        │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Security Layers (Defense in Depth)

1. **Router Firewall (Network Layer)** - Controls **who** can reach the server
   - Only WireGuard UDP port exposed publicly
   - VPN clients can only reach AI server port 11434
   - No VPN → LAN (other devices) access
   - No AI server → LAN (other devices) access

2. **WireGuard VPN (Cryptographic Layer)** - Controls **which devices** can access
   - Per-peer public key authentication
   - No shared secrets
   - Peer revocation by removing public key from router

3. **Firewall Isolation Layer** - Controls **what** the server can access
   - Server cannot reach other LAN resources
   - Server can reach internet (for models, updates)
   - Outbound traffic is logged (optional)

See `SECURITY.md` for complete security model documentation.

---

## Server Responsibilities (Layer 2)

### Ollama Configuration

- Bind Ollama to **dedicated LAN IP** (`192.168.250.20:11434`) - recommended
  - Alternative: Bind to all interfaces (`0.0.0.0:11434`) - simpler but less explicit
- Configured via `OLLAMA_HOST` environment variable in LaunchAgent plist
- Let Ollama handle model loading, inference, and unloading automatically
- Leverage Ollama's native support for streaming responses, JSON mode, tool calling

### Dual API Surface (Direct)

Ollama exposes both OpenAI-compatible and Anthropic-compatible APIs **directly** (no proxy):

**OpenAI-compatible API:**
- `POST /v1/chat/completions`
- `GET /v1/models`
- `GET /v1/models/{model}`
- `POST /v1/responses` (experimental, Ollama 0.5.0+)

**Anthropic-compatible API:**
- `POST /v1/messages`

**Ollama Native API:**
- `GET /api/version`
- `GET /api/tags`
- `POST /api/show`
- `POST /api/generate`
- `POST /api/pull`
- Other native endpoints

**Note**: All Ollama endpoints are accessible to VPN clients. No endpoint filtering at application layer (firewall controls access).

---

## Component Management

### Service Architecture

Ollama runs as user-level LaunchAgent (not root):

**Ollama LaunchAgent** (`~/Library/LaunchAgents/com.ollama.plist`)
- Binds `192.168.250.20:11434` (dedicated LAN IP) or `0.0.0.0:11434` (all interfaces)
- Sets `OLLAMA_HOST=192.168.250.20` (or `0.0.0.0`)
- Auto-start on login (`RunAtLoad=true`)
- Auto-restart on crash (`KeepAlive=true`)
- Logs to `/tmp/ollama.stdout.log`, `/tmp/ollama.stderr.log`

### Service Management Commands

**Ollama:**
```bash
# Status
launchctl list | grep com.ollama

# Start/Stop/Restart
launchctl kickstart gui/$(id -u)/com.ollama
launchctl stop gui/$(id -u)/com.ollama
launchctl kickstart -k gui/$(id -u)/com.ollama

# View logs
tail -f /tmp/ollama.stdout.log
tail -f /tmp/ollama.stderr.log
```

---

## Network & Access Model

### WireGuard VPN Configuration (Layer 1)

- All remote access goes through WireGuard VPN hosted on OpenWrt router
- No port forwarding of inference port (11434) - only WireGuard UDP port exposed
- Per-peer public key authentication (no shared secrets)
- VPN clients reach server via static LAN IP: `192.168.250.20:11434`
- No dynamic DNS or hostname resolution needed (direct IP access)

### Firewall-Based Isolation Configuration

- Server assigned static IP on LAN: `192.168.250.20` (configurable)
- LAN subnet: `192.168.250.0/24` (configurable)
- Server isolated from other LAN devices via firewall rules
- Server allows outbound internet (for model downloads, OS updates)
  - **Trade-off**: Allows automatic updates but increases attack surface
  - **Alternative**: Air-gapped with manual model loading (see SECURITY.md)

### Network Binding

- Ollama bound to dedicated LAN IP (`192.168.250.20`) - recommended for explicit control
- Alternative: Bind to all interfaces (`0.0.0.0`) - simpler but less explicit
- Firewall enforces access control (only VPN clients can reach port 11434)
- No application-layer authentication (security via network perimeter)

---

## Design Rationale

### Why Two-Layer Architecture?

**Layer separation allows:**
- Independent implementation and testing of each layer
- Router/VPN can be set up once and serve multiple services (not just AI server)
- AI server can be deployed on different network topologies (LAN-only, different VPN solutions)
- Clear security boundaries with different threat models

**Why not Tailscale + HAProxy (v1 approach)?**
- Third-party dependency (Tailscale service)
- HAProxy added complexity for endpoint filtering
- Less control over network perimeter
- More attack surface (Tailscale + HAProxy + Ollama)

**Current approach (v2):**
```
Client → WireGuard (router) → Firewall → Ollama (isolated LAN)
```
- Self-sovereign infrastructure (no third-party VPN service)
- Router controls all ingress (single point of administration)
- Firewall enforces access control (no application-layer proxy needed)
- Simpler architecture (fewer moving parts)
- Full control over network topology
- No separate physical or VLAN DMZ required

### Why OpenWrt + WireGuard?

**OpenWrt:**
- **Open source** - Auditable, no vendor backdoors
- **Mature** - 20+ years of development
- **Flexible** - Runs on wide range of hardware
- **Community** - Large user base, extensive documentation

**WireGuard:**
- **Modern** - Designed for security and simplicity
- **Fast** - Minimal overhead
- **Auditable** - Small codebase (~4,000 lines)
- **Standard** - Built into Linux kernel
- **No shared secrets** - Per-peer public key authentication

### Why Firewall-Based Isolation?

- **Isolation** - Server cannot access other LAN resources
- **Principle of least privilege** - Server only has internet access, nothing more
- **Blast radius containment** - If server compromised, attacker cannot pivot to other LAN devices
- **Clear security boundary** - Easy to audit and monitor via firewall rules
- **Simplicity** - No separate physical interface or VLAN configuration needed
- **Flexibility** - Easy to add/remove isolation rules as needed

---

## Performance Characteristics

### Network Latency Impact

WireGuard adds minimal overhead:
- ~0.1-0.5ms encryption/decryption per packet
- Negligible compared to inference time

For typical inference workload:
- Model loading: 1-10 seconds (Ollama)
- Token generation: 50-200ms per token (Ollama)
- WireGuard overhead: <1ms
- Router forwarding: <1ms

Network latency is **negligible** compared to inference time.

### Throughput Impact

Router forwarding can handle:
- 10,000+ packets/second on modest hardware
- Concurrent connections limited only by Ollama (typically 5-10)

For this use case (single-user or small team):
- Ollama is bottleneck (model loading, GPU memory)
- Router/VPN is never the limiting factor

### Bandwidth Considerations

- Upload bandwidth critical for streaming responses
- Recommendation: ≥100 Mb/s upload for low-latency worldwide
- WireGuard encryption adds ~5-10% overhead

---

## Deployment Variants

### Single Server (Standard - v2)

```
Client 1 ─┐
Client 2 ─┼→ WireGuard VPN → Router Firewall → Ollama (192.168.250.20)
Client 3 ─┘
```

All clients share single Ollama instance. This is the standard deployment.

### Future: Multiple Isolated Services (Optional)

```
                                 ┌→ Ollama (192.168.250.20)
Client ─→ WireGuard ─→ Router ──┼→ Other Service (192.168.250.21)
                                 └→ Another Service (192.168.250.22)
```

Multiple services can be isolated on the same LAN, each with dedicated firewall rules.

**Out of scope for v2**, but architecture supports it.

### Alternative: LAN-Only Deployment

For environments without VPN requirements:

```
Client (LAN) ─→ Ollama (192.168.250.20)
```

Server can run on LAN without router/VPN layer. Use Layer 2 (AI server) specs only.

---

## Out of Scope

### v2 Baseline

The following are **intentionally excluded** from baseline architecture:

- Built-in authentication / API keys (network perimeter provides security)
- Application-layer TLS termination (WireGuard already provides encryption)
- Request content inspection / mutation
- Application-layer rate limiting / quotas (could add via reverse proxy if needed)
- Application-layer access logging (router logs connections)
- Web-based UI for server management
- Model quantization / conversion
- Multi-server load balancing
- Wi-Fi infrastructure
- Intrusion detection system (IDS) on router (could add via OpenWrt packages)

These can be added later without changing the base two-layer architecture.

---

## Failure Modes & Recovery

### Router Crash

- Ollama remains running but unreachable from internet
- VPN clients lose connectivity
- No exposed attack surface (port 11434 not forwarded)
- Manual router reboot required
- Typical recovery time: 1-2 minutes (router boot + VPN re-establishment)

### Ollama Crash

- Router remains running
- VPN clients can connect but get connection refused on port 11434
- LaunchAgent auto-restarts Ollama (KeepAlive=true)
- Typical recovery time: 5-10 seconds (service restart + model reloading)

### WireGuard Tunnel Failure

- Router remains running
- Clients cannot establish VPN connection
- No exposed attack surface (only WireGuard UDP port public)
- Check router WireGuard configuration and firewall rules
- Typical recovery: reconfigure WireGuard, redistribute peer configs

### Firewall Isolation Failure

- If firewall rules misconfigured, server might reach other LAN devices or vice versa
- Monitor router firewall logs for unexpected traffic
- Validate firewall rules regularly (see `NETWORK_DOCUMENTATION.md`)

### Configuration Error

- If Ollama binding wrong: VPN clients cannot connect
- If router firewall rules wrong: VPN clients blocked or have excessive access
- Verify binding: `lsof -i :11434` on server
- Verify firewall: test from VPN client with `nc -zv 192.168.250.20 11434`

**Defense in depth**: Network perimeter provides security even if Ollama has vulnerabilities.

---

## Monitoring & Observability

### Health Checks

**Ollama health (from server):**
```bash
curl http://192.168.250.20:11434/api/version
```

**End-to-end health (from VPN client):**
```bash
curl http://192.168.250.20:11434/v1/models
```

**Router health:**
```bash
# On router via SSH
wg show wg0  # WireGuard status
iptables -L -n -v  # Firewall rules with counters
```

### Log Locations

**Server:**
- Ollama: `/tmp/ollama.stdout.log`, `/tmp/ollama.stderr.log`
- LaunchAgent: `~/Library/Logs/` (system logs)

**Router:**
- System log: `/var/log/messages` (or via LuCI web interface)
- Firewall log: `/var/log/firewall` (if logging enabled)
- WireGuard: `logread | grep wireguard`

### Optional Monitoring

Router can log (configure in `NETWORK_DOCUMENTATION.md`):
- Connection attempts to port 11434
- WireGuard handshakes
- Firewall blocks
- Bandwidth usage per VPN peer

Not required for v2, but useful for security auditing.

---

## Summary

This architecture provides:

> **Self-sovereign remote access via defense-in-depth**

Two independent layers:
1. **Network Perimeter (Router + VPN + Firewall)** - Controls who can reach the server and enforces isolation
2. **AI Server (Ollama)** - Provides inference service, unaware of perimeter security

Benefits:
- ✅ Self-sovereign infrastructure (no third-party VPN service)
- ✅ Single ingress point (router controls all remote access)
- ✅ Firewall-based isolation (server isolated from other LAN devices)
- ✅ Modern cryptography (WireGuard per-peer keys)
- ✅ Defense in depth (firewall + isolation rules + binding)
- ✅ Negligible performance impact (<1ms VPN overhead)
- ✅ Modular architecture (layers can be implemented independently)
- ✅ Simple deployment (no separate physical or VLAN DMZ required)

All while maintaining:
- Zero public exposure of inference port
- Zero third-party cloud dependencies
- Simple operational model (LaunchAgent for Ollama, OpenWrt for router)
- Wired network only (no Wi-Fi infrastructure)
- Full control over network topology
