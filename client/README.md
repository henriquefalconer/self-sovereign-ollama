# remote-ollama ai-client

macOS client setup for connecting to remote Ollama, supporting both Aider and Claude Code.

## Overview

The remote-ollama ai-client is a one-time installer that configures your macOS environment to use remote Ollama via OpenAI-compatible and Anthropic-compatible APIs.

After installation:
- **Aider** (and other OpenAI-compatible tools) connect to remote Ollama automatically
- **Claude Code** can optionally use remote Ollama backend (alternative to Anthropic cloud)
- Zero manual configuration per session
- All API calls go through the secure Tailscale network
- Optional analytics and version management tools for Claude Code

## What This Does

1. Installs and configures Tailscale membership
2. Creates environment variables pointing to remote Ollama server
3. Installs Aider with automatic Ollama connection
4. Optionally configures Claude Code to use remote Ollama backend (user consent required)
5. Provides analytics tools for measuring performance
6. Provides version compatibility management for Claude Code + Ollama
7. Provides clean uninstallation

## Quick Reference

### Aider (v1)

| Operation | Command | Description |
|-----------|---------|-------------|
| **Start Aider** | `aider` | Launch Aider in interactive mode |
| | `aider --yes` | Launch Aider in YOLO mode (auto-accept changes) |

### Claude Code (v2+ - Optional)

| Operation | Command | Description |
|-----------|---------|-------------|
| **With cloud API** | `claude --model opus-4-6` | Use Anthropic cloud (default, recommended) |
| | `claude --model sonnet` | Use Sonnet 4.5 via cloud |
| **With remote Ollama** | `claude-ollama --model qwen3-coder` | Use remote Ollama backend (if alias configured) |
| **Version check** | `./scripts/check-compatibility.sh` | Verify Claude Code + Ollama compatibility |
| **Pin versions** | `./scripts/pin-versions.sh` | Lock to current known-working versions |
| **Rollback** | `./scripts/downgrade-claude.sh` | Downgrade Claude Code if update breaks |

### Configuration

| Operation | Command | Description |
|-----------|---------|-------------|
| **Check config** | `echo $OPENAI_API_BASE` | Display OpenAI API base URL (for Aider) |
| | `echo $ANTHROPIC_BASE_URL` | Display Anthropic API base (if Ollama backend configured) |
| | `cat ~/.ai-client/env` | View all environment variables |
| **Test connectivity** | `curl $OPENAI_API_BASE/models` | Test OpenAI API connection |
| | `tailscale status` | Check Tailscale connection status |

### Testing

| Operation | Command | Description |
|-----------|---------|-------------|
| **Run tests** | `./scripts/test.sh` | Run comprehensive test suite |
| | `./scripts/test.sh --skip-server` | Run tests without server connectivity checks |
| | `./scripts/test.sh --quick` | Run quick tests (skip model inference) |

### Shell Management

| Operation | Command | Description |
|-----------|---------|-------------|
| **Reload environment** | `source ~/.ai-client/env` | Reload environment variables in current shell |
| | `exec $SHELL` | Restart shell to apply environment changes |

## Claude Code Integration (v2+ - Optional)

### Backend Options

**Anthropic Cloud API** (default, recommended):
- Full model capabilities (Opus 4.6, Sonnet 4.5)
- Prompt caching support (critical for performance)
- Highest quality output
- Pay-per-use pricing

**Remote Ollama Backend** (optional, experimental):
- Privacy (all inference on private Tailscale network)
- No API costs
- Lower quality models (qwen3-coder, glm-4.7, etc.)
- No prompt caching (~2-3x slower on repeated contexts)
- Limited parallelism

### When to Use Which Backend

✅ **Use Anthropic Cloud (default)** for:
- Complex coding tasks
- Autonomous workflows
- Production work
- Tasks requiring high quality

✅ **Use Remote Ollama (optional)** for:
- Privacy-critical code
- Simple file edits
- Quick refactoring
- Development when server is accessible via Tailscale

### Setup

During installation, you'll be asked:
```
Optional: Claude Code + Ollama Integration

Create 'claude-ollama' shell alias? (y/N)
```

If you choose **yes**, you'll get a shell alias for easy switching:
```bash
claude --model opus-4-6            # Uses cloud (always)
claude-ollama --model qwen3-coder  # Uses remote Ollama
```

If you choose **no**, Claude Code will use Anthropic cloud API only (recommended for most users).

## Performance Analytics (v2+ - Optional)

Measure actual tool usage and performance to make informed decisions about backend suitability.

### Tools

- **`loop-with-analytics.sh`** - Enhanced execution with performance measurement
- **`compare-analytics.sh`** - Compare performance between different backends or configurations

### What Gets Measured

- Tool usage counts (Read, Bash, Edit, Write, Grep, Glob, Task spawns, etc.)
- Token usage (input, cache creation, cache reads, output)
- Cache efficiency (hit rate percentage)
- Workload classification (shallow vs deep operations)

### Example Output

```
═══════════════════════════════════════════════════════
   Iteration Analytics
═══════════════════════════════════════════════════════
Tool Usage:
  Read: 12 | Bash: 3 | Edit: 2 | Write: 1
  Grep: 5 | Glob: 8 | Subagents: 6 | Todo: 2

Token Usage:
  Input: 15,234 | Cache creation: 34,428 | Cache read: 13,697
  Output: 1,842 | Cache hit rate: 72%

Workload:
  Shallow ops: 25 | Deep ops: 3
  Ratio = 25:3
═══════════════════════════════════════════════════════
```

See `ANALYTICS_README.md` for complete guide.

## Version Management (v2+ - Optional)

Prevent breaking changes from tool updates.

### Tools

- **`check-compatibility.sh`** - Verify Claude Code and Ollama versions are tested together
- **`pin-versions.sh`** - Lock tools to known-working versions
- **`downgrade-claude.sh`** - Rollback Claude Code if update breaks

### Usage

```bash
# Before updating Claude Code
./client/scripts/check-compatibility.sh

# Pin current versions (recommended for production)
./client/scripts/pin-versions.sh

# If update breaks, rollback
./client/scripts/downgrade-claude.sh
```

### Why This Matters

Ollama's Anthropic API compatibility is experimental. Claude Code updates may require features Ollama doesn't support yet. Version management prevents downtime from breaking changes.
| **Uninstall** | `./scripts/uninstall.sh` | Remove client configuration and Aider |
| | `~/.ai-client/uninstall.sh` | Uninstall if installed via curl-pipe |

## Requirements

- macOS 14 Sonoma or later
- Homebrew
- Python 3.10+
- Tailscale account
- Access to a remote-ollama ai-server (must be invited to the same Tailscale network)

## Installation

See [SETUP.md](SETUP.md) for complete setup instructions.

Quick start:
```bash
./scripts/install.sh
```

## API Contract

The client relies on the exact API contract documented in [specs/API_CONTRACT.md](specs/API_CONTRACT.md).

The remote Ollama server provides:
- OpenAI-compatible `/v1` endpoints (native Ollama feature)
- Hostname resolution via Tailscale
- Support for streaming, JSON mode, tool calling
- No authentication required (network-layer security)

## Usage

The client has **no persistent daemon or background service**. It only configures environment variables that tools use to connect to remote Ollama.

### Running Aider

After installation, simply run:
```bash
aider                     # interactive mode
aider --yes               # YOLO mode
```

Aider automatically reads the environment variables and connects to remote Ollama.

### Using Other Tools

Any tool that supports custom OpenAI base URLs will work automatically:
```bash
# Environment variables are already set
echo $OPENAI_API_BASE    # http://ai-server:11434/v1
echo $OPENAI_API_KEY     # ollama
```

### No Service Management Required

Unlike the Ollama server, the client requires no start/stop/restart commands. Simply invoke tools when needed.

## Testing & Verification

### Running the Test Suite

The client includes a comprehensive automated test suite that verifies installation and connectivity:

```bash
# Run all tests (27 tests covering environment, dependencies, connectivity, API contract, and Aider)
./scripts/test.sh

# Run tests without server connectivity checks (useful during initial setup)
./scripts/test.sh --skip-server

# Run only critical tests (skip API contract validation and Aider integration)
./scripts/test.sh --quick

# Run with verbose output (shows full API request/response details and timing)
./scripts/test.sh --verbose
```

### Test Coverage

The test suite validates:
- **Environment Configuration** (7 tests): env file exists, all 4 variables set correctly, shell profile sourcing, variables exported
- **Dependencies** (6 tests): Tailscale connected, Homebrew installed, Python 3.10+, pipx installed, Aider installed
- **Connectivity** (6 tests): Server reachable, all API endpoints responding, error handling
- **API Contract** (5 tests): Base URL formats, HTTP status codes, response schemas, streaming with usage data
- **Aider Integration** (3 tests): Binary in PATH, environment variables configured
- **Script Behavior** (3 tests): Uninstall script available, valid syntax, install idempotency

### Sample Output

```
remote-ollama ai-client Test Suite
Running 28 tests

=== Environment Configuration Tests ===
✓ PASS Environment file exists (~/.ai-client/env)
✓ PASS OLLAMA_API_BASE is set: http://remote-ollama:11434
✓ PASS OPENAI_API_BASE is set: http://remote-ollama:11434/v1
✓ PASS OPENAI_API_KEY is set correctly: ollama
• SKIP AIDER_MODEL is not set (optional)
✓ PASS Shell profile sources env file (/Users/vm/.zshrc)
✓ PASS Environment variables are exported in env file

=== Dependency Tests ===
✓ PASS Tailscale is installed
✓ PASS Tailscale is connected (IP: 100.100.246.47)
✓ PASS Homebrew is installed
✓ PASS Python 3.14 found (>= 3.10)
✓ PASS pipx is installed
✓ PASS Aider is installed: aider 0.86.1

=== Connectivity Tests ===
✓ PASS Server is reachable (remote-ollama)
✓ PASS GET /v1/models returns valid JSON (1 models)

...

Test Summary
───────────────────────────────
Passed:  27
Failed:  0
Skipped: 2
Total:   29
═══════════════════════════════

✓ All tests passed!
```

All 27 tests passed on hardware testing (2026-02-10 on vm@macos with Aider 0.86.1, Python 3.14).

## Uninstallation

```bash
./scripts/uninstall.sh
```

This removes:
- Aider installation
- Environment variable configuration
- Shell profile modifications

Tailscale and Homebrew are left untouched.

## Documentation

- [SETUP.md](SETUP.md) – Complete setup instructions
- [specs/API_CONTRACT.md](specs/API_CONTRACT.md) – Exact server API interface
- [specs/ARCHITECTURE.md](specs/ARCHITECTURE.md) – Client architecture
- [specs/FUNCTIONALITIES.md](specs/FUNCTIONALITIES.md) – Client functionalities
- [specs/REQUIREMENTS.md](specs/REQUIREMENTS.md) – System requirements
- [specs/SCRIPTS.md](specs/SCRIPTS.md) – Script documentation
- [specs/FILES.md](specs/FILES.md) – Repository layout

## Out of Scope (v1)

- Direct HTTP API calls (use Aider or other tools)
- Linux/Windows support
- IDE plugins
- Custom authentication
