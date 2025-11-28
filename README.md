# Killswitch for use with a VPN

If you run a VPN (optionally with Tailscale) you may find that the VPN's killswitch
prevents you using Tailscale or iCloud Private Relay.

One solution is to *turn off the VPN killswitch* but then you risk leaking traffic.

This LaunchDaemon automatically prevents traffic from leaking from your VPN whilst
maintaining configurable connectivity to Tailscale and iCloud Private Relay.

It defaults to NordVPN as the VPN it looks for. However it can be used for any VPN by
modifying the plist to include the `--vpn="Name of VPN"` argument.

## Routing Options

**Tailscale** supports two routing modes:
- **`escape`** (default): Bypass the VPN (route directly through physical interface)
- **`none`**: Disable Tailscale entirely (blocked by killswitch)

**iCloud Private Relay** supports three routing modes:
- **`none`** (default): No special handling (blocked by killswitch)
- **`escape`**: Bypass the VPN (route directly through physical interface) 
- **`vpn`**: Force traffic through the VPN

### Command Line Usage

```bash
# Basic usage with defaults (Tailscale=escape, iCloud=none)
./vpn-killswitch.sh

# Customize routing modes
./vpn-killswitch.sh --tailscale=escape --icloud_relay=escape
./vpn-killswitch.sh --tailscale=none --icloud_relay=escape
./vpn-killswitch.sh --tailscale=escape --icloud_relay=vpn

# Use different VPN
./vpn-killswitch.sh --vpn="ExpressVPN" --tailscale=escape
```

### Manual plist Configuration

To customize routing in a plist file:

```xml
<key>ProgramArguments</key>
<array>
    <string>/usr/bin/env</string>
    <string>/usr/local/bin/vpn-killswitch.sh</string>
    <string>--vpn="Name of VPN"</string>
    <string>--tailscale=escape</string>
    <string>--icloud_relay=escape</string>
</array>
```

## Installation

Choose the installation method that best fits your needs:

### Default Configuration
```bash
make install
```
Installs with Tailscale bypass enabled, iCloud Private Relay disabled.

### Both Services Bypass VPN
```bash
make install_relay
```
Allows both Tailscale and iCloud Private Relay to bypass the VPN.

### Custom Configuration

1. Copy and modify one of the plist files:
   - `com.georgeharker.vpn-killswitch.plist` (default: Tailscale escape, iCloud none)
   - `com.georgeharker.vpn-killswitch-relay.plist` (both services escape)
   - `com.georgeharker.vpn-killswitch-tailscale-only.plist` (Tailscale escape, iCloud none)

2. Adjust the `--tailscale` and `--icloud_relay` arguments as needed
3. Install manually:
   ```bash
   sudo cp your-custom.plist /Library/LaunchDaemons/com.georgeharker.vpn-killswitch.plist
   sudo chmod 644 /Library/LaunchDaemons/com.georgeharker.vpn-killswitch.plist
   sudo launchctl load -w /Library/LaunchDaemons/com.georgeharker.vpn-killswitch.plist
   ```

## Removal

Use `make remove` to uninstall the LaunchDaemon.

## Routing Mode Details

### Tailscale Routing Modes

- **`escape`** (default): Tailscale traffic bypasses the VPN and uses the physical network interface directly. This prevents double-VPN overhead and maintains optimal Tailscale mesh networking performance.
- **`none`**: Tailscale interface is blocked entirely. Use this if you want to disable Tailscale while the VPN is active.

**Note**: There is no viable "VPN mode" for Tailscale because Tailscale creates its own mesh network that can't meaningfully be routed through another VPN tunnel.

### iCloud Private Relay Routing Modes

- **`escape`**: iCloud Private Relay traffic bypasses the VPN and uses the physical network interface. Useful when your VPN blocks Apple's relay servers.
- **`vpn`**: iCloud Private Relay traffic is routed through the VPN.
- **`none`** (default): No special iCloud Private Relay handling (traffic will be blocked by killswitch).

### Technical Implementation

The killswitch uses macOS's `pfctl` (Packet Filter) to:
1. Allow traffic on the VPN interface
2. Allow essential services (DNS, DHCP, local networks)
3. Handle Tailscale and iCloud Private Relay based on routing mode
4. Block all other traffic on non-VPN interfaces

For `escape` mode, traffic is routed via `route-to` directives through the physical interface, bypassing the VPN tunnel.
