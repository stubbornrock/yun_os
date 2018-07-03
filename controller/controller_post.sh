#!/bin/bash

##############################
## JUST RUN ONCE ON CONTROLLER
##############################

INVENTORY="/tmp/yun_os/nodes.txt"

delete_service(){
    source /root/openrc
    for name in `cat $INVENTORY | egrep 'mariadb|rabbitmq' | awk '{print $3}'`;do
        for service in `nova service-list | grep $name | cut -d'|' -f2`;do
            nova service-delete $service
        done
    done
}
delete_agent(){
    source /root/openrc
    for name in `cat $INVENTORY | egrep 'mariadb|rabbitmq' | awk '{print $3}'`;do
        for service in `neutron agent-list | grep $name | cut -d'|' -f2`;do
            neutron agent-delete $service
        done
    done
}
delete_router(){
    source /root/openrc
    for id in `neutron router-list -F id -f value`;do
        neutron router-delete $id
    done
}

crm resource restart p_haproxy
delete_service
delete_agent
delete_router
