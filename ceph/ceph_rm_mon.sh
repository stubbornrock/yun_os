#!/bin/bash
#set -x

INVENTORY="/tmp/yun_os/nodes.txt"
nodes(){
    local roles="$1"
    local field="$2" #1:management 2:pxe 3:storagepub 4:hostname 5:role
    if [[ $roles == "all" ]];then
        cat ${INVENTORY} | awk "{print \$${field}}" | sort | uniq
    else
        cat ${INVENTORY} | egrep -e "$roles" | awk "{print \$${field}}" | sort | uniq
    fi
}

remove_ceph_mon_node(){
    # delete ceph_mon
    for hostname in `nodes 'mariadb|rabbitmq' 4`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        echo "ceph mon rm $short_hostname"
        ceph mon rm $short_hostname
    done
}
remove_ceph_mon_node
