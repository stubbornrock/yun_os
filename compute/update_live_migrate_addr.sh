#!/bin/bash
INVENTORY="/tmp/yun_os/nodes.txt"
HOSTNAME=`hostname`
STORAGEPUB=""
NOVA_CFG="/etc/nova/nova.conf"
DATE=`date +%Y%m%d%H`

############################
# common functions
############################
echo_info(){
    echo -e "\033[32m$1\033[0m"
}
echo_error(){
    echo -e "\033[31m$1\033[0m"
}
echo_warn(){
    echo -e "\033[33m$1\033[0m"
}

############################
# backup functions
############################
_backup_file(){
    CFG=$1
    CFG_BAK=${CFG}.${DATE}
    if [ ! -f "$CFG_BAK" ]; then
        cp $CFG $CFG_BAK
    fi
}

############################
# main functions
############################
nodes(){
    local roles="$1"
    local field="$2" #1:management 2:pxe 3:storagepub 4:hostname 5:role
    if [[ $roles == "all" ]];then
        cat ${INVENTORY} | awk "{print \$${field}}" | sort | uniq
    else
        cat ${INVENTORY} | egrep -e "$roles" | awk "{print \$${field}}" | sort | uniq
    fi
}
function get_storagepub_addr(){
    STORAGEPUB=`nodes $HOSTNAME 3|head -1`
}

function update_live_migrate_addr(){
    get_storagepub_addr
    echo_info "File $NOVA_CFG update live_migration_inbound_addr=$STORAGEPUB"
    if [[ -f $NOVA_CFG ]];then
        _backup_file $NOVA_CFG
        echo_info "live_migration_inbound_addr value:"
        egrep -n "^live_migration_inbound_addr" $NOVA_CFG
        if [[ $? -ne 0 ]];then
            linenum=`cat $NOVA_CFG | egrep -n "^#live_migration_inbound_addr" | cut -d ":" -f1`
            if [ "$linenum" -gt 0 ] 2>/dev/null ;then
                echo_info "File $NOVA_CFG option live_migration_inbound_addr need add!"
                linenum=`expr $linenum + 1`
                sed -i "${linenum}i live_migration_inbound_addr=$STORAGEPUB" $NOVA_CFG
            else
                echo_error "File $NOVA_CFG option #live_migration_inbound_addr not Found!"
            fi
        else
            echo_warn "File $NOVA_CFG option live_migration_inbound_addr need update!"
            sed -i "s/^live_migration_inbound_addr.*/live_migration_inbound_addr=$STORAGEPUB/" $NOVA_CFG
        fi
    else
        echo_warn "Host $HOSTNAME has no $NOVA_CFG"
    fi
}
function check_live_migrate_addr(){
    if [[ -f $NOVA_CFG ]];then
        egrep -n "^live_migration_inbound_addr" $NOVA_CFG
    else
        echo_warn "Host $HOSTNAME has no $NOVA_CFG"
    fi
}

function restore_live_migrate_addr(){
    cp ${NOVA_CFG}.${DATE} ${NOVA_CFG}
}

action=$1
if [[ $action == "add" ]];then
    update_live_migrate_addr
elif [[ $action == "check" ]];then
    check_live_migrate_addr
elif [[ $action == "delete" ]];then
    restore_live_migrate_addr
fi
