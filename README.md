<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# self-sovereign-ollama

**Ollama server setup for secure remote access.**

This project documents how to configure Ollama on Apple Silicon for remote access with dual API support (OpenAI-compatible and Anthropic-compatible endpoints).

## Project Structure

This monorepo contains two main components:

- **server/** – Ollama server configuration for macOS with dual API support
- **client/** – Client-side setup for connecting to remote Ollama (Aider and Claude Code)

## About Network Documentation

**Important**: This repository also includes documentation of the network infrastructure I set up to enable remote access (`server/NETWORK_DOCUMENTATION.md`), but **the network setup is essentially a separate project** from the Ollama server configuration.

**Why it's documented here:**
- To serve as reference material for how I configured my specific network setup
- To help others who might want to implement something similar
- To document the complete end-to-end solution I built

**What you should know:**
- The network setup (OpenWrt router + WireGuard VPN + firewall configuration) is **optional** and represents one possible approach
- You can use the server setup with any network architecture that provides remote access (Tailscale, Cloudflare Tunnel, direct port forwarding, etc.)
- The network documentation reflects my specific configuration and may not match your needs or existing infrastructure

**Focus of this repo**: Setting up and running Ollama with dual API support. The network layer is documented separately as a reference implementation.

---

## Overview

The self-sovereign-ollama project documents how to run Ollama on your own hardware with remote access.

### Server (ai-server)
- Runs Ollama on a dedicated Apple Silicon Mac with high unified memory
- Exposes dual API: OpenAI-compatible `/v1` and Anthropic-compatible `/v1/messages` endpoints
- Supports both Aider (OpenAI API) and Claude Code (Anthropic API)
- Native macOS service management via launchd
- Configurable network binding (dedicated IP or all interfaces)
- 24/7 operation for on-demand inference

### Client (ai-client)
- macOS environment setup and configuration
- Connects to remote Ollama server (requires network connectivity - see Network Documentation section)
- Configures tools (Aider, optionally Claude Code) to use remote Ollama automatically
- Optional: Claude Code can use either Anthropic cloud API or remote Ollama backend
- Zero manual configuration per session

## Quick Start

### Server Setup
See [server/README.md](server/README.md) for detailed server installation and configuration.

### Client Setup
See [client/README.md](client/README.md) for client installation and usage.

## Supported Tools in Client

### Aider
- Uses OpenAI-compatible API (`/v1/chat/completions`)
- Connects to remote Ollama automatically after installation
- Zero configuration per session

### Claude Code
- **Default**: Uses Anthropic cloud API (Opus 4.6, Sonnet 4.5)
- **Optional**: Can use self-hosted Ollama backend via Anthropic-compatible API (`/v1/messages`)
- Optional backend switching via shell alias
- Version compatibility checking and management tools included

## Network Documentation (Reference Implementation)

**Note**: This section documents the specific network architecture I configured for my setup. This is **not required** for running Ollama - it's just one possible approach to enable remote access. You can use any network solution that provides connectivity to your Ollama server (VPN, reverse proxy, direct port forwarding, etc.).

**My network configuration** (see [server/NETWORK_DOCUMENTATION.md](server/NETWORK_DOCUMENTATION.md) for complete details):

```
Client → WireGuard VPN (OpenWrt Router) → Firewall (port 11434 only) → Ollama (192.168.250.20)
```

**Architecture:**
- OpenWrt router running WireGuard VPN server (behind ISP router)
- Firewall-based isolation for AI server on LAN
- VPN provides secure remote access without public exposure of port 11434

**My network topology:**
- **VPN subnet**: 10.10.10.0/24 (WireGuard clients)
- **LAN subnet**: 192.168.250.0/24 (All devices including isolated AI server)
- **AI server**: 192.168.250.20 (isolated via firewall rules)
- **Upstream network**: 192.168.2.0/24 (ISP router, OpenWrt is behind it)

**Why I chose this:**
- Self-sovereign infrastructure (no third-party VPN services)
- Complete control over network security
- No reliance on cloud services
- Firewall-based isolation without needing separate physical networks

**Alternative approaches** you might prefer:
- Tailscale or other mesh VPN services
- Cloudflare Tunnel or similar reverse proxies
- Direct port forwarding (if you're comfortable with public exposure)
- SSH tunneling
- Any other method that connects your client to your server's port 11434

## Requirements

### Server (Core Requirements)
- Apple Silicon Mac (M-series) with ≥96 GB unified memory recommended
- macOS 14 Sonoma or later
- Homebrew
- Network connectivity (any method - see Network Documentation section for my approach)
- High upload bandwidth (≥100 Mb/s recommended for remote streaming)
- 24/7 operation capability

### Client
- macOS 14 Sonoma or later
- Homebrew
- Python 3.10+
- Network access to server (method depends on your network setup)

### Network Infrastructure (My Specific Setup - Optional Reference)

**Note**: These requirements only apply if you want to replicate my network configuration. See [server/NETWORK_DOCUMENTATION.md](server/NETWORK_DOCUMENTATION.md).

- OpenWrt-compatible router (or use existing router with WireGuard support)
- WireGuard VPN (or alternative like Tailscale, Cloudflare Tunnel, etc.)
- Ability to configure firewall rules (for server isolation)
- Public IP or DDNS (if exposing VPN endpoint to internet)

## Documentation

### Setup Guides
- [server/README.md](server/README.md) – Server overview and quick reference
- [server/SETUP.md](server/SETUP.md) – Server installation instructions
- [server/NETWORK_DOCUMENTATION.md](server/NETWORK_DOCUMENTATION.md) – OpenWrt router + WireGuard VPN configuration guide
- [client/README.md](client/README.md) – Client overview and quick reference
- [client/SETUP.md](client/SETUP.md) – Client installation instructions

### Specifications
- **Server specs**: `server/specs/` – Server architecture, dual API support, Anthropic compatibility, **security model**, hardening options
- **Client specs**: `client/specs/` – Client architecture, API contract, Claude Code integration, analytics, version management

### Project Management
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) – Implementation status and roadmap
- [AGENTS.md](AGENTS.md) – Component responsibilities and coordination

## Security Model (My Network Implementation)

**Note**: This security model describes my specific network configuration. If you use a different approach (Tailscale, Cloudflare Tunnel, etc.), your security model will differ.

### My Two-Layer Architecture

**Layer 1: Network Perimeter (OpenWrt Router + WireGuard)**
- **WireGuard VPN**: Per-peer public key authentication (cryptographic identity)
- **Firewall-Based Isolation**: Server isolated from other LAN devices via firewall rules
- **Firewall Rules**: VPN → AI server port 11434 only, AI server → other LAN devices denied
- **Self-Sovereign Infrastructure**: No third-party VPN services

**Layer 2: AI Server (Ollama)**
- **Direct API Exposure**: All Ollama endpoints accessible to authorized network clients
- **Dedicated IP Binding**: Ollama listens on dedicated LAN IP (192.168.250.20)
- **Firewall Isolation**: Cannot access other LAN devices or services

### Security Properties (My Setup)

- ✅ **Cryptographic authentication** - WireGuard per-peer public keys (no shared secrets)
- ✅ **Network isolation** - Server isolated from other LAN devices via firewall
- ✅ **Port-level control** - Only port 11434 accessible from VPN clients
- ✅ **Self-sovereign** - No reliance on third-party VPN services
- ✅ **Defense in depth** - VPN authentication + firewall isolation + port firewall

**Your security model will depend on your network approach**. See [server/NETWORK_DOCUMENTATION.md](server/NETWORK_DOCUMENTATION.md) for details on my configuration, and [server/specs/SECURITY.md](server/specs/SECURITY.md) for security considerations.

## License

Proprietary. Copyright (c) 2026 Henrique Falconer. All rights reserved.
