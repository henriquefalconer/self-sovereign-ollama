# remote-ollama-proxy ai-server Scripts

## scripts/install.sh

### System Validation
- Validates macOS 14+ (Sonoma) and Apple Silicon hardware requirements
- Checks / installs Homebrew

### Homebrew Configuration
- Suppresses Homebrew noise: `HOMEBREW_NO_ENV_HINTS=1`, `HOMEBREW_NO_INSTALL_CLEANUP=1`
- Redirects verbose installation output to `/tmp/*.log` files for cleaner UX

### Tailscale Installation & Setup
- Installs Tailscale GUI app via `brew install --cask tailscale`
- Installs Tailscale CLI tools via `brew install tailscale` (required for connection detection)
- Warns user about sudo password prompt before installation
- Opens Tailscale GUI app for first-time setup
- Provides comprehensive first-time setup instructions:
  - System Extension permission (required)
  - Notifications permission (recommended)
  - "Start on login" option (recommended - ensures reconnection after reboot)
  - VPN activation in System Settings if needed
  - Browser authentication with account creation
  - Survey form (can be skipped)
  - Introduction/tutorial (can be skipped)
- Interactive connection flow: user presses Enter when ready (no timeout pressure)
- Intelligent connection detection via `tailscale status` and `tailscale ip -4`
- Context-specific troubleshooting tips if connection fails

### Ollama Installation & Configuration
- Checks / installs Ollama via Homebrew (output redirected to log)
- Stops any existing Ollama service (brew services or launchd) to avoid conflicts
- Creates `~/Library/LaunchAgents/com.ollama.plist` to run Ollama as user-level service
  - Sets `OLLAMA_HOST=127.0.0.1` to bind loopback interface only
  - Configures `KeepAlive=true` and `RunAtLoad=true` for automatic startup
  - Logs to `/tmp/ollama.stdout.log` and `/tmp/ollama.stderr.log`
- Loads the plist via `launchctl bootstrap` (modern API)
- Verifies Ollama is listening on port 11434 (retry loop with timeout)
- Verifies process is running as user (not root)
- Runs self-test: `curl -sf http://localhost:11434/v1/models`

### HAProxy Installation & Configuration (Optional)
- **User consent prompt**: "Install HAProxy proxy? (Y/n)"
  - Explains benefits: endpoint allowlisting, defense in depth, single choke point
  - Explains tradeoffs: additional service, minimal latency overhead (<1ms)
  - Default: Yes
- If user accepts:
  - Checks / installs HAProxy via Homebrew: `brew install haproxy`
  - Suppresses Homebrew noise (consistent with Ollama installation)
  - Redirects installation output to `/tmp/haproxy-install.log`
  - Creates `~/.haproxy/` directory for configuration
  - Generates `~/.haproxy/haproxy.cfg` with:
    - Frontend listening on Tailscale interface (`100.x.x.x:11434` via `tailscale ip -4`)
    - Backend forwarding to Ollama on loopback (`127.0.0.1:11434`)
    - Endpoint allowlist (OpenAI + Anthropic + Ollama metadata APIs)
    - Default deny for all other paths
  - Creates `~/Library/LaunchAgents/com.haproxy.plist` with:
    - `ProgramArguments`: `/opt/homebrew/bin/haproxy -f ~/.haproxy/haproxy.cfg`
    - `RunAtLoad=true` and `KeepAlive=true`
    - `StandardOutPath=/tmp/haproxy.stdout.log`
    - `StandardErrorPath=/tmp/haproxy.stderr.log`
  - Loads HAProxy service via `launchctl bootstrap`
  - Verifies HAProxy is listening on Tailscale interface
  - Verifies proxy forwarding works (test request through proxy)
- If user declines:
  - Updates Ollama plist to use `OLLAMA_HOST=0.0.0.0` (fallback mode)
  - Displays warning about reduced security posture
  - Continues installation (functional but less secure)

### Tailscale Configuration Instructions
- Displays clear, boxed sections for each configuration step
- **Step 1: Machine Name**
  - Provides direct link to Tailscale machines page
  - Shows current Tailscale IP for easy identification
  - Recommends machine name: `remote-ollama-proxy`
- **Step 2: ACL Configuration**
  - Instructs user to click "JSON editor" button first (critical step)
  - Provides complete ACL JSON snippet with tags
  - **Step 3: Tag Instructions** with explicit steps:
    - Navigate to machines page
    - Find machine by IP
    - Click three dots menu → "Edit ACL tags..."
    - Add tag in Tags field
    - Save changes
- **Step 3: Optional Model Pre-pull**
  - Shows popular model examples (qwen2.5-coder:32b, deepseek-r1:70b, llama3.2)

### Final Summary
- Visual hierarchy with boxed "Installation Complete" message
- Shows service status (Ollama running, Tailscale connected, auto-start enabled)
- **What's Next** section with numbered steps:
  1. Complete Tailscale configuration (3 steps above)
  2. Install client on laptop/desktop (provides curl-pipe command)
  3. Test connection from client
- Troubleshooting commands section (restart Ollama, view logs)

### Design Principles
- Idempotent: safe to re-run without breaking existing setup
- User-friendly: minimal noise, clear visual hierarchy, actionable instructions
- Interactive: user controls pacing (press Enter when ready)
- Informative: context-specific error messages and troubleshooting tips
- Complete: guides user through entire workflow including client installation

## scripts/uninstall.sh

### Functionality
- Stops the Ollama LaunchAgent service via `launchctl bootout`
- Removes `~/Library/LaunchAgents/com.ollama.plist`
- Cleans up Ollama logs from `/tmp/` (`ollama.stdout.log`, `ollama.stderr.log`)
- **HAProxy cleanup** (if installed):
  - Stops HAProxy LaunchAgent service via `launchctl bootout`
  - Removes `~/Library/LaunchAgents/com.haproxy.plist`
  - Deletes `~/.haproxy/` directory
  - Cleans up HAProxy logs from `/tmp/` (`haproxy.stdout.log`, `haproxy.stderr.log`)
  - Handles gracefully if HAProxy was never installed
- Leaves Homebrew, Tailscale, HAProxy binary, and Ollama binary untouched (user may want to keep them)
- Leaves downloaded models in `~/.ollama/models/` untouched (valuable data)
- Handles edge cases gracefully (service not running, plist missing, partial installation)

### UX Requirements
- **Clear banner** - Display script name and purpose at start
- **Color-coded output** - Use echo -e with GREEN/YELLOW/RED for info/warn/error messages
- **Progress tracking** - Show what's being removed at each step
- **Final summary** - Display boxed or clearly separated summary section showing:
  - What was successfully removed
  - What was left intact (Homebrew, Tailscale, Ollama binary, models)
  - Any errors or warnings encountered
- **Graceful degradation** - Continue with remaining cleanup even if some steps fail
- **Idempotent** - Safe to re-run on already-cleaned system (no errors on missing files)

## scripts/warm-models.sh

### Functionality
- Accepts model names as command-line arguments (e.g., `qwen2.5-coder:32b deepseek-r1:70b`)
- Shows usage message if no models specified
- Verifies Ollama is running before proceeding (fail fast with clear error if not)
- For each model:
  - Pulls the model via `ollama pull <model>` (downloads if not present)
  - Sends lightweight `/v1/chat/completions` request to force-load into memory
    - Uses minimal prompt ("hi") with `max_tokens: 1`
- Continues on individual model failures (resilient)
- Includes comments documenting how to wire into launchd as post-boot warmup (optional)

### UX Requirements
- **Clear usage** - Show usage message with examples if invoked without arguments
- **Color-coded output** - Use echo -e with GREEN/YELLOW/RED for status messages
- **Progress per model** - Show clear status for each model:
  - "Pulling model..." (if download needed)
  - "Loading into memory..." (warm-up request)
  - "✓ Ready" (success) or "✗ Failed: <reason>" (error)
- **Progress indicators** - Show what's happening during long operations (pulling large models)
- **Final summary** - Display results at end:
  - Count of models successfully warmed
  - Count of models that failed (if any)
  - List of failed models with brief reason
- **Continue on failure** - Don't abort entire script if one model fails
- **Time estimates** - Optionally show estimated time remaining for large downloads

## scripts/test.sh

Comprehensive test script that validates all server functionality. Designed to run on the server machine after installation.

### Service Status Tests
- Verify LaunchAgent is loaded (`launchctl list | grep com.ollama`)
- Verify Ollama process is running as user (not root)
- Verify Ollama is listening on port 11434
- Verify service responds to basic HTTP requests

### API Endpoint Tests (OpenAI-Compatible)
- `GET /v1/models` - returns JSON model list
- `GET /v1/models/{model}` - returns single model details (requires at least one pulled model)
- `POST /v1/chat/completions` - non-streaming request succeeds
- `POST /v1/chat/completions` - streaming (`stream: true`) returns SSE chunks
- `POST /v1/chat/completions` - with `stream_options.include_usage` returns usage data
- `POST /v1/chat/completions` - JSON mode (`response_format: {"type": "json_object"}`)
- `POST /v1/responses` - experimental endpoint (note if requires Ollama 0.5.0+)

### API Endpoint Tests (Anthropic-Compatible, v2+)

These tests validate the Anthropic Messages API endpoint (`/v1/messages`) introduced in Ollama 0.5.0+. If Ollama version is < 0.5.0, these tests should be skipped with appropriate messaging.

- `POST /v1/messages` - non-streaming request succeeds with text content
  - Verify response has required fields: `id`, `type: "message"`, `role: "assistant"`, `content` (array), `stop_reason`, `usage`
  - Verify `content[0].type: "text"` and `content[0].text` is a non-empty string
  - Verify `usage` has `input_tokens` and `output_tokens`
- `POST /v1/messages` - streaming request returns correct SSE event sequence
  - Verify event sequence: `message_start` → `content_block_start` → `content_block_delta` (multiple) → `content_block_stop` → `message_delta` → `message_stop`
  - Verify `message_start` event has `message` with `id`, `type`, `role`, `content` (empty array initially), `usage`
  - Verify `content_block_delta` events have `delta.text` with incremental text
  - Verify final `message_stop` event completes the stream
- `POST /v1/messages` - with system prompt
  - Verify system prompt is processed (request includes `system: "You are a helpful assistant"` or system array)
  - Verify response acknowledges or respects system instructions (implementation-dependent, may just verify 200 OK)
- `POST /v1/messages` - error case with nonexistent model
  - Verify appropriate error status (400, 404, or 500)
  - Verify error response has meaningful error message
- `POST /v1/messages` - tool use (optional/skippable, model-dependent)
  - If model supports tools, verify `tools` parameter is accepted
  - Verify `tool_use` content blocks are returned when appropriate
  - Mark as SKIP if model doesn't support tools
- `POST /v1/messages` - thinking blocks (optional/skippable, model-dependent)
  - If model supports thinking, verify `thinking` content blocks are returned
  - Mark as SKIP if model doesn't support thinking

**Flag Support**:
- Add `--skip-anthropic-tests` flag to skip all Anthropic API tests (for environments with Ollama < 0.5.0)
- If `--skip-anthropic-tests` is not provided but Ollama version < 0.5.0 is detected, auto-skip with message: "Anthropic API tests skipped (requires Ollama 0.5.0+, detected X.Y.Z)"

**Total Test Count**: Update `TOTAL_TESTS` variable to include these new tests (current: 20, add ~5-6 non-optional Anthropic tests = ~25-26 total)

### Error Behavior Tests
- 500 error on inference with nonexistent model
- Appropriate error responses for malformed requests

### Security Tests
- Verify Ollama process owner is current user (not root)
- Verify log files exist and are readable (`/tmp/ollama.stdout.log`, `/tmp/ollama.stderr.log`)
- Verify plist file exists at `~/Library/LaunchAgents/com.ollama.plist`
- Verify `OLLAMA_HOST=127.0.0.1` is set in plist environment variables (loopback-only binding)

### Network Tests
- Verify Ollama service binds to loopback interface only (127.0.0.1:11434)
  - Use `lsof -i :11434` to check binding
  - FAIL if service binds to 0.0.0.0 (security violation)
- Test local access via localhost (should succeed)
- Test direct Ollama access from Tailscale IP (should fail if HAProxy installed, succeed otherwise)
- Note: Testing from unauthorized client requires separate client-side test

### HAProxy Tests (skip gracefully if HAProxy not installed)
- Verify HAProxy LaunchAgent is loaded (`launchctl list | grep com.haproxy`)
- Verify HAProxy process is running as user (not root)
- Verify HAProxy is listening on Tailscale interface (`100.x.x.x:11434`)
- Test allowlisted endpoint forwarding:
  - `POST /v1/chat/completions` (should succeed - OpenAI API)
  - `POST /v1/messages` (should succeed - Anthropic API)
  - `GET /v1/models` (should succeed - OpenAI API)
  - `GET /api/version` (should succeed - Ollama metadata)
- Test blocked endpoint enforcement:
  - `POST /api/generate` (should fail - not in allowlist)
  - `POST /api/pull` (should fail - not in allowlist)
  - `DELETE /api/delete` (should fail - not in allowlist)
  - Expected: 403 Forbidden or 404 Not Found
- Verify direct Ollama access from Tailscale IP is blocked:
  - Attempt to connect to Ollama on loopback from Tailscale IP
  - Expected: Connection refused or timeout (kernel-enforced isolation)
- Verify HAProxy logs exist and are readable (`/tmp/haproxy.stdout.log`, `/tmp/haproxy.stderr.log`)
- Verify HAProxy config exists at `~/.haproxy/haproxy.cfg`

**Expected test count**: ~33-34 tests (up from 26 after adding HAProxy tests)

### Output Format
- **Per-test results** - Clear pass/fail/skip for each test with brief description
- **Summary statistics** - Final count (X passed, Y failed, Z skipped)
- **Exit codes** - 0 if all tests pass, non-zero otherwise
- **Verbose mode** - `--verbose` or `-v` flag for detailed output (request/response bodies, timing)
- **Colorized output** - Use echo -e with color codes:
  - GREEN for passed tests
  - RED for failed tests
  - YELLOW for skipped tests
- **Progress indication** - Show test number / total (e.g., "Running test 5/20...")
- **Grouped results** - Organize output by test category (Service Status, API Endpoints, Security, Network)

### UX Requirements
- **Clear banner** - Display script name, purpose, and test count at start
- **Real-time feedback** - Show results as tests run (don't wait until end)
- **Minimal noise** - Suppress verbose curl output unless --verbose flag used
- **Helpful failures** - When test fails, show:
  - What was expected
  - What was received
  - Suggested troubleshooting steps
- **Skip guidance** - If tests are skipped, explain why and how to enable them
- **Final summary box** - Visually separated summary section with:
  - Overall pass/fail status
  - Statistics
  - Next steps if failures occurred

### Test Requirements
- Requires at least one model pulled for model-specific tests
- Can run with `--skip-model-tests` flag if no models available
- Non-destructive: does not modify server state (read-only API calls)

## Configuration files

Server configuration is minimal and managed via:
- Environment variables in the Ollama launchd plist (`OLLAMA_HOST=127.0.0.1`)
- HAProxy configuration file at `~/.haproxy/haproxy.cfg` (if HAProxy installed)
  - Frontend binding to Tailscale interface
  - Backend forwarding to Ollama on loopback
  - Endpoint allowlist with default deny
- Ollama's built-in configuration system
- Tailscale ACLs (managed via Tailscale admin console)
