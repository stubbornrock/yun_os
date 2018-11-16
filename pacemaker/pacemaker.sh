#!/bin/bash

INVENTORY="/tmp/yun_os/nodes.txt"
COROSYNC_FILE='/etc/corosync/corosync.conf'
DATE=`date +%Y%m%d%H`

nodes(){
    local roles="$1"
    local field="$2" #1:management 2:pxe 3:storagepub 4:hostname 5:role
    if [[ $roles == "all" ]];then
        cat ${INVENTORY} | awk "{print \$${field}}" | sort | uniq
    else
        cat ${INVENTORY} | egrep -e "$roles" | awk "{print \$${field}}" | sort | uniq
    fi
}
_backup_file(){
    CFG=$1
    CFG_BAK=${CFG}.${DATE}
    if [ ! -f "$CFG_BAK" ]; then
        cp $CFG $CFG_BAK
    fi
}
stop_disable(){
    systemctl stop corosync pacemaker
    systemctl disable corosync pacemaker
}
update_conf_file(){
    _backup_file $COROSYNC_FILE
    for mgmt in `nodes 'rabbitmq|mariadb' 1`;do
        echo "corosync.conf remove node $mgmt"
        line_start=`grep -A 2 -B 2 -n "$mgmt" $COROSYNC_FILE |cut -d "-" -f 1 | head -1`
        line_end=`grep -A 2 -B 2 -n "$mgmt" $COROSYNC_FILE |cut -d "-" -f 1 | tail -1`
        test_end=`grep -A 2 -B 2 -n "10.0.0.1" $COROSYNC_FILE |cut -d "-" -f 1 | tail -1`
        if [[ "$line_start" != "" ]] && [[ "$line_end" != "" ]];then
            echo "corosync.conf remove node $mgmt"
            sed -i "${line_start},${line_end}d" $COROSYNC_FILE
        else
            echo "Node $mgmt not in corosync.conf"
        fi
    done
}
pacemaker_remove_node(){
    node_pxe_ip=$1
    # delete pacemaker node
    hostname=`nodes "$node_pxe_ip" 4`
    echo "pacemaker rm node $hostname"
    crm_node --remove=$hostname --force
}
check(){
    cat $COROSYNC_FILE | grep nodeid
    crm status
}
action=$1
pxe_ip=$2
if [[ $action == "remove" ]];then
    pacemaker_remove_node $pxe_ip
elif [[ $action == "disable" ]];then
    stop_disable
elif [[ $action == "update" ]];then
    update_conf_file
elif [[ $action == "check" ]];then
    check
fi
