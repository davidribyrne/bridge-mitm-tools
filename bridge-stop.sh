#!/bin/bash

if [ -z "$1" ]; then
	echo "Usage: $0 <bridge-ifname>"
	exit 1
fi

BRIDGE_IF=$1

ifconfig $BRIDGE_IF down
brctl delbr $BRIDGE_IF
