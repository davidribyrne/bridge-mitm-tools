#!/bin/bash

while getopts ":b:l:r:" opt; do
	case $opt in
		b) IF_BRIDGE="$OPTARG"
		;;
		l) IF_LEFT="$OPTARG"
		;;
		r) IF_RIGHT="$OPTARG"
		;;
	esac
done

if [ -z "$IF_BRIDGE" ] || [ -z "$IF_LEFT" ] || [ -z "$IF_RIGHT" ]; then
	echo "Usage: $0 -b <bridge-intf-name> -l <left-intf-name> -r <right-intf-name>"
	exit 1
fi

ifconfig $IF_LEFT 0.0.0.0
ifconfig $IF_RIGHT 0.0.0.0

brctl addbr $IF_BRIDGE
brctl addif $IF_BRIDGE $IF_LEFT
brctl addif $IF_BRIDGE $IF_RIGHT
ifconfig $IF_BRIDGE up
