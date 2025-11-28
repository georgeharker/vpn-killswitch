#!/bin/zsh

# vpn-killswitch.sh
# Uses:
#   https://github.com/brona/iproute2mac
#   https://jqlang.org
# Presumes homebrew or /usr/local installation of these

export PATH="$PATH:/usr/local/bin"
eval "$(/usr/bin/env PATH_HELPER_ROOT="/opt/homebrew" /usr/libexec/path_helper -s)"

function usage(){
  echo "Usage: $script_name [--no4] | [--no6]"
  echo "  --no4                                 do not search ipv4 for tailscale"
  echo "  --no6                                 do not search ipv6 for tailscale"
  echo "  --vpn=name                            specify vpn name (Nord by default)"
  echo "  --icloud_relay=[none,escape]          icloud relay treatment (none)"
  echo "  --tailscale=[none,escape]             tailscale treatment (escape)"
  echo ""
}

# Parse command line arguments manually to handle --option=value format
no4=()
no6=()
vpn=()
icloud_relay_opt=()
tailscale_opt=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --no4)
            no4+=("$1")
            shift
            ;;
        --no6)
            no6+=("$1")
            shift
            ;;
        --vpn=*)
            vpn=("--vpn" "${1#*=}")
            shift
            ;;
        --icloud_relay=*)
            icloud_relay_opt=("--icloud_relay" "${1#*=}")
            shift
            ;;
        --tailscale=*)
            tailscale_opt=("--tailscale" "${1#*=}")
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Parse and validate routing options
icloud_relay_mode="none"
if [[ ${#icloud_relay_opt[@]} -gt 0 ]]; then
    icloud_relay_mode=${icloud_relay_opt[2]}
fi

tailscale_mode="escape"
if [[ ${#tailscale_opt[@]} -gt 0 ]]; then
    tailscale_mode=${tailscale_opt[2]}
fi

# Validate options
if [[ $icloud_relay_mode != "none" && $icloud_relay_mode != "escape" && $icloud_relay_mode != "vpn" ]]; then
    echo "Error: Invalid icloud_relay option '$icloud_relay_mode'. Must be one of: none, escape, vpn"
    exit 1
fi

if [[ $tailscale_mode != "none" && $tailscale_mode != "escape" ]]; then
    echo "Error: Invalid tailscale option '$tailscale_mode'. Must be one of: none, escape"
    exit 1
fi

echo "Configuration:"
echo "  Tailscale routing: $tailscale_mode"
echo "  iCloud Private Relay routing: $icloud_relay_mode"

tailscale_inet4_ip=""
tailscale_inet6_ip=""
tailscale_utun=""

function get_tailscale_ips() {
    # Skip tailscale detection if mode is "none"
    if [[ $tailscale_mode == "none" ]]; then
        echo "Tailscale routing: disabled (none mode)"
        return
    fi
    
    tailscale_ips=$(tailscale status --json | jq -r '.Self.TailscaleIPs[]')
    for ip in ${(f)tailscale_ips}; do
        if [[ "$ip" =~ [0-9]+.[0-9]+.[0-9]+.[0-9]+ ]]; then
            echo "ipv4 addr: $ip"
            tailscale_inet4_ip=$ip
        elif [[ "$ip" =~ [0-9a-fA-F]+(:[0-9a-fA-F:]*)* ]]; then
            echo "ipv6 addr: $ip"
            tailscale_inet6_ip=$ip
        fi
    done

    if [[ ${#no4[@]} -gt 0 ]]; then
        tailscale_inet4_ip=""
    fi

    if [[ ${#no6[@]} -gt 0 ]]; then
        tailscale_inet6_ip=""
    fi

    if [[ -n tailscale_inet4_ip || -n tailscale_inet6_ip ]]; then
        local ifaces=$(ip -j addr | jq -r '.[] | select(
                .addr_info[]?.family == "inet" and .addr_info[]?.local == "'$tailscale_inet4_ip'" or
                .addr_info[]?.family == "inet6" and .addr_info[]?.local == "'$tailscale_inet6_ip'" ) | .ifname')
        typeset -Ua utuns
        for iface in ${(f)ifaces}; do
            utuns+=($iface)
        done
        tailscale_utun=${utuns[1]}
        echo "Tailscale utun: ${tailscale_utun} (mode: $tailscale_mode)"
    fi
}

vpn_name="Nord"
if [[ ${#vpn[@]} -gt 0 ]]; then
    vpn_name=${vpn[2]}
fi

nord_id=""
nord_server_address=""
nord_utun=""

function get_vpn_info() {
    vpn_id=$(scutil --nc list | grep "${vpn_name}" | grep '^\*[[:blank:]]*(Connected)' | sed -Ene 's/^.*[[:blank:]]+([A-F0-9]+(-[A-F0-9]+)+).*$/\1/p')
    if [[ -n $vpn_id ]]; then
        echo "VPN ${vpn_name} scutil id: ${vpn_id}"
        vpn_server_address=$(scutil --nc status ${vpn_id} | grep -E ServerAddress | sed -Ene 's/^.*ServerAddress[[:blank:]]*:[[:blank:]]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*$/\1/p')
        vpn_utun=$(scutil --nc status ${vpn_id} | grep InterfaceName | sed -Ene 's/^.*InterfaceName[[:blank:]]*:[[:blank:]]*([a-zA-Z0-9_]+).*$/\1/p')
        echo "${vpn_name} ServerAddress: ${vpn_server_address}"
        echo "VPN ${vpn_name} utun: ${vpn_utun}"
        
        # Validate VPN interface exists
        if [[ -z $vpn_utun ]] || ! ifconfig "$vpn_utun" >/dev/null 2>&1; then
            echo "Error: VPN interface ${vpn_utun} not found or not active"
            return 1
        fi
    else
        echo "VPN ${vpn_name} is not connected"
        return 1
    fi
}

function get_up_en_interface() {
    local en_ifaces=$(ip -j addr | jq -r '.[] | select(.operstate == "UP" and (.addr_info | length) > 0 and (.ifname | match("en[0-9]+"; "g"))) | .ifname')
    typeset -Ua ens
    for iface in ${(f)en_ifaces}; do
        ens+=($iface)
    done
    en=${ens[1]}
    echo $en
}

function get_gateway() {
    echo $(ip -j route list | jq -r '.[] | select(.dev == "'${1}'" and has("gateway")) | .gateway')
}

function resolve_icloud_relay_ips() {
	typeset -aU relay_ips
    local relay_ips=()
    local domains=("mask.icloud.com" "mask-h2.icloud.com" "mask-api.icloud.com" "mask.apple-dns.net")
    
    for domain in $domains; do
        # Get IPv4 addresses
        local ipv4_addrs=$(dig +short $domain @${vpn_server_address} A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        for ip in ${(f)ipv4_addrs}; do
            [[ -n $ip ]] && relay_ips+=($ip)
        done
        
        # Get IPv6 addresses
        local ipv6_addrs=$(dig +short $domain  @${vpn_server_address} AAAA | grep -E '^[0-9a-fA-F:]+$')
        for ip in ${(f)ipv6_addrs}; do
            [[ -n $ip ]] && relay_ips+=($ip)
        done
    done
    
    printf '%s\n' "${relay_ips[@]}"
}

get_tailscale_ips
if ! get_vpn_info; then
    echo "VPN setup failed, cleaning up pfctl rules"
    sudo pfctl -a "killswitch/*" -Fa -t icloud_relay -T flush -t icloud_relay -T kill
    exit 1
fi

# Pre-resolve iCloud relay IPs if needed
icloud_relay_ips=()
if [[ $icloud_relay_mode != "none" ]]; then
    echo "Resolving iCloud Private Relay IPs (mode: $icloud_relay_mode)..."
    icloud_relay_ips=($(resolve_icloud_relay_ips))
    echo "Found ${#icloud_relay_ips[@]} relay IPs"
fi

pf_conf=$(cat <<EOF_PF_CONF
table <icloud_relay> persist
anchor "killswitch/*" {
pass quick on lo0 from any to any
pass quick on ${vpn_utun} from any to any # Your VPN interface

$(
# Handle Tailscale routing based on mode
if [[ -n ${tailscale_utun} ]]; then
    case $tailscale_mode in
        "escape")
            echo "# Tailscale: bypass VPN (escape mode)"
            echo "pass quick on ${tailscale_utun} from any to any  # Tailscale interface"
            echo "# Allow Tailscale NAT traversal (CRITICAL for direct connections - otherwise it uses DERP)"
            echo "pass out quick proto udp to any port { nat-stun-port 41641 }  # 41641 = tailscale"
            echo "pass in quick proto udp from any port { nat-stun-port 41641 }  # 41641 = tailscale"
            ;;
        "none")
            echo "# Tailscale: disabled - block interface entirely"
            echo "block drop quick on ${tailscale_utun} from any to any"
            ;;
    esac
else
    if [[ $tailscale_mode == "escape" ]]; then
        echo "# Tailscale not detected but escape mode requested"
        echo "# Allow Tailscale NAT traversal in case it starts later"
        echo "pass out quick proto udp to any port { nat-stun-port 41641 }  # 41641 = tailscale"
        echo "pass in quick proto udp from any port { nat-stun-port 41641 }  # 41641 = tailscale"
    fi
fi
)

pass out quick proto { tcp udp } to any port domain #DNS
pass out quick proto udp from any port bootpc to any port bootps #DHCP
pass out quick proto { tcp udp } to ${vpn_server_address}

# Allow local network - add your own subnets

pass quick from any to { 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 }

$(
# Handle iCloud Private Relay routing based on mode
if [[ $icloud_relay_mode == "escape" ]]; then
    local enx=$(get_up_en_interface)
    local gateway_ip=$(get_gateway $enx)
    if [[ -n $enx && -n $gateway_ip ]]; then
        echo "# iCloud Private Relay: bypass VPN (escape mode)"
        echo "pass out route-to (${enx} ${gateway_ip}) proto tcp from any to <icloud_relay> port { https, domain }"
        echo "pass out route-to (${enx} ${gateway_ip}) proto udp from any to <icloud_relay> port { https, domain }"
        echo "pass in quick on ${enx} proto tcp from <icloud_relay> to any"
        echo "pass in quick on ${enx} proto udp from <icloud_relay> to any"
    else
        echo "# Warning: Could not determine physical interface or gateway for iCloud relay escape"
    fi
elif [[ $icloud_relay_mode == "vpn" ]]; then
    echo "# iCloud Private Relay: route through VPN"
    echo "# iCloud Private Relay traffic will be routed through the VPN interface"
elif [[ $icloud_relay_mode == "none" ]]; then
    echo "# iCloud Private Relay: disabled - no special rules"
fi
)

# Block everything else on non-VPN interfaces

block drop out quick on ! ${vpn_utun} inet from any to any
}

EOF_PF_CONF
)

if [[ -n $vpn_id ]]; then
    # Load pfctl rules
    echo "${pf_conf}" | sudo pfctl -a "killswitch/*" -f -
    
	echo "Current killswitch rules:"
    sudo pfctl -a "killswitch/*" -sr

    # Add iCloud relay IPs to table if relay is enabled and using escape mode
    if [[ $icloud_relay_mode == "escape" && ${#icloud_relay_ips[@]} -gt 0 ]]; then
        echo "Adding ${#icloud_relay_ips[@]} IPs to icloud_relay table..."
        for ip in "${icloud_relay_ips[@]}"; do
            sudo pfctl -a "killswitch/*" -t icloud_relay -T add "$ip" 2>/dev/null || echo "Failed to add $ip"
        done
        
        # Show current table contents
        echo "Current icloud_relay table contents:"
        sudo pfctl -a "killswitch/*" -t icloud_relay -T show
    elif [[ $icloud_relay_mode != "none" ]]; then
        echo "iCloud Private Relay mode: $icloud_relay_mode (no table population needed)"
    fi
else
    sudo pfctl -a "killswitch/*" -Fa -t icloud_relay -T flush -t icloud_relay -T kill
fi

