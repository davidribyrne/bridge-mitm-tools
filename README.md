Bridge MITM tools
=================

A collection of shell scripts for performing a MITM attack on bridged TCP traffic.

Example usage
-------------

Assuming a local server bound to \<server IP\>:1337

1. `./bridge-start.sh -b br0 -l eth0 -r eth1`
2. `./bridge-reroute.sh \`  
`    --bridge br0 \`  
`    --client 10.1.33.6 00:00:00:00:00:00 \`  
`    --server 10.1.33.7 00:00:00:00:00:01 80 \`  
`    --local-port 1337`
3. \<tomfoolery\>
4. `./bridge-reroute-undo.sh -b br0 -c 10.1.33.6`
5. `./bridge-stop.sh br0`

Works well in combination with [hijack-agent](https://github.com/rkok/hijack-agent)!

How it works
------------

Using `ebtables` and `iptables`, traffic destined for the server is rerouted to a local dummy interface __fake0__:\<local port\> with \<server IP+MAC\> assigned to it. All other traffic (client-to-server / server-to-client) continues to be routed normally.

Assumptions / TODOs
-------------------

As these scripts were written for use on a Raspberry Pi, there are some limitations:

- Only tested on Debian / Raspbian Jessie, other Linuxes will require tweaks
- May not bridge transparently (see below)
- TODO: IPv6, UDP
- TODO: setup script to install required binaries (ip, iptables, ifconfig, modprobe, ebtables)

Pull requests are appreciated!

MITM detectability
------------------

Though efforts were made to bridge / hijack transparently:

- `bridge-reroute.sh` disables ARP on all relevant interfaces
- `dhcp-disable.sh` kills `dhclient` for a given interface

... complete transparency is not guaranteed, as other processes on the system may attempt to send information onto the network. Please test-drive before use.
