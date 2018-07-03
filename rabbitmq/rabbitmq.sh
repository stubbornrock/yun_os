#!/bin/bash

RABBITMQ_DATA_DIR='/var/lib/rabbitmq/mnesia/'
RABBITMQ_DATA_BAKDIR='/var/lib/rabbitmq/mnesia_bak'
RABBITMQ_CFG='/etc/rabbitmq/rabbitmq.config'
RABBITMQ_CFG_BAK='/etc/rabbitmq/rabbitmq.config.bak'

## backup rabbitmq data/config
_backup_rabbitmq_data(){
    if [ ! -d "$RABBITMQ_DATA_BAKDIR" ]; then
        mkdir -p $RABBITMQ_DATA_BAKDIR
        mv $RABBITMQ_DATA_DIR $RABBITMQ_DATA_BAKDIR/
    fi
}
_backup_rabbitmq_cfg(){
    if [ ! -f "$RABBITMQ_CFG_BAK" ]; then
        cp $RABBITMQ_CFG $RABBITMQ_CFG_BAK
    fi
}

## delete nodes
delete_rabbitmq_nodes(){
    rabbitmq_state=`systemctl is-active rabbitmq-server`
    if [[ $rabbitmq_state == "active" ]];then
        rabbitmqctl stop_app
        rabbitmqctl reset
        rabbitmqctl stop
        pkill -TERM epmd ;pkill -TERM beam
        #systemctl stop rabbitmq-server
        systemctl disable rabbitmq-server
        _backup_rabbitmq_data
        #rabbitmqctl forget_cluster_node 
        #set_cluster_name name
    else
        if [ ! -d $RABBITMQ_DATA_DIR ];then
            echo "rabbitmq-server has reset pass"
        else
            echo "rabbitmq-server is not active! please start first!"
            exit 1
        fi
        systemctl disable rabbitmq-server
    fi
}

## update rabbitmq config
update_rabbitmq_config(){
    _backup_rabbitmq_cfg
    cluster_nodes="$1"
    sed -i "s#{cluster_nodes.*#{cluster_nodes, {[$cluster_nodes], disc}},#g" $RABBITMQ_CFG
}

## add nodes
add_rabbitmq_nodes(){
    cluster_nodes="$1"
    bootstrap=$2
    update_rabbitmq_config $cluster_nodes

    hostname=`hostname -s`
    rabbitmq_node="'rabbit@$hostname'"
    if $bootstrap;then
        systemctl restart rabbitmq-server
        rabbit_password=`egrep ^rabbit_password /etc/nova/nova.conf | cut -d'=' -f2`
        rabbitmqctl add_user nova $rabbit_password
        rabbitmqctl set_user_tags nova administrator
        rabbitmqctl set_permissions -p / nova '.*' '.*' '.*'
        rabbitmqctl set_policy -p / ha-two  "." '{"ha-mode":"exactly","ha-params":2,"ha-sync-mode":"automatic"}'
    else
        systemctl restart rabbitmq-server
        #rabbitmqctl stop_app
        #rabbitmqctl join_cluster $first_node
        #rabbitmqctl start_app
    fi
}

## --------- Main ----------------
usage(){
    echo "USAGE:"
    echo "sh rabbitmq.sh delete"
    echo "sh rabbitmq.sh update cluster_nodes['rabbit@node-1',...]"
    echo "sh rabbitmq.sh add cluster_nodes['rabbit@node-1',...] bootstrap[true|false]"
}
action=$1
cluster_nodes=$2
bootstrap=$3
if [[ $action == "delete" ]];then
    if [ $# != 1 ] ; then usage;else
    delete_rabbitmq_nodes
    fi
elif [[ $action == "update" ]];then
    if [ $# != 2 ] ; then usage;else
    update_rabbitmq_config $cluster_nodes
    fi
elif [[ $action == "add" ]];then
    if [ $# != 3 ] ; then usage;else
    add_rabbitmq_nodes $cluster_nodes $bootstrap
    fi
else
    usage
fi
