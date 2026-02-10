# private-ai-server Scripts

## scripts/install.sh

- Validates macOS + Apple Silicon hardware requirements
- Checks / installs Homebrew
- Checks / installs Tailscale (opens GUI app for login + device approval)
- Checks / installs Ollama via Homebrew
- Stops any existing Ollama service (brew services or launchd) to avoid conflicts
- Creates `~/Library/LaunchAgents/com.ollama.plist` to run Ollama as user-level service
  - Sets `OLLAMA_HOST=0.0.0.0` to bind all network interfaces
  - Configures `KeepAlive=true` and `RunAtLoad=true` for automatic startup
  - Logs to `/tmp/ollama.stdout.log` and `/tmp/ollama.stderr.log`
- Loads the plist via `launchctl bootstrap` (modern API)
- Verifies Ollama is listening on port 11434 (retry loop with timeout)
- Prompts user to set Tailscale machine name (default: `private-ai-server`)
- Prints Tailscale ACL JSON snippet for user to apply in admin console
- Runs self-test: `curl -sf http://localhost:11434/v1/models`
- Idempotent: safe to re-run without breaking existing setup

## scripts/uninstall.sh

- Stops the Ollama LaunchAgent service via `launchctl bootout`
- Removes `~/Library/LaunchAgents/com.ollama.plist`
- Optionally cleans up Ollama logs from `/tmp/` (`ollama.stdout.log`, `ollama.stderr.log`)
- Leaves Homebrew, Tailscale, and Ollama binary untouched (user may want to keep them)
- Leaves downloaded models in `~/.ollama/models/` untouched (valuable data)
- Provides clear summary of what was removed and what remains
- Handles edge cases gracefully (service not running, plist missing, partial installation)

## scripts/warm-models.sh

- Accepts model names as command-line arguments (e.g., `qwen2.5-coder:32b deepseek-r1:70b`)
- Verifies Ollama is running before proceeding
- For each model:
  - Pulls the model via `ollama pull <model>` (downloads if not present)
  - Sends lightweight `/v1/chat/completions` request to force-load into memory
    - Uses minimal prompt ("hi") with `max_tokens: 1`
- Reports progress per model (pulling, loading, ready, failed)
- Continues on individual model failures; prints summary at end
- Includes comments documenting how to wire into launchd as post-boot warmup (optional)

## No config files

Server requires no configuration files. All settings are managed via:
- Environment variables in the launchd plist (`OLLAMA_HOST=0.0.0.0`)
- Ollama's built-in configuration system
- Tailscale ACLs (managed via Tailscale admin console)
