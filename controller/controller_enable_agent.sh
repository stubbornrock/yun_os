#!/bin/bash

##############################
## JUST RUN ONCE ON CONTROLLER
##############################

INVENTORY="/tmp/yun_os/nodes.txt"

function enable_dhcp_agent(){
    echo "Enable dhcp agents ..."
    source /root/openrc
    # disable dhcp agent
    for net in `neutron net-list  --router:external False --field id --format value`;do
        subnet_uuid=`neutron net-show $net | grep subnets | cut -d'|' -f3`
        neutron subnet-update --enable-dhcp $subnet_uuid
    done
}

crm resource restart p_haproxy
enable_dhcp_agent
