#!/bin/bash

# For masquerading (and probably DNAT'ing)
# Should be on already
sysctl -w net.ipv4.ip_forward=1

# (Debug) For showing -j TRACE in syslog
#modprobe ipt_LOG
#sysctl -w net.netfilter.nf_log.2=ipt_LOG
