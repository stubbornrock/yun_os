#!/bin/bash
INVENTORY="/tmp/yun_os/nodes.txt"

CONFIG_FILES=(
"/etc/aodh/aodh.conf"
"/etc/ceilometer/ceilometer.conf"
"/etc/cinder/cinder.conf"
"/etc/glance/glance-api.conf"
"/etc/heat/heat.conf"
"/etc/ironic/ironic.conf"
"/etc/keystone/keystone.conf"
"/etc/magnum/magnum.conf"
"/etc/neutron/neutron.conf"
"/etc/nova/nova.conf"
"/etc/sahara/sahara.conf"
"/etc/trove/trove.conf"
"/etc/trove/trove-taskmanager.conf"
"/etc/trove/trove-conductor.conf"
"/etc/trove/trove-guestagent.conf"
)
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
nodes(){
    local roles="$1"
    local field="$2" #1:management 2:pxe 3:storagepub 4:hostname 5:role
    if [[ $roles == "all" ]];then
        cat ${INVENTORY} | awk "{print \$${field}}" | sort | uniq
    else
        cat ${INVENTORY} | egrep -e "$roles" | awk "{print \$${field}}" | sort | uniq
    fi
}
############################
# backup functions
############################
DATE=`date +%Y%m%d%H`
_backup_file(){
    CFG=$1
    CFG_BAK=${CFG}.${DATE}
    if [ ! -f "$CFG_BAK" ]; then
        cp $CFG $CFG_BAK
    fi
}

RABBITMQ_HOSTS=""
generate_transport_url(){
    RABBITMQ_PORT=5672
    for ip in `nodes rabbitmq1 1`;do
        RABBITMQ_HOSTS="${RABBITMQ_HOSTS}${ip}:${RABBITMQ_PORT},"
    done
    RABBITMQ_HOSTS=${RABBITMQ_HOSTS%?}    
}

function add_rpc_transport(){
    generate_transport_url
    for file in ${CONFIG_FILES[@]};do
        echo_info "File $file [add] rpc rabbit_hosts=$RABBITMQ_HOSTS"
        if [[ -f $file ]];then
            _backup_file $file
            linenum=`cat $file | grep -n rabbit_hosts | grep -v "#" | cut -d ":" -f1`
            if [ "$linenum" -gt 0 ] 2>/dev/null ;then  
                sed -i "${linenum}s/^/#/g" $file
                linenum=`expr $linenum + 1`
                sed -i "${linenum}i rabbit_hosts = $RABBITMQ_HOSTS" $file 
            else
                echo_error "File $file rabbit_hosts option not Found!"
            fi
        fi
    done
}

function delete_rpc_transport(){
    for file in ${CONFIG_FILES[@]};do
        cp ${file}.${DATE} ${file}
    done
}

action=$1
if [[ $action == "add" ]];then
    add_rpc_transport
elif [[ $action == "delete" ]];then
    delete_rpc_transport
fi
