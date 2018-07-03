#!/bin/bash
set -x
services=("neutron-l3-agent")
for s in ${services[@]};do
    systemctl stop $s;systemctl disable $s
done
