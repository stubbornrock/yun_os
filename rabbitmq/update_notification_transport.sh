#!/bin/bash
INVENTORY="/tmp/yun_os/nodes.txt"

CONFIG_FILES=(
"/etc/aodh/aodh.conf"
"/etc/ceilometer/ceilometer.conf"
"/etc/cinder/cinder.conf"
"/etc/glance/glance-registry.conf"
"/etc/glance/glance-api.conf"
"/etc/heat/heat.conf"
"/etc/ironic/ironic.conf"
"/etc/keystone/keystone.conf"
"/etc/magnum/magnum.conf"
"/etc/neutron/neutron.conf"
"/etc/nova/nova.conf"
"/etc/sahara/sahara.conf"
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

TRANSPORT_URL="rabbit://"
generate_transport_url(){
    #rabbit_host=`egrep ^rabbit_host /etc/nova/nova.conf | cut -d'=' -f2 | cut -d':' -f1`
    rabbit_user='nova'
    rabbit_port=5672
    rabbit_password=`egrep ^rabbit_password /etc/nova/nova.conf | cut -d'=' -f2`
    for ip in `nodes rabbitmq2 1`;do
        TRANSPORT_URL="${TRANSPORT_URL}${rabbit_user}:${rabbit_password}@${ip}:${rabbit_port},"
    done
    TRANSPORT_URL=${TRANSPORT_URL%?}
    TRANSPORT_URL=${TRANSPORT_URL}/
}

function add_notification_transport(){
    generate_transport_url
    for file in ${CONFIG_FILES[@]};do
        if [[ -f $file ]];then
            _backup_file $file
            egrep -i ^notification_transport_url $file
            if [[ $? -eq 1 ]];then
                echo_info "File $file [add] notification_transport_url=$TRANSPORT_URL"
                linenum=`egrep -n "^\[DEFAULT\]" $file | cut -d':' -f1`
                linenum=`expr $linenum + 1`
                sed -i "${linenum}i notification_transport_url=$TRANSPORT_URL" $file
            else
                echo_warn "File $file [update] notification_transport_url=$TRANSPORT_URL"
                sed -i "s#^notification_transport_url.*#notification_transport_url=$TRANSPORT_URL#g" $file
            fi
        fi
    done
}

function delete_notification_transport(){
    for file in ${CONFIG_FILES[@]};do
        echo "File $file [delete] notification_transport_url"
        linenum=`egrep -ni ^notification_transport_url $file | cut -d':' -f1`
        sed -i "${linenum}d" $file
    done
}

action=$1
if [[ $action == "add" ]];then
    add_notification_transport
elif [[ $action == "delete" ]];then
    delete_notification_transport
fi
