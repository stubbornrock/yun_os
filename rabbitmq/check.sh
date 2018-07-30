#!/bin/bash

RABBITMQ_CFG='/etc/rabbitmq/rabbitmq.config'

echo_warn(){
    echo -e "\033[33m$1\033[0m"
}
Note(){
    echo_warn "Check $1 ...."
}

check(){
    Note "Openstack Services"
    python /tmp/yun_os/services/service_manager.py check

    Note "$RABBITMQ_CFG Configs"
    cat $RABBITMQ_CFG | grep cluster_nodes

    Note "Rabbitmq Cluster_status"
    rabbitmqctl cluster_status
    rabbitmqctl list_users
    rabbitmqctl list_policies
    rabbitmqctl list_permissions 
}
## --- Main ---
check
