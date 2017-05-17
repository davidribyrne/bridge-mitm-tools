#!/bin/bash

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Usage: $0 <bridge-if> <mac-addr>"
	exit 1
fi

BRIDGE_IF="$1"
MAC_ADDR="$2"

STPSTAT="$(brctl showstp $BRIDGE_IF | grep -vE '(^ |^$)')"
MACSTAT="$(brctl showmacs $BRIDGE_IF | grep "$MAC_ADDR")"

if [ "$(echo "$STPSTAT" | head -1)" != "$BRIDGE_IF" ]; then
	echo "Unexpected output from 'brctl showstp'"
	exit 1
elif [ -z "$MACSTAT" ]; then
	echo "This MAC is not or no longer known by $BRIDGE_IF"
	exit 1
fi

IFNUM=$(echo "$MACSTAT" | awk '{print $1}')

echo "$STPSTAT" | perl -ne 'print "$1" if /^([^ ]+) \('$IFNUM'\)/g'
echo 