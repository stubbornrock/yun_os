#!/bin/bash

INVENTORY="/tmp/yun_os/nodes.txt"
CEPH_CONF="/etc/ceph/ceph.conf"

nodes(){
    local roles="$1"
    local field="$2" #1:management 2:pxe 3:storagepub 4:hostname 5:role
    if [[ $roles == "all" ]];then
        cat ${INVENTORY} | awk "{print \$${field}}" | sort | uniq
    else
        cat ${INVENTORY} | egrep -e "$roles" | awk "{print \$${field}}" | sort | uniq
    fi
}

update_ceph_conf(){
    ceph_mon_nodes=""
    for hostname in `nodes controller 4`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        ceph_mon_nodes="${ceph_mon_nodes}${short_hostname} "
    done
    ceph_mon_nodes=${ceph_mon_nodes%?}
    #echo $ceph_mon_nodes
    sed -i "s/^mon_initial_members.*/mon_initial_members = $ceph_mon_nodes/g" $CEPH_CONF
    
    ceph_mon_publicip=""
    for publicip in `nodes controller 3`;do
        ceph_mon_publicip="${ceph_mon_publicip}${publicip} "
    done
    #echo "$ceph_mon_publicip"
    sed -i "s/^mon_host.*/mon_host = $ceph_mon_publicip/g" $CEPH_CONF
}
update_ceph_conf
