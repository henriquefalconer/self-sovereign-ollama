# self-sovereign-ollama ai-server Security Model (v2.0.0)

## Security Philosophy

This architecture implements **defense in depth** through two independent layers:

1. **Network Perimeter Layer** (Router + VPN + Firewall) - Controls who can reach the server and enforces network isolation
2. **AI Server Layer** (Ollama) - Provides inference service, secured by network perimeter

Each layer is independently auditable and provides security even if the other has misconfigurations.

---

## Network Topology

```
Internet
   ↓
WireGuard UDP port (only public exposure)
   ↓
┌──────────────────────────────────────────┐
│ OpenWrt Router (Network Perimeter)       │
│  • Firewall: deny all except WireGuard   │
│  • VPN → AI server: port 11434 only            │
│  • VPN → LAN: deny                       │
│  • AI server → LAN: deny                       │
└────────────┬─────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│ Isolated LAN (192.168.250.0/24)           │
│                                           │
│  ┌────────────────────────────────────┐  │
│  │ self-sovereign-ollama server         │  │
│  │ IP: 192.168.250.20                 │  │
│  │ Bind: 192.168.250.20:11434         │  │
│  │                                    │  │
│  │ • Ollama: listens on dedicated LAN IP│  │
│  │ • No LAN access                   │  │
│  │ • Internet outbound allowed       │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘

Other LAN Devices (192.168.250.0/24)
  • Cannot reach AI server (firewall blocks)
  • Cannot reach VPN clients (firewall blocks)
  • Admin devices can access router for management
```

---

## LAYER 1: Network Perimeter Security (Router + VPN + Firewall)

### What it controls

**Who can reach the server and what network resources are accessible**

### Implementation Components

**1. Router Firewall (OpenWrt)**
- Default deny all inbound from WAN
- Only WireGuard UDP port exposed publicly
- Stateful packet inspection
- Per-zone firewall rules (WAN, LAN, VPN) + isolation rules for AI server

**2. WireGuard VPN**
- Per-peer public key authentication (no shared secrets)
- Modern cryptography (ChaCha20, Poly1305, Curve25519)
- Minimal attack surface (~4,000 lines of code)
- No user/password authentication (key-based only)

**3. Isolated LAN Segmentation**
- Firewall rules isolate AI server from other LAN devices
- Firewall isolation from LAN
- Outbound internet allowed (for model downloads, OS updates)
- No inbound connections except via VPN

### Firewall Rules (Enforced at Router)

```
# WAN → Router
accept: WireGuard UDP port only
deny: everything else

# VPN → AI server
accept: TCP port 11434 to 192.168.250.20
deny: everything else

# VPN → LAN
deny: all

# VPN → WAN
deny: all (no internet access from VPN clients)

# AI server → other LAN devices
deny: all

# AI server → WAN
accept: all (outbound internet for models, updates)

# LAN → AI server
accept: all (admin access, optional)

# LAN → Router
accept: SSH, LuCI (admin only)
```

### Security Properties

✅ **Single ingress point** - Router is only entry to network
✅ **Public exposure minimized** - Only WireGuard UDP port public
✅ **Cryptographic authentication** - Per-peer keys, no passwords
✅ **Network segmentation** - AI server isolated from other LAN devices via firewall
✅ **Blast radius containment** - Server compromise cannot reach LAN
✅ **Peer revocation** - Remove public key from router immediately

❌ Does not prevent authorized VPN clients from abusing inference API
❌ Does not prevent Ollama vulnerabilities from being exploited
❌ Does not inspect application-layer requests

### Why Network Perimeter is Fundamental

Network perimeter transforms security model from:

> "Server is public; trust application to secure itself"

To:

> "Server is private; only authorized devices can reach it"

This is **enforced by router hardware** and kernel packet filtering, not by application configuration.

---

## LAYER 2: AI Server Security (Ollama)

### What it controls

**Inference service on isolated LAN**

### Implementation

- Ollama binds to dedicated LAN IP (`192.168.250.20:11434`)
- LaunchAgent plist sets `OLLAMA_HOST=192.168.250.20`
- No built-in authentication (relies on network perimeter)
- Logs stored locally (`/tmp/ollama.*.log`)
- No outbound telemetry

### Security Properties

✅ **Stateless** - No persistent user sessions or authentication tokens
✅ **No secrets** - No API keys, passwords, or sensitive data stored
✅ **Local logs only** - No external logging or telemetry
✅ **User-level process** - Runs as user, not root
✅ **Auto-restart** - LaunchAgent keeps service running

❌ **No authentication** - Trusts network perimeter completely
❌ **All endpoints exposed** - No application-layer filtering
❌ **No rate limiting** - Can be overwhelmed by authorized clients
❌ **No request inspection** - Cannot detect malicious payloads

### Why Application Layer Has Minimal Security

Design decision: **Security is enforced at network perimeter, not application layer.**

Rationale:
- Simpler architecture (no HAProxy, no endpoint filtering)
- Fewer moving parts (less to break)
- Ollama focuses on inference, router focuses on security
- Clear separation of concerns

---

## What This Architecture Prevents

### ✅ Completely Prevented

**Unauthorized network access:**
- No public access to inference port (11434)
- Only WireGuard-authenticated devices can reach server
- LAN devices cannot reach AI server (unless admin allows)
- VPN clients cannot reach LAN
- Internet users cannot scan or discover server

**Network-based reconnaissance:**
- Port scanning from internet sees only WireGuard UDP port
- No service fingerprinting possible without VPN access
- firewall isolation prevents lateral movement if server compromised

**Common misconfigurations:**
- Port forwarding mistakes (11434 never forwarded)
- Accidental 0.0.0.0 binding still protected by firewall
- Firewall isolation prevents server from accessing LAN even if misconfigured

### ⚠️ Mitigated (but not eliminated)

**Resource exhaustion:**
- Firewall can limit connection rates (configure on router)
- Ollama still vulnerable to authorized client abuse
- OS still vulnerable to local resource pressure

**Lateral movement after compromise:**
- firewall isolation contains server compromise
- Attacker cannot reach LAN from compromised AI server
- But attacker has outbound internet (can exfiltrate data or download tools)

### ❌ Explicitly Out of Scope (v2 threat model)

**Authorized client abuse:**
- Excessive inference requests from valid VPN clients
- Prompt injection attacks
- Extraction of model weights
- Quality-of-service violations

**Application-layer vulnerabilities:**
- Ollama API bugs
- Model-level exploits
- Prompt-level attacks
- Zero-day exploits in Ollama

**Host compromise:**
- macOS kernel vulnerabilities
- Privilege escalation on server
- Local malware on server

**Outbound data exfiltration:**
- If server compromised, attacker has outbound internet
- Can exfiltrate data, communicate with C&C servers
- Trade-off: Outbound access needed for model downloads and OS updates
- **Alternative**: Fully air-gapped isolated server (no outbound internet, manual model loading)

These are valid concerns but **not fully addressed by this architecture**.

---

## Access Control & Revocation

### Adding a VPN client

1. **Client generates WireGuard keypair** (during install)
2. **Client sends public key to admin** (via secure channel)
3. **Admin adds public key to router** WireGuard config
4. **Admin applies firewall rules** allowing new peer to reach AI server port 11434
5. **Client establishes VPN tunnel** automatically

See `NETWORK_DOCUMENTATION.md` for detailed configuration steps.

### Revoking access

**Immediate revocation:**
1. **Remove public key** from router WireGuard config
2. **Reload WireGuard** service on router
3. Client can no longer establish tunnel

**Firewall-level revocation (slower):**
1. Add client VPN IP to firewall block list
2. Client can establish tunnel but cannot reach AI server

**Key rotation:**
- Generate new server keypair
- Redistribute new server public key to all clients
- Forces all clients to reconfigure

### Per-peer granularity

WireGuard configuration supports:
- **Per-peer AllowedIPs** - Restrict what each peer can access
- **Per-peer firewall rules** - Different access levels for different clients
- **Per-peer bandwidth limits** - QoS on router (optional)
- **Per-peer connection logging** - Audit who connects when

---

## Operational Security Requirements

### Logging

**Server:**
- Ollama logs remain local (`/tmp/ollama.stdout.log`, `/tmp/ollama.stderr.log`)
- No outbound telemetry or analytics
- Log rotation recommended (via `launchd` or external tool)

**Router:**
- Connection logs: `/var/log/messages` (or via `logread`)
- Firewall logs: can be enabled for port 11434 connections
- WireGuard handshake logs: useful for auditing access
- Log retention: configure on router (limited flash storage)

### Updates

Regular security updates required for:

**Server:**
- macOS system and security patches
- Ollama binary (via Homebrew or manual)

**Router:**
- OpenWrt firmware updates
- OpenWrt package updates (WireGuard, firewall, etc.)

**Clients:**
- WireGuard client software
- Operating system updates

### Process Ownership

**Server:**
- Ollama runs as user-level LaunchAgent (not root)
- No elevated privileges required during normal operation

**Router:**
- OpenWrt services run as appropriate users (root for firewall, dedicated users for others)
- WireGuard runs as kernel module (Linux kernel)

### Monitoring

**Server monitoring (optional):**
- Ollama health checks (via VPN client)
- System resource monitoring (CPU, memory, GPU)
- Model loading success/failure
- API response times

**Router monitoring (recommended):**
- WireGuard tunnel status (`wg show`)
- Firewall connection counters (`iptables -L -v -n`)
- CPU/memory usage (`top`, `free`)
- Bandwidth usage per peer (via QoS logs)

---

## CORS Considerations

- Default Ollama CORS restrictions apply
- No proxy to modify CORS headers
- Optional: Set `OLLAMA_ORIGINS` environment variable if browser-based clients are planned
- Browser clients must connect via VPN (same as CLI clients)

---

## Threat Model Summary

### In scope (addressed by this architecture)

✅ Unauthorized network access (no public exposure)
✅ Network-based reconnaissance (only WireGuard port visible)
✅ Lateral movement (firewall isolation)
✅ Per-device authentication (WireGuard per-peer keys)
✅ Device revocation (remove public key)

### Out of scope (explicitly not addressed)

❌ Authorized VPN client abuse (inference overload, malicious prompts)
❌ Application-layer vulnerabilities (Ollama bugs, zero-days)
❌ Host-level compromise (macOS exploits, malware)
❌ Physical access attacks (physical server access)
❌ Social engineering (stolen private keys, phishing admin)
❌ Outbound data exfiltration (if AI server compromised)
❌ Supply chain attacks (compromised Ollama binary, model backdoors)

This is intentional. The architecture focuses on **network perimeter security**, not application-layer or host-level security.

Future hardening options can be added **without changing this base architecture**:
- Air-gapped isolated server (no outbound internet)
- Application-layer rate limiting (reverse proxy on isolated LAN)
- Request inspection and filtering (WAF on router)
- Intrusion detection system (IDS via OpenWrt packages)

See `HARDENING_OPTIONS.md` for design space.

---

## Comparison with v1 (Tailscale + HAProxy)

### v1 Architecture (Tailscale + HAProxy + Loopback)

```
Client → Tailscale (100.x.x.x) → HAProxy → Ollama (127.0.0.1:11434)
```

**Characteristics:**
- Three-layer defense (Tailscale, HAProxy, loopback binding)
- Application-layer endpoint filtering (HAProxy allowlist)
- Third-party VPN service (Tailscale)
- More complex (3 components to manage)

**Benefits:**
- Endpoint allowlisting (can block specific Ollama endpoints)
- Simpler client setup (Tailscale GUI)

**Drawbacks:**
- Depends on Tailscale service availability
- HAProxy adds complexity (configuration, monitoring)
- Less control over network perimeter

### v2 Architecture (WireGuard + Firewall Isolation) - Current

```
Client → WireGuard VPN → Router Firewall → Ollama (isolated LAN)
```

**Characteristics:**
- Two-layer defense (network perimeter + firewall isolation)
- Network-layer access control (firewall rules)
- Self-sovereign infrastructure (OpenWrt + WireGuard)
- Simpler (fewer moving parts)

**Benefits:**
- No third-party VPN service dependency
- Full control over router and firewall
- Simpler architecture (no HAProxy)
- firewall isolation adds defense-in-depth

**Drawbacks:**
- No application-layer endpoint filtering (all Ollama endpoints accessible to VPN clients)
- More complex initial router setup
- Requires network administration skills

### Comparison Summary

| Aspect | v1 (Tailscale + HAProxy) | v2 (WireGuard + Firewall Isolation) |
|--------|--------------------------|----------------------|
| **Third-party dependency** | Yes (Tailscale) | No (self-sovereign) |
| **Endpoint filtering** | Yes (HAProxy allowlist) | No (firewall only) |
| **Network segmentation** | No | Yes (Firewall isolation) |
| **Complexity** | Higher (3 components) | Lower (2 layers) |
| **Control** | Less (Tailscale managed) | Full (you own router) |
| **Setup difficulty** | Easier (Tailscale GUI) | Harder (router config) |

---

## Outbound Internet Trade-offs

### Current Default: Outbound Allowed from isolated server

**Why:**
- Model downloads (`ollama pull`)
- OS updates (macOS security patches, Homebrew)
- Ollama binary updates
- Dependency updates

**Trade-off:**
- If server compromised, attacker can exfiltrate data
- Attacker can communicate with command & control servers
- Attacker can download additional tools

### Alternative: Fully Air-Gapped Server

**Configuration:**
- Set router firewall: `AI server → WAN: deny all`
- Manually transfer models to server via USB or LAN transfer
- Manually apply security updates during maintenance windows

**Benefits:**
- No data exfiltration possible if server compromised
- No C&C communication possible
- Maximum security posture

**Drawbacks:**
- Manual model management (slower, more error-prone)
- Delayed security updates (must remember to apply)
- More operational overhead

**Recommendation for self-sovereign networks:**
- **High-security environments**: Air-gap isolated server, manual model loading
- **Convenience-first environments**: Allow outbound, accept risk

---

## Future Hardening Options

This architecture provides a **foundation** for future security enhancements without re-architecture:

**Network-layer:**
- Connection rate limiting (router firewall)
- Per-peer bandwidth limits (QoS)
- Geo-IP blocking (if WireGuard keys stolen)
- Port knocking (additional obfuscation)

**Application-layer** (requires reverse proxy on isolated LAN):
- Request size limits
- Endpoint allowlisting (v1 HAProxy-style)
- API key authentication
- Rate limiting per client
- Request logging with attribution

**Isolated server layer:**
- Intrusion detection system (Snort, Suricata via OpenWrt)
- Web application firewall (ModSecurity)
- Outbound firewall logs and alerts

See `HARDENING_OPTIONS.md` for complete design space (not requirements, just options).

---

## Security Review Recommendations

For production deployments:

**Server validation:**
1. **Verify dedicated IP binding** - Run `lsof -i :11434` on server (should show dedicated LAN IP)
2. **Test LAN isolation** - Attempt to ping LAN devices from server (should fail)
3. **Test outbound** - Attempt to reach internet from server (should succeed or fail based on configuration)
4. **Monitor logs** - Check `/tmp/ollama.*.log` for unexpected activity

**Router validation:**
1. **Test VPN connectivity** - Connect from client, verify tunnel established
2. **Test firewall rules** - Attempt to reach port 11434 from VPN client (should succeed)
3. **Test LAN isolation** - Attempt to reach LAN from VPN client (should fail)
4. **Test WAN exposure** - Port scan public IP from internet (should only see WireGuard UDP)
5. **Review firewall logs** - Check for unexpected connection attempts

**Client validation:**
1. **Test VPN-only access** - Disconnect VPN, attempt to reach server (should fail)
2. **Test inference** - Connect via VPN, run sample inference (should succeed)
3. **Monitor connection** - Check for unexpected disconnections or slowdowns

**Ongoing:**
- Update regularly (server, router, clients)
- Rotate WireGuard keys periodically (optional, good practice)
- Review firewall logs monthly
- Document all configuration changes

---

## Summary

This architecture provides:

> **Self-sovereign network security through defense-in-depth**

Two independent layers:
1. **Network Perimeter (Router + VPN + Firewall)** - Controls who can reach the server
2. **AI Server (Ollama)** - Provides inference service, secured by perimeter

Security properties:
- ✅ No public exposure of inference port
- ✅ Per-device cryptographic authentication (WireGuard)
- ✅ Network segmentation (firewall isolation from LAN)
- ✅ Single ingress point (router)
- ✅ No third-party VPN dependency (self-sovereign)
- ✅ Device revocation (remove public key)
- ✅ Blast radius containment (server → LAN denied)

Trade-offs:
- ⚠️ No application-layer endpoint filtering (all Ollama endpoints accessible to VPN clients)
- ⚠️ Outbound internet allowed from isolated server by default (can be air-gapped with manual model loading)
- ⚠️ More complex router setup compared to Tailscale

Each layer is independently auditable and provides security even if the other is misconfigured.
