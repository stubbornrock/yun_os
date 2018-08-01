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
    for ip in `cat ${INVENTORY} | egrep 'rabbitmq1' | awk '{print $1}'`;do
        RABBITMQ_HOSTS="${RABBITMQ_HOSTS}${ip}:${RABBITMQ_PORT},"
    done
    RABBITMQ_HOSTS=${RABBITMQ_HOSTS%?}    
}

function add_rpc_transport(){
    generate_transport_url
    for file in ${CONFIG_FILES[@]};do
        echo "File $file [add] rpc rabbit_hosts=$RABBITMQ_HOSTS"
        if [[ -f $file ]];then
            _backup_file $file
            linenum=`cat $file | grep -n rabbit_hosts | grep -v "#" | cut -d ":" -f1`
            if [ "$linenum" -gt 0 ] 2>/dev/null ;then  
                sed -i "${linenum}s/^/#/g" $file
                linenum=`expr $linenum + 1`
                sed -i "${linenum}i rabbit_hosts = $RABBITMQ_HOSTS" $file 
            else
                echo "File $file rabbit_hosts option not Found!"
            fi
        else
            echo "Host has no $file!"
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
