# Network Setup Documentation (v2.0.0)

**Important: This is reference documentation, not a requirement**

This file documents the specific network configuration I set up for my Ollama server. **The network setup is essentially a separate project** from the Ollama server configuration documented in the rest of this repository.

**What this document contains:**
- Documentation of my specific network infrastructure (OpenWrt + WireGuard + firewall)
- Provided as reference material to help others who want to implement something similar
- Not required to use the Ollama server setup - this is just one possible approach

**Your network setup will likely differ:**
- You may already have a VPN solution (Tailscale, WireGuard Cloud, etc.)
- You may use a reverse proxy (Cloudflare Tunnel, ngrok, etc.)
- You may use direct port forwarding or SSH tunneling
- Any method that provides network connectivity to your Ollama server will work

**If you want to replicate my setup**, the instructions below document exactly what I configured. If you're using a different approach, you can skip this file entirely and just ensure your clients can reach your server's port 11434.

---

## Context: My Specific Setup

I already had an ISP router providing internet connectivity to my home network, so I added an OpenWrt router behind it to create a self-sovereign VPN solution for secure remote access to my AI server.

**My network topology:**
- **ISP Router** (upstream): 192.168.2.0/24 network
  - ISP router at 192.168.2.1
  - OpenWrt router WAN interface at 192.168.2.90
- **OpenWrt Router** (my managed network): 192.168.250.0/24 network
  - OpenWrt router LAN interface at 192.168.250.1
  - AI server at 192.168.250.20 (isolated via firewall)
- **WireGuard VPN**: 10.10.10.0/24 network
  - VPN server at 10.10.10.1 (OpenWrt)
  - VPN clients at 10.10.10.2, 10.10.10.3, etc.

**Key architectural decision:**
- No separate physical DMZ interface - instead I use firewall rules to isolate the AI server
- Server lives on the same LAN subnet (192.168.250.0/24) but is isolated via firewall zones and rules
- This is simpler than creating VLANs but still provides strong isolation

---

## Prerequisites

- OpenWrt-compatible router hardware
- OpenWrt 23.05 LTS or later installed
- Physical wired network connection to router (no Wi-Fi for administration)
- Basic understanding of networking concepts (IP addresses, subnets, firewall rules)

**Note**: This guide assumes OpenWrt is already installed on your router. For router-specific installation instructions, see [OpenWrt Table of Hardware](https://openwrt.org/toh/start).

---

## My Network Architecture

```
Internet
   ↓
ISP Router (192.168.2.1)
   ↓
WAN (eth1) - 192.168.2.90 (DHCP from ISP router)
   ↓
OpenWrt Router (192.168.250.1)
   ├─ LAN (br-lan) - 192.168.250.0/24 (general devices + isolated AI server)
   └─ VPN (wg0) - 10.10.10.0/24 (VPN clients)

AI Server: 192.168.250.20 (isolated via firewall)

Firewall zones:
- wan → all: deny (except WireGuard UDP)
- vpn → lan (AI server): allow (port 11434 only to 192.168.250.20)
- vpn → lan (other): deny
- vpn → wan: deny
- lan (AI server) → lan (other): deny
- lan (AI server) → wan: allow (outbound internet for updates)
- lan (admin) → lan (AI server): allow (optional admin access)
```

---

## Understanding Network Segmentation and Router Access

**Critical concept**: The OpenWrt router creates **two separate network segments**:

1. **Upstream side (WAN)**: 192.168.2.0/24 - ISP router's network
2. **Downstream side (LAN)**: 192.168.250.0/24 - OpenWrt managed network

These networks are **isolated from each other** - devices on one network cannot directly reach IPs on the other network without explicit routing rules.

**What this means for router administration:**

| Your Location | Which Router IP Works | Why |
|--------------|----------------------|-----|
| ISP router's network (192.168.2.x) | `192.168.2.90` (WAN) ✅ | You're on the same network as the WAN interface |
| ISP router's network (192.168.2.x) | `192.168.250.1` (LAN) ❌ | Different network segment, no routing |
| Directly connected to OpenWrt LAN port | `192.168.250.1` (LAN) ✅ | You're on the LAN network |
| Directly connected to OpenWrt LAN port | `192.168.2.90` (WAN) ✅ | Router can bridge between its own interfaces |
| VPN client (10.10.10.x) | Depends on firewall rules | Would need explicit rule (not configured by default) |

**For most administration tasks** when working from your home WiFi/Ethernet, use: `ssh root@192.168.2.90`

---

## Phase 1: Local Network Testing (No ISP Port Forwarding)

In this phase, I configured the basic infrastructure for local testing before exposing the VPN to the internet.

### Part 1: Initial Router Access

**Understanding Router Access Points:**

The OpenWrt router has two network interfaces that you can use for administration:
- **LAN interface** (192.168.250.1 after configuration) - Only accessible from devices connected to the router's LAN ports
- **WAN interface** (192.168.2.90 in my setup) - Accessible from the ISP router's network (192.168.2.0/24)

**Important**: Since the router sits behind the ISP router, **you cannot access the LAN interface (192.168.250.1) from your regular home network** (192.168.2.x). You have two options:

#### Option A: Access via WAN Interface (From ISP Network)

**When to use**: When connected to your ISP router's network (WiFi or Ethernet at 192.168.2.x)

```bash
# Access router via its WAN IP (after initial setup)
ssh root@192.168.2.90

# Or via web browser:
# http://192.168.2.90
```

This is what you'll use for **administration from your normal home network**.

#### Option B: Access via LAN Interface (Physical Connection)

**When to use**: When physically connected to the OpenWrt router's LAN port

```bash
# Connect via Ethernet cable directly to OpenWrt LAN port
# Initially (factory default):
ssh root@192.168.1.1

# After changing LAN IP to 192.168.250.1:
ssh root@192.168.250.1
```

**For initial setup**, I recommend:
1. Connect laptop directly to OpenWrt LAN port via Ethernet
2. Access router at factory default: `ssh root@192.168.1.1`
3. After changing LAN IP, reconnect at: `ssh root@192.168.250.1`

**Default credentials:**
- Username: `root`
- Password: (blank or set during first setup)

**IMPORTANT**: Set a strong root password immediately:
```bash
passwd
```

#### Configure SSH Access

I configured SSH (Dropbear) to ensure secure remote access:

**Via LuCI Web Interface:**
1. Navigate to **System → Administration**
2. Under **SSH Access** (Dropbear Instance):
   - **Enable Instance**: ☑ (checked)
   - **Interface**: unspecified (listens on all interfaces)
   - **Port**: 22
   - **Password authentication**: ☑ (checked)
   - **Allow root logins with password**: ☑ (checked)
   - **Gateway Ports**: ◻ (unchecked)
3. Click **Save** and close

**Why these settings:**
- Enables SSH on both WAN (192.168.2.90) and LAN (192.168.250.1) interfaces
- Allows root login (needed for administration)
- Uses password authentication (alternative: key-based authentication is more secure)

#### Enable HTTPS for Web Interface

For secure admin access via web browser:

**Via LuCI Web Interface:**
1. Navigate to **System → Administration**
2. Under **HTTP(S) Access**:
   - Enable **Redirect to HTTPS**: ☑ (checked)
3. Click **Save** and close

**Important**: After enabling HTTPS redirect, update your browser URL from `http://` to `https://` and reload the page:
- Before: `http://192.168.2.90`
- After: `https://192.168.2.90` (accept self-signed certificate warning)

---

### Part 2: Network Interface Configuration

I changed the LAN subnet from the default 192.168.1.0/24 to 192.168.250.0/24 (avoiding IP conflicts with my existing ISP router's network).

**Via LuCI Web Interface:**
1. Navigate to **Network → Interfaces**
2. Edit **LAN Interface**:
   - Protocol: Static Address
   - IPv4 Address: `192.168.250.1`
   - IPv4 Netmask: `255.255.255.0` (/24)
   - DHCP Server: Enabled

**Via UCI Command Line:**
```bash
uci set network.lan.ipaddr='192.168.250.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

#### Disable DHCP Server on WAN Interface

Since the OpenWrt router's WAN interface gets its IP from the upstream ISP router, I disabled the DHCP server on the WAN interface to avoid conflicts:

**Via LuCI Web Interface:**
1. Navigate to **Network → Interfaces**
2. Click on **WAN** interface
3. Go to **DHCP Server** tab
4. Check **Ignore interface**: ☑ (checked)
5. Click **Save** and close

**Why this is needed:**
- The WAN interface (192.168.2.90) is a client on the ISP router's network
- Running a DHCP server on WAN would conflict with the ISP router's DHCP
- This ensures the WAN interface only receives IP configuration, not serves it

**After this change, reconnect to the router:**

**Option 1: Via LAN interface (if physically connected to LAN port):**
```bash
ssh root@192.168.250.1
```

**Option 2: Via WAN interface (if on ISP network 192.168.2.x):**
```bash
ssh root@192.168.2.90
```

---

### Part 3: WireGuard VPN Setup

#### Install WireGuard Packages

```bash
# Update package lists
opkg update

# Install WireGuard packages
opkg install wireguard-tools luci-proto-wireguard kmod-wireguard

# Reboot to load kernel module
reboot
```

#### Generate Server Keys

**After the router reboots, reconnect via SSH:**
```bash
# From your ISP network (192.168.2.x):
ssh root@192.168.2.90

# Or if directly connected to OpenWrt LAN port:
ssh root@192.168.250.1
```

**Then generate WireGuard server keys:**
```bash
# Create wireguard directory
mkdir -p /etc/wireguard

# Generate server private key
umask 077
wg genkey > /etc/wireguard/server_private.key

# Generate server public key
wg pubkey < /etc/wireguard/server_private.key > /etc/wireguard/server_public.key

# Display keys (save these securely)
echo "Server Private Key:"
cat /etc/wireguard/server_private.key
echo "Server Public Key:"
cat /etc/wireguard/server_public.key
```

#### Configure WireGuard Interface

**Via UCI:**
```bash
# WireGuard interface
uci set network.wg0=interface
uci set network.wg0.proto='wireguard'
uci set network.wg0.private_key="$(cat /etc/wireguard/server_private.key)"
uci set network.wg0.listen_port='51820'
uci add_list network.wg0.addresses='10.10.10.1/24'

# Commit changes
uci commit network
/etc/init.d/network restart
```

**Via LuCI:**
1. Navigate to **Network → Interfaces**
2. Click "Add new interface"
3. Name: `wg0`
4. Protocol: WireGuard VPN
5. On the **General Settings** tab:
   - **Private Key**: Paste your server private key (from `/etc/wireguard/server_private.key`)
   - **Public Key**: Leave empty (auto-generated from private key)
   - **Listen Port**: `51820`
   - **IP Addresses**: Click **Add** and enter `10.10.10.1/24`
6. Click **Save** and close

#### Add WireGuard Peer (Client)

Clients generate their own keypair during client installation. When a client sends you their **public key**, add the peer to the router:

**Via UCI:**
```bash
# Add peer
uci add network wireguard_wg0
uci set network.@wireguard_wg0[-1].public_key='CLIENT_PUBLIC_KEY_HERE'
uci set network.@wireguard_wg0[-1].description='client-laptop'
uci add_list network.@wireguard_wg0[-1].allowed_ips='10.10.10.2/32'

# Commit changes
uci commit network
/etc/init.d/network restart
```

**Via LuCI:**
1. Navigate to **Network → Interfaces → wg0**
2. Go to **Peers** tab
3. Add peer:
   - Description: `client-laptop`
   - Public Key: (client's public key)
   - Allowed IPs: `10.10.10.2/32`
   - Persistent Keepalive: `25` (optional, helps with NAT traversal)
4. Save and Apply

**Repeat for each client**, incrementing the IP address (`10.10.10.3`, `10.10.10.4`, etc.).

---

### Part 4: Firewall Configuration

This is the key part - creating firewall zones and rules to isolate the AI server while allowing controlled access.

#### Create Firewall Zones

**Via LuCI:**
1. Navigate to **Network → Firewall**
2. Go to **General Settings** tab
3. Verify/configure default zones:
   - **lan**:
     - Input: accept, Output: accept, Forward: accept
     - Masquerading: unchecked
     - **Allow forward to destination zones**: Select `wan` (enables AI server internet access)
   - **wan**:
     - Input: reject, Output: accept, Forward: reject
     - **Masquerading: checked** ✓ (enables NAT for internet access)
4. Add **vpn** zone:
   - Name: `vpn`
   - Input: reject
   - Output: accept
   - Forward: reject
   - Masquerading: disabled
   - Covered networks: `wg0`

**Via UCI:**
```bash
# Verify WAN zone has masquerading enabled (usually enabled by default)
# If not enabled, set it:
uci set firewall.@zone[1].masq='1'  # Assuming wan is zone[1]

# Add VPN zone
uci add firewall zone
uci set firewall.@zone[-1].name='vpn'
uci set firewall.@zone[-1].input='REJECT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='REJECT'
uci add_list firewall.@zone[-1].network='wg0'

uci commit firewall
/etc/init.d/firewall restart
```

#### Configure Traffic Rules for AI Server Isolation

**Rule 1: Allow VPN → AI Server (port 11434 only)**

**Via LuCI:**
1. Navigate to **Network → Firewall → Traffic Rules** tab
2. Click **Add**
3. Configure the rule:
   - **Name**: `Allow-VPN-to-Ollama`
   - **Protocol**: TCP
   - **Source zone**: vpn
   - **Destination zone**: lan
   - **Destination address**: `192.168.250.20`
   - **Destination port**: `11434`
   - **Action**: accept
4. Click **Save** and close

**Via UCI:**
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-VPN-to-Ollama'
uci set firewall.@rule[-1].src='vpn'
uci set firewall.@rule[-1].dest='lan'
uci set firewall.@rule[-1].dest_ip='192.168.250.20'
uci set firewall.@rule[-1].dest_port='11434'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

---

**Rule 2: Block VPN → LAN (except AI server)**

**Note**: This is implicit through zone defaults. The vpn zone has `forward=REJECT`, so all traffic is blocked by default. Only the specific rule above allows access to 192.168.250.20:11434.

---

**Rule 3: Isolate AI Server from other LAN devices**

**Via LuCI:**
1. Navigate to **Network → Firewall → Traffic Rules** tab
2. Click **Add**
3. Configure the rule:
   - **Name**: `Block-AI-Server-to-LAN`
   - **Source zone**: lan
   - **Source address**: `192.168.250.20`
   - **Destination zone**: lan
   - **Action**: reject
4. Click **Save & Apply**

**Via UCI:**
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Block-AI-Server-to-LAN'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].src_ip='192.168.250.20'
uci set firewall.@rule[-1].dest='lan'
uci set firewall.@rule[-1].target='REJECT'

uci commit firewall
/etc/init.d/firewall restart
```

---

### Part 5: Static IP for AI Server

I configured the AI server with a static IP address for consistency. **I used Option B** (configuring directly on the server) for my setup.

**Option A: DHCP Static Lease on Router**

**Via LuCI:**
1. Navigate to **Network → DHCP and DNS**
2. Go to **Static Leases** tab
3. Add static lease:
   - Hostname: `self-sovereign-ollama`
   - MAC Address: (AI server's MAC address)
   - IPv4 Address: `192.168.250.20`

**Via UCI:**
```bash
# Add static DHCP lease
uci add dhcp host
uci set dhcp.@host[-1].name='self-sovereign-ollama'
uci set dhcp.@host[-1].mac='XX:XX:XX:XX:XX:XX'  # Replace with actual MAC
uci set dhcp.@host[-1].ip='192.168.250.20'

uci commit dhcp
/etc/init.d/dnsmasq restart
```

**Option B: Configure static IP on server directly** (recommended for stability)
- I used macOS System Settings → Network → Ethernet → Details → TCP/IP
- Set to "Manually" and configured:
  - IP Address: `192.168.250.20`
  - Subnet Mask: `255.255.255.0`
  - Router: `192.168.250.1`
  - DNS: `192.168.250.1` (or external DNS like 1.1.1.1)

---

### Part 6: Local Testing

At this point, with the VPN configured but no ISP port forwarding, I tested connectivity:

**From the AI server (192.168.250.20):**
```bash
# Test router connectivity
ping 192.168.250.1  # Should succeed

# Test internet connectivity
ping 8.8.8.8  # Should succeed

# Test that AI server cannot reach other LAN devices (isolation)
ping 192.168.250.100  # Should fail (if firewall rules correct)
```

**From a device on the local home network (testing through WAN):**
```bash
# From your laptop on home network (192.168.2.x)
# Connect to VPN using OpenWrt's WAN IP as endpoint: 192.168.2.90:51820
# Then test:

ping 10.10.10.1  # VPN server should respond
curl http://192.168.250.20:11434/v1/models  # Should reach Ollama through VPN
ping 192.168.250.1  # LAN gateway - should fail (VPN clients blocked from LAN)
```

**Note**: This tests the VPN through the WAN interface (192.168.2.90) from your regular home network, which is how it will work in production (before ISP port forwarding is added).

---

## Phase 2: External Access (With ISP Port Forwarding)

As a final step to enable remote access from anywhere, I configured port forwarding on my ISP router to expose the WireGuard VPN to the internet.

### Part 7: ISP Router Port Forwarding

**On my ISP router (192.168.2.1):**
1. Logged into ISP router admin interface
2. Found port forwarding / virtual server settings
3. Added port forwarding rule:
   - External Port: `51820` (UDP)
   - Internal IP: `192.168.2.90` (OpenWrt WAN IP)
   - Internal Port: `51820` (UDP)
   - Protocol: UDP

This allows external VPN clients to reach the OpenWrt WireGuard server via my public IP.

**CRITICAL**: Only forward UDP port 51820 (WireGuard). Do NOT forward TCP port 11434 (Ollama) to the internet.

---

### Part 8: OpenWrt WAN Traffic Rules

Ensure OpenWrt accepts WireGuard traffic from WAN (this allows external VPN connections to reach the router).

**Via LuCI:**
1. Navigate to **Network → Firewall → Traffic Rules** tab
2. Click **Add**
3. Configure the rule:
   - **Name**: `Allow-WireGuard`
   - **Protocol**: UDP
   - **Source zone**: wan
   - **Destination port**: `51820`
   - **Action**: accept
4. Click **Save & Apply**

**Via UCI:**
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-WireGuard'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='51820'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

---

### Part 9: External Client Configuration

When configuring external VPN clients (not on the local LAN), they need:
- **Endpoint**: `<my-public-ip>:51820` (or use Dynamic DNS)
- **Server Public Key**: From `/etc/wireguard/server_public.key`
- **Allowed IPs**: `10.10.10.0/24, 192.168.250.20/32`

**Note**: If using the client installation script (`client/scripts/install.sh`), this configuration is **generated automatically** - no need to create it manually. The example below is for reference or manual setup.

Example client WireGuard config:
```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.10.10.2/32

[Peer]
PublicKey = <server-public-key-from-openwrt>
Endpoint = <my-public-ip>:51820
AllowedIPs = 10.10.10.0/24, 192.168.250.20/32
PersistentKeepalive = 25
```

---

## Verification and Testing

### Verify WireGuard is Running

**Run on OpenWrt router (server):**

```bash
# SSH to router: ssh root@192.168.2.90

# Check WireGuard interface status
wg show wg0

# Should show:
# - interface: wg0
# - public key: (server public key)
# - listening port: 51820
# - peers: (list of configured peers)
```

### Verify Firewall Rules

**Run on OpenWrt router (server):**

```bash
# SSH to router: ssh root@192.168.2.90

# List all firewall rules
iptables -L -n -v

# Check for:
# - WAN → WireGuard UDP port 51820: ACCEPT
# - VPN → LAN (192.168.250.20:11434): ACCEPT
# - VPN → LAN (other): DROP/REJECT
# - LAN (192.168.250.20) → LAN (other): DROP/REJECT
```

### Test from VPN Client

**Run on client machine (after WireGuard is configured and connected):**

```bash
# First, connect to VPN (varies by client OS - use WireGuard app or wg-quick)

# Test VPN connectivity
ping 10.10.10.1  # Should succeed (router VPN IP)

# Test connectivity to AI server
ping 192.168.250.20  # Should succeed

# Test connectivity to inference port
nc -zv 192.168.250.20 11434  # Should succeed (if Ollama is running)

# Test that LAN gateway is isolated (should fail - this is expected)
ping 192.168.250.1  # Should timeout or fail (VPN clients blocked from LAN gateway)

# Test internet access (should fail - VPN clients have no internet routing)
ping 8.8.8.8  # Should timeout or fail
```

### Test from AI Server

**Run on AI server (macOS):**

```bash
# On the AI server at 192.168.250.20

# Test outbound internet (should succeed)
ping 8.8.8.8
curl -I https://www.google.com

# Test access to other LAN devices (should fail due to isolation)
ping 192.168.250.100  # Should timeout or fail (firewall isolation working)

# Test access to router gateway (should succeed for DNS, etc.)
ping 192.168.250.1  # Should succeed
```

---

## Maintenance and Troubleshooting

### View Logs

```bash
# System log
logread

# Firewall log
logread | grep firewall

# WireGuard log
logread | grep wireguard

# Real-time log
logread -f
```

### Check WireGuard Status

```bash
# Show WireGuard interface status
wg show

# Show peers with handshake times
wg show wg0

# Show specific peer
wg show wg0 peers
```

### Check Firewall Rules

```bash
# List all rules
iptables -L -v -n

# List NAT rules
iptables -t nat -L -v -n

# Check zone forwardings
uci show firewall | grep zone
uci show firewall | grep forwarding
```

### Common Issues

**Issue: VPN clients cannot connect from external network**
- Check ISP router port forwarding (UDP 51820 → 192.168.2.90)
- Verify OpenWrt WAN firewall accepts UDP 51820
- Check WireGuard is running: `wg show wg0`
- Verify client has correct public IP as endpoint

**Issue: VPN clients cannot reach AI server**
- Check firewall rule allows VPN → 192.168.250.20:11434
- Verify AI server is running and listening: `lsof -i :11434`
- Test from router: `nc -zv 192.168.250.20 11434`

**Issue: AI server can reach other LAN devices (isolation broken)**
- Check firewall rule blocks traffic from 192.168.250.20 to LAN
- Verify with: `uci show firewall | grep "Block-AI-Server"`
- Test isolation from server: `ping 192.168.250.X`

---

## Backup and Restore

### Backup Configuration

```bash
# Create backup (on OpenWrt router)
sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz

# Download backup (from admin machine)
mkdir -p ~/openwrt-backups  # Create directory if it doesn't exist
scp -O 'root@192.168.2.90:/tmp/backup-*.tar.gz' ~/openwrt-backups/
# Note: -O flag uses legacy SCP (OpenWrt doesn't have SFTP server by default)
# Note: Quotes prevent local shell from expanding the wildcard
```

### Restore Configuration

```bash
# Upload backup
scp -O backup.tar.gz root@192.168.2.90:/tmp/

# Restore (preserves installed packages)
sysupgrade -r /tmp/backup.tar.gz

# Reboot
reboot
```

---

## Support and Further Reading

- **OpenWrt Documentation**: https://openwrt.org/docs/start
- **WireGuard Documentation**: https://www.wireguard.com/
- **OpenWrt Firewall Guide**: https://openwrt.org/docs/guide-user/firewall/start
- **OpenWrt UCI Documentation**: https://openwrt.org/docs/guide-user/base-system/uci

For project-specific issues, see main repository documentation.
