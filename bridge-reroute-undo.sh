#!/bin/bash
while getopts ":b:c:" opt; do
	case $opt in
		b) BRIDGE_IF="$OPTARG"
		;;
		c) CLIENT_IP="$OPTARG"
		;;
	esac
done

if [ -z "$BRIDGE_IF" ] || [ -z "$CLIENT_IP" ]; then
	echo "Usage: $0 -b <bridge-ifname> -c <client-ip>"
	exit 1
fi

# TODO: clean specifically the rules that were added by bridge-reroute.sh
iptables -t nat -F
ebtables -t broute -F

ip neigh del $CLIENT_IP dev $BRIDGE_IF
ifconfig fake0 0.0.0.0
ip link del fake0 type dummy
rmmod dummy