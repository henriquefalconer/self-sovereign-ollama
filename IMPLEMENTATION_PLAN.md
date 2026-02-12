<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-12

---

## Current Status

| Component | v2 Compliance | Summary |
|-----------|:------------:|---------|
| **Specs** | 100% | All 18 specs (9 server, 9 client) are v2-compliant. |
| **Server Scripts** | ~20% | Only `warm-models.sh` is v2-compliant. `install.sh`, `uninstall.sh`, `test.sh` are v1. |
| **Client Scripts** | ~60% | `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh`, `env.template` are v2-compliant. `install.sh`, `uninstall.sh`, `test.sh` still reference Tailscale. |
| **Root Analytics** | 100% | `loop.sh`, `loop-with-analytics.sh`, `compare-analytics.sh` are v2-compliant. |
| **Documentation** | 100% | All READMEs, SETUP guides, ROUTER_SETUP.md are v2-compliant. |

**Target Architecture** (v2):
```
Client -> WireGuard VPN (OpenWrt Router) -> Firewall -> Ollama (192.168.100.10:11434)
```

**v1 Architecture** (to be eliminated from scripts):
```
Client -> Tailscale -> HAProxy (100.x.x.x:11434) -> Ollama (127.0.0.1:11434)
```

---

## Dependency Graph

```
P1 (server scripts) --- can start immediately (specs are authoritative)
P2 (client scripts) --- can start immediately (independent of P1)
    |
P3 (hardware validation) --- depends on P1 + P2
```

P1 and P2 are independent and can be executed in parallel. They share no code and communicate only via the API contract (`client/specs/API_CONTRACT.md`).

---

## P1: Server Scripts -- Rewrite for v2

**Spec authority**: `server/specs/SCRIPTS.md`

### P1a: `server/scripts/install.sh` (751 lines -- complete rewrite)

**REMOVE** (~380 lines of v1 code):
- Lines 95-227: Tailscale install/connect workflow (~133 lines)
- Lines 352-624: HAProxy install/config (~273 lines)
- Lines 626-698: Tailscale ACL instructions (~72 lines)
- Line 284: `OLLAMA_HOST=127.0.0.1` binding
- Lines 700-751: v1 final summary referencing Tailscale/HAProxy

**KEEP** (~300 lines, v2-compatible):
- Lines 1-52: Helpers (colors, error handling, cleanup)
- Lines 54-94: macOS 14+ / Apple Silicon / Homebrew validation
- Lines 229-248: Ollama install via Homebrew
- Lines 250-308: LaunchAgent lifecycle (stop existing, create plist, bootstrap)
- Lines 310-350: Health check retry loop, process ownership check

**MODIFY**:
- Plist `OLLAMA_HOST`: `127.0.0.1` -> `192.168.100.10` (or `0.0.0.0`)
- Health check URLs: `localhost` -> DMZ IP throughout
- Self-test URL: `localhost` -> `192.168.100.10`

**ADD** (~200 lines per spec):
- Router setup check prompt (reference `ROUTER_SETUP.md`, abort if not done)
- DMZ network config prompts (subnet default `192.168.100.0/24`, IP default `192.168.100.10`)
- IP format and subnet membership validation
- Static IP config: `sudo networksetup -setmanual "Ethernet" ...`
- Interface detection: `networksetup -listallhardwareports`
- DNS config (router primary, public backup)
- Binding verification: `lsof -i :11434` (should show DMZ IP or `*:11434`)
- Router connectivity: `ping -c 3 192.168.100.1`
- Optional model pre-pull prompt
- v2 final summary (DMZ IP, auto-start, router connectivity, what's next, security notes, troubleshooting)

### P1b: `server/scripts/uninstall.sh` (210 lines -- moderate edit)

**REMOVE** (~65 lines):
- Lines 92-155: HAProxy cleanup section (service stop, plist, config dir, logs)
- Line 161: "Tailscale" in preserved items list
- Line 163: "HAProxy binary" in preserved items list
- Lines 200-206: Tailscale/HAProxy uninstall instructions

**KEEP** (~146 lines):
- Ollama service stop, plist removal, log cleanup, model preservation

**ADD** (~20 lines):
- Optional static IP -> DHCP revert: prompt, `sudo networksetup -setdhcp "Ethernet"`
- Router config cleanup reminder (remove WireGuard peer, DMZ rules; reference `ROUTER_SETUP.md`)

### P1c: `server/scripts/test.sh` (1089 lines -- substantial edit)

**REMOVE** (~170 lines):
- Lines 853-872: Test 18 (loopback binding check expecting `127.0.0.1`)
- Lines 874-880: Test 19 (localhost access test)
- Lines 882-897: Test 20 (Tailscale IP access test)
- Lines 900-1058: Tests 21-30 (entire HAProxy test section, 10 tests)

**MODIFY**:
- Test 17 (lines 840-848): `OLLAMA_HOST` plist check -- accept `192.168.100.10` or `0.0.0.0` (not `127.0.0.1`)
- "What's Next" section (lines 1082-1088): reference `ROUTER_SETUP.md`/WireGuard instead of Tailscale

**ADD** (~6 new automated tests + manual checklist):
- **Network Configuration Tests**: static IP configured, IP matches DMZ, router connectivity (`ping`), DNS resolution, outbound internet, LAN isolation (should fail)
- **DMZ IP Connectivity**: `curl http://192.168.100.10:11434/v1/models`
- **Binding Verification**: `lsof -i :11434` shows DMZ IP or `0.0.0.0`
- **Router Integration**: manual checklist display (VPN client, router SSH, internet -- not automated)
- Update `TOTAL_TESTS` to reflect new count (~31 automated tests)

---

## P2: Client Scripts -- Update VPN References

**Spec authority**: `client/specs/SCRIPTS.md`

### P2a: `client/scripts/install.sh` (617 lines -- substantial rewrite)

**REMOVE** (~129 lines):
- Lines 152-280: Entire Tailscale section (GUI check, install, connection flow, IP detection)

**MODIFY** (~50 lines):
- Lines 4-5, 53: project name/branding
- Lines 286-291: hostname prompt default `self-sovereign-ollama` -> `192.168.100.10`
- Lines 312, 360: env template comments
- Line 540: GitHub URL
- Lines 558, 607: error messages referencing Tailscale -> WireGuard VPN

**ADD** (~130 lines per spec):
- WireGuard install: `brew install wireguard-tools`
- Keypair generation: `wg genkey | tee privatekey | wg pubkey > publickey`
- Key storage in `~/.ai-client/wireguard/` with `chmod 600` on private key
- Public key display with instructions for router admin
- Server IP prompt (default `192.168.100.10`)
- VPN server pubkey/endpoint prompts
- WireGuard config file generation (`~/.ai-client/wireguard/wg0.conf`)
- Import instructions for WireGuard app or `wg-quick`
- VPN connection confirmation before connectivity test
- Updated final summary (display pubkey, remind to send to admin, remind to connect VPN)

### P2b: `client/scripts/uninstall.sh` (156 lines -- minor edit)

**CHANGE** (2 lines):
- Line 6: "Leaves Tailscale" -> "Leaves WireGuard"
- Line 142: `echo "  - Tailscale"` -> `echo "  - WireGuard"`

**ADD** (~15 lines):
- Display public key (if available) before deletion
- WireGuard config cleanup (remove `~/.ai-client/wireguard/` contents)
- Optional `brew uninstall wireguard-tools` prompt
- Reminder to have router admin remove VPN peer

### P2c: `client/scripts/test.sh` (1420 lines -- moderate edit)

**CHANGE** (~20 lines):
- Test 8 (lines 248-254): `command -v tailscale` -> `command -v wg` or `brew list wireguard-tools`
- Test 9 (lines 256-267): `tailscale status`/`tailscale ip -4` -> WireGuard interface check (`wg show` or active `utun` interface)
- Error messages (lines 558, 607, 641, 1403, 1413): "Tailscale" -> "WireGuard VPN"/"VPN"
- Test 14 connectivity context: VPN connection check before server tests

**KEEP**: All other tests (environment config, dependencies, API contract, Aider, Claude Code, version management -- all v2-compliant)

---

## P3: Hardware Validation

**Dependencies**: P1 + P2 complete
**Location**: Apple Silicon hardware + OpenWrt router

- [ ] `server/scripts/install.sh` completes without errors on target hardware
- [ ] `server/scripts/test.sh --verbose` -- all automated tests pass
- [ ] `server/scripts/uninstall.sh` cleanly removes configuration
- [ ] `client/scripts/install.sh` completes without errors
- [ ] `client/scripts/test.sh --verbose` -- all automated tests pass
- [ ] `client/scripts/uninstall.sh` cleanly removes configuration
- [ ] WireGuard VPN: client connects through router tunnel to server
- [ ] DMZ isolation: server cannot reach LAN (`ping 192.168.1.x` fails)
- [ ] End-to-end: Aider and Claude Code inference works via VPN
- [ ] Version management: `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh` work
- [ ] Analytics: `loop-with-analytics.sh` captures metrics
- [ ] Idempotency: re-running install scripts on already-installed system succeeds cleanly

---

## Implementation Constraints

1. **Specs are authoritative**: `server/specs/*.md` (9 files), `client/specs/*.md` (9 files). Scripts must match specs.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for the server-client interface.
3. **Security**: WireGuard VPN + OpenWrt firewall + DMZ isolation. No public exposure. No built-in auth.
4. **Idempotency**: All scripts must be safe to re-run without side effects.
5. **No stubs**: Implement completely or not at all.
6. **Claude Code integration is optional**: Always prompt for user consent on the client side.
7. **curl-pipe install**: Client `install.sh` must work via `curl | bash`.
