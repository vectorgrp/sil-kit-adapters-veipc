#!/bin/bash

export qemu_binary=/usr/bin/qemu-system-x86_64
export bridge_helper=`$qemu_binary --help | grep qemu-bridge-helper | head -n 1 | sed 's/.*default=\([^)]*\)).*/\1/'`
export bridge_conf=`strings $bridge_helper | grep /bridge.conf`
chown root:root $bridge_conf
chmod 0644 $bridge_conf
chmod u+s $bridge_helper

echo "Creating br0 interface"
brctl addbr br0

echo "Attach br0 interface to ens38"
brctl addif br0 ens38

echo "Configure br0 IP"
ifconfig br0 192.168.1.2/24 up
#ifconfig br0 192.168.100.1/24 up
