#!/bin/bash
INVENTORY="/tmp/yun_os/nodes.txt"
HOSTNAME=`hostname`
STORAGEPUB=""
NOVA_CFG="/etc/nova/nova.conf"
DATE=`date +%Y%m%d%H`

_backup_file(){
    CFG=$1
    CFG_BAK=${CFG}.${DATE}
    if [ ! -f "$CFG_BAK" ]; then
        cp $CFG $CFG_BAK
    fi
}

function get_storagepub_addr(){
    STORAGEPUB=`cat $INVENTORY | grep $HOSTNAME | awk '{print $3}'`
}

function update_live_migrate_addr(){
    generate_storagepub_addr
    echo "File $NOVA_CFG [update] live_migration_inbound_addr=$STORAGEPUB"
    if [[ -f $NOVA_CFG ]];then
        _backup_file $NOVA_CFG
        egrep -n "^live_migration_inbound_addr" $NOVA_CFG
        if [[ $? -ne 0 ]];then
            linenum=`cat $NOVA_CFG | egrep -n "^#live_migration_inbound_addr" | cut -d ":" -f1`
            linenum=`expr $linenum + 1`
            sed -i "${linenum}i live_migration_inbound_addr=$STORAGEPUB" $NOVA_CFG
        else
            echo "File $NOVA_CFG live_migration_inbound_addr has Added!"
        fi
    else
        echo "Host has no $file"
    fi
}

function restore_live_migrate_addr(){
    cp ${NOVA_CFG}.${DATE} ${NOVA_CFG}
}

action=$1
if [[ $action == "add" ]];then
    update_live_migrate_addr
elif [[ $action == "delete" ]];then
    restore_live_migrate_addr
fi
