#!/bin/bash
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

TRANSPORT_URL=""
generate_transport_url(){
    rabbit_host=`egrep ^rabbit_host /etc/nova/nova.conf | cut -d'=' -f2 | cut -d':' -f1`
    rabbit_user='nova'
    rabbit_port=5673
    rabbit_password=`egrep ^rabbit_password /etc/nova/nova.conf | cut -d'=' -f2`
    TRANSPORT_URL="rabbit://${rabbit_user}:${rabbit_password}@${rabbit_host}:${rabbit_port}/"
}

function add_notification_transport(){
    generate_transport_url
    for file in ${CONFIG_FILES[@]};do
        if [[ -f $file ]];then
            egrep -i ^notification_transport_url $file
            if [[ $? -eq 1 ]];then
                echo "File $file [add] notification_transport_url=$TRANSPORT_URL"
                linenum=`egrep -n "^\[DEFAULT\]" $file | cut -d':' -f1`
                linenum=`expr $linenum + 1`
                sed -i "${linenum}i notification_transport_url=$TRANSPORT_URL" $file
            else
                echo "File $file [update] notification_transport_url=$TRANSPORT_URL"
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
