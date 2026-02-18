#!/bin/bash
set -euo pipefail

# self-sovereign-ollama ai-server install script (v2)
# Automates the setup of Ollama with WireGuard VPN via OpenWrt router
# Source: server/specs/* and server/SETUP.md

# Suppress Homebrew noise
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

fatal() {
    error "$1"
    exit 1
}

section_break() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

important_section() {
    echo ""
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║  $(printf "%-60s" "$1")  ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Banner
echo "================================================"
echo "  self-sovereign-ollama ai-server Installation"
echo "================================================"
echo ""

# Step 1: Detect macOS + Apple Silicon
info "Checking system requirements..."
if [[ "$(uname)" != "Darwin" ]]; then
    fatal "This script requires macOS. Detected: $(uname)"
fi

MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 14 ]]; then
    fatal "This script requires macOS 14 (Sonoma) or later. Detected: $MACOS_VERSION"
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
    fatal "This script requires Apple Silicon (arm64). Detected: $ARCH"
fi

# Validate shell (zsh or bash)
USER_SHELL=$(basename "$SHELL")
if [[ "$USER_SHELL" != "zsh" && "$USER_SHELL" != "bash" ]]; then
    fatal "This script requires zsh or bash shell. Detected: $USER_SHELL"
fi

info "✓ macOS $MACOS_VERSION with Apple Silicon detected"
info "✓ Shell: $USER_SHELL"

# Step 2: Check for Homebrew
info "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    warn "Homebrew not found"
    echo "Please install Homebrew from https://brew.sh and re-run this script"
    fatal "Homebrew is required"
fi
info "✓ Homebrew found: $(brew --version | head -n1)"

# Step 3: Router Setup Prerequisites
echo ""
echo "=== Router and Network Configuration Prerequisites ==="
echo ""
warn "Before proceeding, ensure your OpenWrt router is configured:"
echo "  1. WireGuard VPN server running (see server/NETWORK_DOCUMENTATION.md)"
echo "  2. LAN network configured (example: 192.168.250.0/24)"
echo "  3. Firewall rules in place (VPN → AI server port 11434)"
echo ""
read -r -p "Have you completed router setup? (y/N): " REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error "Router setup is required before installing the server"
    info "See server/NETWORK_DOCUMENTATION.md for detailed instructions"
    exit 1
fi
info "✓ Router prerequisites confirmed"

# Step 4: LAN Network Configuration
echo ""
echo "=== Step 4: LAN Network Configuration ==="
echo ""

# Prompt for server static IP
info "Enter the static IP you will assign to this server (default: 192.168.250.20)"
read -p "Server IP: " SERVER_IP
SERVER_IP=${SERVER_IP:-192.168.250.20}

# Validate IP format
if ! echo "$SERVER_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    error "Invalid IP address format: $SERVER_IP"
    exit 1
fi

GATEWAY="$(echo "$SERVER_IP" | cut -d. -f1-3).1"

# Instructions for manual static IP configuration
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Configure Static IP in macOS System Settings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Open System Settings → Network"
echo "  2. Select your Ethernet interface → click Details..."
echo "  3. Go to the TCP/IP tab"
echo "  4. Set 'Configure IPv4' to Manually"
echo "  5. Enter:"
echo ""
echo "       IP Address:  $SERVER_IP"
echo "       Subnet Mask: 255.255.255.0"
echo "       Router:      $GATEWAY"
echo ""
echo "  6. Go to the DNS tab, add:"
echo ""
echo "       $GATEWAY"
echo "       8.8.8.8"
echo ""
echo "  7. Click OK → Apply"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Press Enter when done..." < /dev/tty
echo ""

# Verify router connectivity
info "Testing router gateway connectivity..."
if ping -c 3 "$GATEWAY" &> /dev/null; then
    info "✓ Router gateway ($GATEWAY) is reachable"
else
    error "Router gateway ($GATEWAY) is not reachable"
    error "Check ethernet connection and router configuration"
    exit 1
fi

# Step 5: Check/install Ollama
info "Checking for Ollama..."
if ! command -v ollama &> /dev/null; then
    info "Installing Ollama via Homebrew (this may take a minute)..."
    brew install ollama > /tmp/ollama-install.log 2>&1 || fatal "Failed to install Ollama"
fi
OLLAMA_VERSION=$(ollama --version 2>/dev/null | head -n1 || echo 'version unknown')
info "✓ Ollama installed: $OLLAMA_VERSION"

# Step 6: Validate Ollama binary path
info "Validating Ollama binary path..."
OLLAMA_PATH=""
if [[ -x "/opt/homebrew/bin/ollama" ]]; then
    OLLAMA_PATH="/opt/homebrew/bin/ollama"
elif command -v ollama &> /dev/null; then
    OLLAMA_PATH="$(which ollama)"
else
    fatal "Could not locate ollama binary"
fi
info "✓ Ollama binary: $OLLAMA_PATH"

# Step 7: Stop any existing Ollama services
info "Stopping any existing Ollama services..."
# Try to stop brew services version
if brew services list | grep -q ollama; then
    brew services stop ollama 2>/dev/null || true
fi

# Try to bootout existing launchd agent
LAUNCHD_DOMAIN="gui/$(id -u)"
LAUNCHD_LABEL="com.ollama"
launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" 2>/dev/null || true
sleep 2
info "✓ Existing services stopped"

# Step 8: Configure Ollama Binding
echo ""
echo "=== Step 8: Ollama Binding Configuration ==="
echo ""
echo "Choose how Ollama should bind:"
echo "  1. dedicated LAN IP only ($SERVER_IP) - More secure, DMZ-only access"
echo "  2. All interfaces (0.0.0.0) - Required for localhost testing"
echo ""
read -p "Select binding mode (1/2, default=1): " BINDING_CHOICE
BINDING_CHOICE=${BINDING_CHOICE:-1}

if [[ "$BINDING_CHOICE" == "2" ]]; then
    OLLAMA_HOST="0.0.0.0"
    info "Ollama will bind to all interfaces (0.0.0.0)"
else
    OLLAMA_HOST="$SERVER_IP"
    info "Ollama will bind to dedicated LAN IP ($SERVER_IP)"
fi

# Step 9: Create LaunchAgent plist
PLIST_PATH="$HOME/Library/LaunchAgents/com.ollama.plist"
info "Creating LaunchAgent plist at $PLIST_PATH..."
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>$OLLAMA_PATH</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>$OLLAMA_HOST</string>
        <!-- Optional CORS configuration (uncomment if needed):
        <key>OLLAMA_ORIGINS</key>
        <string>*</string>
        -->
    </dict>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ollama.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ollama.stderr.log</string>
</dict>
</plist>
EOF

info "✓ LaunchAgent plist created"

# Step 10: Load the LaunchAgent
info "Loading Ollama LaunchAgent..."
launchctl bootstrap "$LAUNCHD_DOMAIN" "$PLIST_PATH" || fatal "Failed to load LaunchAgent"
sleep 3
info "✓ LaunchAgent loaded"

# Step 11: Verify service binding
echo ""
info "Verifying service binding..."
sleep 3  # Give service time to bind

if lsof -i :11434 -sTCP:LISTEN &> /dev/null; then
    BINDING=$(lsof -i :11434 -sTCP:LISTEN 2>/dev/null | grep ollama | awk '{print $9}')
    if echo "$BINDING" | grep -q "$SERVER_IP"; then
        info "✓ Ollama bound to dedicated LAN IP ($SERVER_IP:11434)"
    elif echo "$BINDING" | grep -q "0.0.0.0"; then
        info "✓ Ollama bound to all interfaces (0.0.0.0:11434)"
    else
        warn "Ollama binding: $BINDING (unexpected)"
    fi
else
    error "Ollama is not listening on port 11434"
    exit 1
fi

# Step 12: Verify Ollama is responding
info "Verifying Ollama API is responding..."
RETRY_COUNT=0
MAX_RETRIES=15
OLLAMA_READY=false

# Use SERVER_IP for testing (works for both binding modes)
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -sf "http://${SERVER_IP}:11434/v1/models" &> /dev/null; then
        OLLAMA_READY=true
        break
    fi
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [[ "$OLLAMA_READY" == "true" ]]; then
    info "✓ Ollama is responding on port 11434"
else
    fatal "Ollama did not respond after 30 seconds. Check logs: /tmp/ollama.stderr.log"
fi

# Step 13: Verify process ownership (must not be root)
info "Verifying Ollama is running as user (not root)..."
OLLAMA_PID=$(pgrep -f "ollama serve" | head -n1)
if [[ -n "$OLLAMA_PID" ]]; then
    OLLAMA_USER=$(ps -o user= -p "$OLLAMA_PID")
    if [[ "$OLLAMA_USER" == "root" ]]; then
        fatal "Security violation: Ollama is running as root. This is not allowed."
    fi
    info "✓ Ollama running as user: $OLLAMA_USER (PID: $OLLAMA_PID)"
else
    warn "Could not verify Ollama process ownership"
fi

# Step 14: Self-test API endpoint
info "Running self-test on API endpoint..."
TEST_RESPONSE=$(curl -sf "http://${SERVER_IP}:11434/v1/models" 2>/dev/null || echo "FAILED")
if [[ "$TEST_RESPONSE" == "FAILED" ]] || ! echo "$TEST_RESPONSE" | grep -q "object"; then
    fatal "Self-test failed: /v1/models did not return valid JSON"
fi
info "✓ Self-test passed: /v1/models returned valid response"


# Step 15: Optional Model Pre-Pull
echo ""
echo "=== Step 15: Optional Model Pre-Pull ==="
echo ""
info "Would you like to pre-pull models now?"
echo "  This is optional but recommended for production deployments."
echo "  Examples: qwen2.5-coder:32b, deepseek-r1:70b, llama3.2-vision:90b"
echo ""
read -r -p "Pre-pull models? (y/N): " REPLY

if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter model names (space-separated): " MODELS
    if [[ -n "$MODELS" ]]; then
        info "Pulling models..."
        for MODEL in $MODELS; do
            info "Pulling $MODEL..."
            if ollama pull "$MODEL"; then
                info "✓ Pulled: $MODEL"
            else
                warn "Failed to pull: $MODEL (continuing anyway)"
            fi
        done
    fi
else
    info "Skipping model pre-pull (you can pull later)"
fi

# Final summary
echo ""
echo ""
echo "┌────────────────────────────────────────────────────┐"
echo "│        Installation Complete! (v2.0.0)             │"
echo "└────────────────────────────────────────────────────┘"
echo ""
info "✓ ai-server is running and configured"
echo ""
echo "Configuration:"
echo "  • Server IP: $SERVER_IP"
echo "  • Port: 11434"
echo "  • Ollama bound to: $OLLAMA_HOST"
echo "  • LaunchAgent: Loaded and running"
echo "  • Auto-start: Enabled (survives reboots)"
echo ""
echo "Router Status:"
echo "  • Gateway: $GATEWAY (reachable)"
echo "  • WireGuard VPN: Configured (per NETWORK_DOCUMENTATION.md)"
echo "  • Firewall: VPN → AI server port 11434 allowed"
echo ""
echo "What's Next:"
echo "  1. Add VPN clients on router (see server/NETWORK_DOCUMENTATION.md)"
echo "  2. Test from client: curl http://$SERVER_IP:11434/v1/models"
echo "  3. Run comprehensive tests: cd server/scripts && ./test.sh --verbose"
echo "  4. Check logs: tail -f /tmp/ollama.stderr.log"
echo ""
echo "Troubleshooting:"
echo "  • Check service: launchctl list | grep ollama"
echo "  • Verify binding: lsof -i :11434"
echo "  • Test locally: curl http://$SERVER_IP:11434/v1/models"
echo "  • Router SSH: ssh root@$GATEWAY"
echo ""
