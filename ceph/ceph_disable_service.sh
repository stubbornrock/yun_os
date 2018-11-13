#!/bin/bash

CEPH_SERVICES=("ceph.target"\ 
               "ceph-mds.target"\ 
               "ceph-mon.target"\ 
               "ceph-osd.target"\ 
               "ceph-mds.target"\ 
               "ceph-radosgw.target"\ 
               "ceph-radosgw\\@radosgw.gateway")

disable_services(){
    for s in ${CEPH_SERVICES[@]};do
        echo "systemctl stop $s;systemctl disable $s"
        systemctl stop $s;systemctl disable $s
        short_hostname=`hostname -s`
        mon_service="ceph-mon@${short_hostname}.service"
        echo "systemctl stop $mon_service;systemctl disable $mon_service"
        systemctl stop $mon_service;systemctl disable $mon_service
    done
}

check_services(){
    for s in ${CEPH_SERVICES[@]};do
        systemctl status $s | egrep 'Active:|.service'
        short_hostname=`hostname -s`
        mon_service="ceph-mon@${short_hostname}.service"
        systemctl status $mon_service | egrep 'Active:|.service'
    done
}

action=$1
if [[ $action  == "disable" ]];then
    disable_services
elif [[ $action  == "check" ]];then
    check_services
fi
