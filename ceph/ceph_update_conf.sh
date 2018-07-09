#!/bin/bash

INVENTORY="/tmp/yun_os/nodes.txt"
CEPH_CONF="/etc/ceph/ceph.conf"

update_ceph_conf(){
    ceph_mon_nodes=""
    for hostname in `cat ${INVENTORY} | egrep 'controller' | awk '{print $4}'`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        ceph_mon_nodes="${ceph_mon_nodes}${short_hostname} "
    done
    ceph_mon_nodes=${ceph_mon_nodes%?}
    #echo $ceph_mon_nodes
    sed -i "s/^mon_initial_members.*/mon_initial_members = $ceph_mon_nodes/g" $CEPH_CONF
    
    ceph_mon_publicip=""
    for publicip in `cat ${INVENTORY} | egrep 'controller' | awk '{print $3}'`;do
        ceph_mon_publicip="${ceph_mon_publicip}${publicip} "
    done
    sed -i "s/^mon_host.*/mon_host = $ceph_mon_publicip/g" $CEPH_CONF
}
update_ceph_conf
