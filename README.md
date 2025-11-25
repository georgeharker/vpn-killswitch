# killswitch for use with a VPN

If you run a VPN (optionally with tailscale) you may find that the VPN's killswitch
prevents you using tailscale.

One solution is to *turn off the VPN killswitch* but then you risk leaking traffic.

This LaunchDaemon automatically kills traffic from leaking from your VPN whilst
maintaining connectivity to tailscale.

It defaults to NornVPN as the VPN it looks for.  However it can be used for any by
modifying the plist to include the `--vpn="Name of VPN"` argument like so:

```
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/env</string>
        <string>/usr/local/bin/vpn-killswitch.sh</string>
        <string>--vpn="Name of VPN"</string>
	</array>
```

## Installation

Use `make install` (which will ask for a `sudo` password) to install the LaunchDaemon.

## Removal

Use `make remove`

## Optional escape route for icloud private relay

Use `make install_relay` which similarly asks for a `sudo` password and will attempt to
route the traffic for icloud private relay directly onto an active network device which is
not a vpn.  Ie it does not go over the VPN.

This is useful if your VPN blocks icloud private relay.
