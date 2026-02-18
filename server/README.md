# self-sovereign-ollama ai-server

**Ollama server configuration for remote access on Apple Silicon.**

## Overview

This configures Ollama on macOS to provide remote LLM inference with:
- **Dual API support**: OpenAI-compatible `/v1/*` and Anthropic-compatible `/v1/messages` endpoints
- Supports both Aider (OpenAI API) and Claude Code (Anthropic API)
- Native macOS service management via launchd
- Configurable network binding (dedicated IP or all interfaces)
- Runs exclusively on a dedicated, always-on Mac

## About Network Configuration

**Important**: This documentation focuses on the **Ollama server setup**. Network configuration (VPN, firewall, remote access) is documented separately in [NETWORK_DOCUMENTATION.md](NETWORK_DOCUMENTATION.md) as a reference implementation, but it's **essentially an independent project**.

**What this means:**
- The server setup works with any network approach that provides connectivity
- The network documentation reflects my specific setup (OpenWrt + WireGuard) and serves as reference material
- You can use different solutions (Tailscale, Cloudflare Tunnel, direct port forwarding, etc.)

See [NETWORK_DOCUMENTATION.md](NETWORK_DOCUMENTATION.md) for details on my network configuration if you're interested in replicating it.

## Quick Reference

| Operation | Command | Description |
|-----------|---------|-------------|
| **Check status** | `launchctl list \| grep com.ollama` | Check if Ollama service is loaded |
| | `curl -sf http://192.168.250.20:11434/v1/models` | Test API endpoint availability from VPN |
| **Start service** | `launchctl kickstart gui/$(id -u)/com.ollama` | Start Ollama if stopped |
| **Stop service** | `launchctl stop gui/$(id -u)/com.ollama` | Stop Ollama temporarily |
| **Restart service** | `launchctl kickstart -k gui/$(id -u)/com.ollama` | Kill and restart Ollama immediately |
| **View logs** | `tail -f /tmp/ollama.stdout.log` | Monitor Ollama standard output logs |
| | `tail -f /tmp/ollama.stderr.log` | Monitor Ollama error logs |
| **Check models** | `ollama list` | List all pulled models |
| **Warm models** | `./scripts/warm-models.sh <model-name>` | Pre-load models into memory for faster response |
| **Run tests** | `./scripts/test.sh` | Run comprehensive test suite (36 tests) |
| | `./scripts/test.sh --skip-anthropic-tests` | Skip Anthropic API tests (for Ollama < 0.5.0) |
| | `./scripts/test.sh --skip-model-tests` | Run tests without model inference |
| **Router config** | See [NETWORK_DOCUMENTATION.md](NETWORK_DOCUMENTATION.md) | OpenWrt + WireGuard VPN configuration guide |
| **Uninstall** | `./scripts/uninstall.sh` | Remove server configuration and services |

## Intended Deployment

- **Hardware**: Apple Silicon Mac (M-series) with ≥96 GB unified memory recommended
- **Network**: High upload bandwidth (≥100 Mb/s recommended for worldwide low-latency streaming)
- **Uptime**: 24/7 operation with UPS recommended
- **OS**: macOS 14 Sonoma or later

## Architecture

See [specs/ARCHITECTURE.md](specs/ARCHITECTURE.md) for full architectural details.

**Core server architecture:**
- Built on Ollama's native dual API capabilities (OpenAI + Anthropic)
- Native macOS service management via launchd
- Configurable network binding (dedicated IP or all interfaces)
- Service auto-start and crash recovery

**My network topology** (see [NETWORK_DOCUMENTATION.md](NETWORK_DOCUMENTATION.md) for details):
```
Client → WireGuard VPN (OpenWrt Router) → Firewall (port 11434) → Ollama (192.168.250.20:11434)
```

**Network access** (your approach may differ):
- Remote access requires network connectivity (VPN, reverse proxy, etc.)
- My implementation uses WireGuard VPN with firewall-based server isolation
- See [NETWORK_DOCUMENTATION.md](NETWORK_DOCUMENTATION.md) for my specific network configuration

## API

The server exposes dual API surfaces directly via Ollama at:
```
http://192.168.250.20:11434
```

All Ollama endpoints are accessible to authorized VPN clients. Access control provided by router firewall (VPN authentication + port 11434 only).

### OpenAI-Compatible API

For Aider and OpenAI-compatible tools:

**Available endpoints:**
- `/v1/chat/completions` - Streaming, JSON mode, tool calling
- `/v1/models` - List available models
- `/v1/models/{model}` - Get model details
- `/v1/responses` - Experimental non-stateful endpoint (Ollama 0.5.0+)

### Anthropic-Compatible API

For Claude Code and Anthropic-compatible tools:

**Available endpoint:**
- `/v1/messages` - Anthropic Messages API compatibility (Ollama 0.5.0+)

**Supported**:
- Messages, streaming, system prompts, multi-turn conversations
- Vision (base64 images), tool use, thinking blocks

**Limitations**:
- No `tool_choice` parameter
- No prompt caching (major performance impact)
- No PDF support, no URL-based images

See [specs/ANTHROPIC_COMPATIBILITY.md](specs/ANTHROPIC_COMPATIBILITY.md) for complete specification.

### Ollama Native API

All native Ollama endpoints accessible to VPN clients:
- `GET /api/version` - Ollama version info
- `GET /api/tags` - List models
- `POST /api/show` - Model details
- `POST /api/pull`, `/api/delete`, `/api/create`, `/api/push`, `/api/copy` - Model management

**Note**: v2 architecture trusts authorized VPN clients. If model management restriction needed, add reverse proxy (see [specs/HARDENING_OPTIONS.md](specs/HARDENING_OPTIONS.md)).

### API Contract

Full API contract documented in [../client/specs/API_CONTRACT.md](../client/specs/API_CONTRACT.md).

## Setup

See [SETUP.md](SETUP.md) for complete server installation instructions.

**Quick summary** (server only):
1. Install Ollama on Mac server
2. Configure Ollama to bind to dedicated IP or all interfaces via launchd
3. Configure server with static IP (if using dedicated IP binding)
4. Pull desired models via Ollama CLI
5. Verify local connectivity

**For remote access**, you'll also need network configuration. See [NETWORK_DOCUMENTATION.md](NETWORK_DOCUMENTATION.md) for my approach (OpenWrt + WireGuard), or use your preferred method (Tailscale, Cloudflare Tunnel, etc.).

## Operations

Once installed, Ollama service runs as a LaunchAgent and starts automatically at login.

### Check Status
```bash
# Check if Ollama service is running
launchctl list | grep com.ollama

# Test API endpoint (from server locally on dedicated IP)
curl -sf http://192.168.250.20:11434/v1/models

# Test from VPN client (requires VPN connection)
curl -sf http://192.168.250.20:11434/v1/models
```

### Start Service
```bash
# Start Ollama (if stopped)
launchctl kickstart gui/$(id -u)/com.ollama
```

### Stop Service
```bash
# Stop Ollama temporarily
launchctl stop gui/$(id -u)/com.ollama
```

### Restart Service
```bash
# Restart Ollama (kill and restart immediately)
launchctl kickstart -k gui/$(id -u)/com.ollama
```

### Disable Service (Prevent Auto-Start)
```bash
# Unload Ollama completely
launchctl bootout gui/$(id -u)/com.ollama
```

### Re-enable Service
```bash
# Load Ollama again
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist
```

### View Logs
```bash
# Ollama standard output
tail -f /tmp/ollama.stdout.log

# Ollama error output
tail -f /tmp/ollama.stderr.log
```

### Warm Models (Optional Performance Optimization)

The `warm-models.sh` script pre-loads models into memory for faster first-request latency. This is useful for ensuring models are immediately ready after server boot or restart.

```bash
# Warm a single model
./scripts/warm-models.sh qwen2.5-coder:32b

# Warm multiple models
./scripts/warm-models.sh qwen2.5-coder:32b deepseek-r1:70b llama3.2-vision:90b
```

What it does:
- Pulls each model (downloads if not already present)
- Sends a minimal inference request to force-load the model into memory
- Continues processing remaining models if one fails
- Provides detailed progress reporting and summary

When to use it:
- After server restarts or reboots to eliminate cold-start latency
- Before critical workloads that require immediate response
- Can be integrated into launchd for automatic warmup at boot (see script comments)

## Testing & Verification

### Running the Test Suite

The server includes a comprehensive automated test suite that verifies all functionality:

```bash
# Run all tests (36 tests: service status, OpenAI API, Anthropic API, security, network configuration)
./scripts/test.sh

# Skip Anthropic API tests (useful for Ollama versions < 0.5.0)
./scripts/test.sh --skip-anthropic-tests

# Run tests without model inference (faster, skips model-dependent tests)
./scripts/test.sh --skip-model-tests

# Run with verbose output (shows full API request/response details and timing)
./scripts/test.sh --verbose
```

### Test Coverage

The test suite validates:
- **Service Status** (3 tests): Ollama LaunchAgent loaded, process running, port listening, HTTP response
- **OpenAI API** (7 tests): All OpenAI-compatible endpoints (`/v1/models`, `/v1/models/{model}`, `/v1/chat/completions`, `/v1/responses`), streaming, error handling
- **Anthropic API** (5 tests): `/v1/messages` endpoint (non-streaming, streaming, system prompts, error handling)
- **Security** (4 tests): Process owners, log files, plist configuration, OLLAMA_HOST verification
- **Network Configuration** (6 tests): Dedicated IP binding (192.168.250.20), localhost unreachable (dedicated IP only), static IP configuration
- **Router Integration** (Manual checklist): VPN connectivity, firewall rules, server isolation (requires SSH access to router)

**Total**: 36 tests (automated) + manual router integration checklist

### Sample Output

```
self-sovereign-ollama ai-server Test Suite
Running 36 tests

=== Service Status Tests ===
✓ PASS Ollama LaunchAgent is loaded: com.ollama
✓ PASS Ollama process is running (PID: 19272, user: vm)
✓ PASS Ollama is listening on port 11434

=== Network Configuration Tests ===
✓ PASS Ollama is bound to dedicated LAN IP (192.168.250.20)
✓ PASS Ollama is unreachable from localhost (dedicated IP only)
✓ PASS Static IP configured on isolated LAN

=== OpenAI API Endpoint Tests ===
✓ PASS GET /v1/models returns valid JSON (1 models)
✓ PASS GET /v1/models/{model} returns valid model details
✓ PASS POST /v1/chat/completions (non-streaming) succeeded
✓ PASS POST /v1/chat/completions (streaming) returns SSE chunks

=== Anthropic API Tests ===
✓ PASS POST /v1/messages (non-streaming) succeeded
✓ PASS POST /v1/messages (streaming) returns SSE chunks
✓ PASS POST /v1/messages with system prompt succeeded
✓ PASS POST /v1/messages error handling works (400/404/500)
✓ PASS POST /v1/messages multi-turn conversation succeeded
✓ PASS POST /v1/messages streaming includes usage metrics

...

Test Summary
───────────────────────────────
Passed:  36
Failed:  0
Skipped: 0
Total:   36
═══════════════════════════════

✓ All tests passed!

=== Manual Router Integration Checklist ===
(Requires SSH access to router - see NETWORK_DOCUMENTATION.md)
```

All 36 automated tests pass (service status, APIs, security, network configuration).

## Security

See [specs/SECURITY.md](specs/SECURITY.md) for complete security considerations.

**Server security:**
- Ollama runs as user-level process (not root)
- Logs stored locally
- No built-in authentication (relies on network-level access control)
- All Ollama endpoints accessible to network clients

**Network security** (depends on your approach):
- My implementation: WireGuard VPN with firewall-based isolation (see [NETWORK_DOCUMENTATION.md](NETWORK_DOCUMENTATION.md))
- Your implementation may use different methods (Tailscale, reverse proxy with auth, etc.)
- Security model depends on how you provide remote access

## Documentation

- [SETUP.md](SETUP.md) – Server setup instructions
- [NETWORK_DOCUMENTATION.md](NETWORK_DOCUMENTATION.md) – OpenWrt router + WireGuard VPN configuration guide
- [specs/ARCHITECTURE.md](specs/ARCHITECTURE.md) – Architecture and principles
- [specs/FUNCTIONALITIES.md](specs/FUNCTIONALITIES.md) – Detailed functionality specifications
- [specs/SECURITY.md](specs/SECURITY.md) – Security model and two-layer architecture
- [specs/INTERFACES.md](specs/INTERFACES.md) – External interfaces
- [specs/FILES.md](specs/FILES.md) – Repository layout
- [specs/HARDENING_OPTIONS.md](specs/HARDENING_OPTIONS.md) – Router-based security expansion options

## Out of Scope

- Built-in authentication proxy / API keys
- Web-based chat UI
- Automatic model quantization
- Load balancing across multiple nodes
- Monitoring / metrics endpoint
