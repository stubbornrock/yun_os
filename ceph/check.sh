#!/bin/bash
CEPH_CONF="/etc/ceph/ceph.conf"

echo_warn(){
    echo -e "\033[33m$1\033[0m"
}
Note(){
    echo_warn "Check $1 ...."
}

check(){
    Note "/etc/ceph/ceph.conf"
    if [[ -f $CEPH_CONF ]];then
        egrep "^mon_initial_members|^mon_host" $CEPH_CONF    
    else
        echo "[INFO] No $CEPH_CONF File On this Host!"
    fi
}
check
