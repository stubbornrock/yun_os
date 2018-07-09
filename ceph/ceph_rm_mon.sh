#!/bin/bash
#set -x

INVENTORY="/tmp/yun_os/nodes.txt"

remove_ceph_mon_node(){
    # delete ceph_mon
    for hostname in `cat ${INVENTORY} | egrep 'mariadb|rabbitmq' | awk '{print $4}'`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        echo "ceph mon rm $short_hostname"
        ceph mon rm $short_hostname
    done
}
remove_ceph_mon_node
