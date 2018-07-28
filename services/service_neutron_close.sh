#!/bin/bash
set -x
services=("neutron-l3-agent" "neutron-dhcp-agent" "neutron-metadata-agent")
for s in ${services[@]};do
    systemctl stop $s;systemctl disable $s
done
