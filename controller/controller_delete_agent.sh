#!/bin/bash

##############################
## JUST RUN ONCE ON CONTROLLER
##############################

INVENTORY="/tmp/yun_os/nodes.txt"

nodes(){
    local roles="$1"
    local field="$2" #1:management 2:pxe 3:storagepub 4:hostname 5:role
    if [[ $roles == "all" ]];then
        cat ${INVENTORY} | awk "{print \$${field}}" | sort | uniq
    else
        cat ${INVENTORY} | egrep -e "$roles" | awk "{print \$${field}}" | sort | uniq
    fi
}

function test_commands(){
    set -e
    echo "Test nova/neutron commands ... if error please exit and check!!"
    source /root/openrc
    nova service-list
    neutron agent-list
    neutron router-list
    neutron agent-list
    set +e
}

function delete_nova_service(){
    echo "Delete nova services on mariadb|rabbitmq ..."
    host_names=""
    for name in `nodes 'mariadb|rabbitmq' 4`;do
        host_names="${host_names}${name}|"
    done
    host_names=${host_names%?}
    source /root/openrc
    for service in `nova service-list | egrep $host_names | cut -d'|' -f2`;do
        echo "nova service-delete $service ...."
        nova service-delete $service
    done
}

function delete_neutron_agent(){
    echo "Delete neutron agents on mariadb|rabbitmq ..."
    host_names=""
    for name in `nodes 'mariadb|rabbitmq' 4`;do
        host_names="${host_names}${name}|"
    done
    host_names=${host_names%?}
    source /root/openrc
    for service in `neutron agent-list | egrep $host_names | cut -d'|' -f2`;do
        echo "neutron agent-delete $service ...."
        neutron agent-delete $service
    done
}

function delete_neutron_router(){
    echo "Delete neutron routers ..."
    source /root/openrc
    for id in `neutron router-list --field id -f value`;do
        neutron router-delete $id
    done
}

function disable_neutron_l3agent(){
    echo "Disable neutron l3 agents on controllers ..."
    host_names=""
    for name in `nodes controller 4`;do
        host_names="${host_names}${name}|"
    done
    host_names=${host_names%?}
    source /root/openrc
    for service in `neutron agent-list | grep neutron-l3-agent | egrep $host_names | cut -d'|' -f2`;do
        echo "neutron agent-delete $service ..."
        neutron agent-delete $service
    done
}

function delete_dhcp_agent(){
    echo "Disable dhcp agent ..."
    source /root/openrc
    # disable dhcp agent
    for net in `neutron net-list  --router:external False --field id --format value`;do
        subnet_uuid=`neutron net-show $net | grep subnets | cut -d'|' -f3`
        neutron subnet-update --disable-dhcp $subnet_uuid
    done
}

crm resource restart p_haproxy
test_commands
delete_nova_service
delete_neutron_agent
delete_neutron_router
disable_neutron_l3agent
delete_dhcp_agent
