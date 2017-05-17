#!/bin/bash

if [ -z "$1" ]; then
	echo "Usage: $0 <dhcp-interface>"
	exit 1
fi

INTERFACE=$1

dhcgrep() {
	INTERFACE=$1
	ps -ef | grep dhclient.$INTERFACE | grep -v grep | awk '{print $2}'
}

DHCPID=$(dhcgrep $INTERFACE)
if [ ! -z "$DHCPID" ]; then
	kill $DHCPID
fi
if [ ! -z "$(dhcgrep $INTERFACE)" ]; then
	echo "Couldn't kill dhclient for $INTERFACE" > /dev/stderr
	exit 1
fi

exit 0
