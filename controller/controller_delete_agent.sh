#!/bin/bash

##############################
## JUST RUN ONCE ON CONTROLLER
##############################

INVENTORY="/tmp/yun_os/nodes.txt"

function delete_nova_service(){
    source /root/openrc
    for name in `cat $INVENTORY | egrep 'mariadb|rabbitmq' | awk '{print $4}'`;do
        for service in `nova service-list | grep $name | cut -d'|' -f2`;do
            nova service-delete $service
        done
    done
}

function delete_neutron_agent(){
    source /root/openrc
    for name in `cat $INVENTORY | egrep 'mariadb|rabbitmq' | awk '{print $4}'`;do
        for service in `neutron agent-list | grep $name | cut -d'|' -f2`;do
            neutron agent-delete $service
        done
    done
}

function delete_neutron_router(){
    source /root/openrc
    for id in `neutron router-list --field id -f value`;do
        neutron router-delete $id
    done
}

function delete_dhcp_agent(){
    source /root/openrc
    # disable dhcp agent
    for net in `neutron net-list  --router:external False --field id --format value`;do
        subnet_uuid=`neutron net-show $net | grep subnets | cut -d'|' -f3`
        neutron subnet-update --disable-dhcp $subnet_uuid
    done
}

crm resource restart p_haproxy
delete_nova_service
delete_neutron_agent
delete_neutron_router
delete_dhcp_agent
