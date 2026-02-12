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
| **Specs** | 100% | All 18 specs (9 server, 9 client) are v2-compliant. v1 refs are legitimate historical context only. |
| **Server Scripts** | ~15% | `warm-models.sh` is mostly v2-compliant but uses `localhost` (breaks with DMZ-only binding). `install.sh`, `uninstall.sh`, `test.sh` are v1. |
| **Client Scripts** | ~55% | `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh` are v2-compliant. `env.template` is v2-compliant. `install.sh`, `uninstall.sh`, `test.sh` still reference Tailscale. |
| **Root Analytics** | 100% | `loop.sh`, `loop-with-analytics.sh`, `compare-analytics.sh` are v2-compliant. |
| **Documentation** | 100% | All READMEs, SETUP guides, ROUTER_SETUP.md are v2-compliant. |

**Target Architecture** (v2):
```
Client -> WireGuard VPN (OpenWrt Router) -> Firewall -> Ollama (192.168.100.10:11434)
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

## P1: Server Scripts — Rewrite for v2

**Spec authority**: `server/specs/SCRIPTS.md`

### P1a: `server/scripts/install.sh` (751 lines — complete rewrite)

- **Remove** Tailscale install/connect workflow (lines 95-227, ~133 lines)
- **Remove** HAProxy install/config (lines 352-624, ~273 lines)
- **Remove** Tailscale ACL instructions (lines 626-698, ~72 lines)
- **Remove** v1 final summary referencing Tailscale/HAProxy (lines 700-751)
- **Remove** `OLLAMA_HOST=127.0.0.1` binding (line 284)
- **Keep** helpers, system validation, Ollama install, LaunchAgent lifecycle, health check (~300 lines)
- **Modify** plist `OLLAMA_HOST` to `192.168.100.10` (or `0.0.0.0`)
- **Modify** all health check and self-test URLs from `localhost` to DMZ IP (or auto-detect from plist)
- **Add** router setup check prompt (reference `ROUTER_SETUP.md`)
- **Add** DMZ network config prompts (subnet default `192.168.100.0/24`, IP default `192.168.100.10`)
- **Add** IP format and subnet membership validation
- **Add** static IP config via `sudo networksetup -setmanual "Ethernet" ...`
- **Add** interface detection via `networksetup -listallhardwareports`
- **Add** DNS config (router primary, public backup)
- **Add** binding verification via `lsof -i :11434`
- **Add** router connectivity test via `ping -c 3 192.168.100.1`
- **Add** optional model pre-pull prompt
- **Add** v2 final summary (DMZ IP, auto-start, router connectivity, troubleshooting)

### P1b: `server/scripts/uninstall.sh` (210 lines — moderate edit)

- **Remove** HAProxy cleanup section (lines 92-155, service stop, plist, config dir, logs)
- **Remove** "Tailscale" from preserved items list (line 161)
- **Remove** "HAProxy binary" from preserved items list (line 163)
- **Remove** Tailscale/HAProxy uninstall instructions (lines 200-206)
- **Keep** Ollama service stop, plist removal, log cleanup, model preservation (~146 lines)
- **Add** optional static IP → DHCP revert prompt (`sudo networksetup -setdhcp "Ethernet"`)
- **Add** router config cleanup reminder (remove WireGuard peer, DMZ rules; reference `ROUTER_SETUP.md`)

### P1c: `server/scripts/test.sh` (1089 lines — substantial edit)

- **Remove** Test 18: loopback binding check expecting `127.0.0.1` (lines 853-872)
- **Remove** Test 19: localhost access test (lines 874-880)
- **Remove** Test 20: Tailscale IP access test (lines 882-897)
- **Remove** Tests 21-30: entire HAProxy test section (lines 900-1058, ~158 lines)
- **Fix** test numbering conflict: Anthropic tests currently numbered 21-26 overlap with HAProxy tests 21-30
- **Fix** `TOTAL_TESTS=36` to match actual test count after v2 migration
- **Modify** Test 17: `OLLAMA_HOST` plist check to accept `192.168.100.10` or `0.0.0.0` (not `127.0.0.1`)
- **Modify** all API test URLs from `localhost` to DMZ IP (or auto-detect from plist `OLLAMA_HOST` value)
- **Modify** "What's Next" section to reference `ROUTER_SETUP.md`/WireGuard instead of Tailscale
- **Add** network configuration tests: static IP configured, IP matches DMZ, router connectivity, DNS, internet, LAN isolation
- **Add** DMZ IP connectivity test: `curl http://192.168.100.10:11434/v1/models`
- **Add** binding verification: `lsof -i :11434` shows DMZ IP or `0.0.0.0`
- **Add** manual checklist display (VPN client, router SSH, internet — not automated)

### P1d: `server/scripts/warm-models.sh` — localhost fix

- **Modify** lines 56, 95: `localhost:11434` → auto-detect from `OLLAMA_HOST` env var or plist, fallback to `localhost`
- This ensures the script works with both `OLLAMA_HOST=192.168.100.10` and `OLLAMA_HOST=0.0.0.0`

---

## P2: Client Scripts — Tailscale → WireGuard

**Spec authority**: `client/specs/SCRIPTS.md`

### P2a: `client/scripts/install.sh` (617 lines — substantial rewrite)

- **Remove** entire Tailscale section: GUI check, install, connection flow, IP detection (lines 152-280, ~129 lines)
- **Modify** hostname prompt default from `self-sovereign-ollama` → `192.168.100.10` (line 286-291)
- **Modify** error messages referencing Tailscale → WireGuard VPN (lines 558, 607)
- **Add** WireGuard install: `brew install wireguard-tools`
- **Add** keypair generation: `wg genkey | tee privatekey | wg pubkey > publickey`
- **Add** key storage in `~/.ai-client/wireguard/` with `chmod 600` on private key
- **Add** public key display with instructions to send to router admin
- **Add** server IP prompt (default `192.168.100.10`)
- **Add** VPN server pubkey/endpoint prompts
- **Add** WireGuard config file generation (`~/.ai-client/wireguard/wg0.conf`)
- **Add** import instructions for WireGuard app or `wg-quick`
- **Add** VPN connection confirmation before connectivity test
- **Add** updated final summary (display pubkey, remind to send to admin, remind to connect VPN)

### P2b: `client/scripts/uninstall.sh` (156 lines — minor edit)

- **Change** line 6: "Leaves Tailscale" → "Leaves WireGuard"
- **Change** line 142: `echo "  - Tailscale"` → `echo "  - WireGuard"`
- **Add** display public key (from `~/.ai-client/wireguard/publickey`) before deletion
- **Add** WireGuard config cleanup (remove `~/.ai-client/wireguard/` contents)
- **Add** optional `brew uninstall wireguard-tools` prompt
- **Add** reminder to have router admin remove VPN peer (with public key displayed)

### P2c: `client/scripts/test.sh` (1420 lines — moderate edit)

- **Change** Test 8 (lines 248-254): `command -v tailscale` → `command -v wg` or `brew list wireguard-tools`
- **Change** Test 9 (lines 256-267): `tailscale status`/`tailscale ip -4` → WireGuard interface check (`wg show` or active `utun`)
- **Change** Test 14 (line 333): VPN connectivity check from Tailscale to WireGuard
- **Change** error messages (lines 558, 607, 641, 1403, 1413): "Tailscale" → "WireGuard VPN"/"VPN"
- **Keep** all other tests (environment config, dependencies, API contract, Aider, Claude Code, version management — all v2-compliant)

---

## P3: Hardware Validation

**Dependencies**: P1 + P2 complete
**Location**: Apple Silicon hardware + OpenWrt router

- [ ] `server/scripts/install.sh` completes without errors on target hardware
- [ ] `server/scripts/test.sh --verbose` — all automated tests pass
- [ ] `server/scripts/uninstall.sh` cleanly removes configuration
- [ ] `client/scripts/install.sh` completes without errors
- [ ] `client/scripts/test.sh --verbose` — all automated tests pass
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
