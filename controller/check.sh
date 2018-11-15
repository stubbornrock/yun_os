#!/bin/bash
INVENTORY="/tmp/yun_os/nodes.txt"
HAPROXY_DIR='/etc/haproxy/conf.d/'

echo_warn(){
    echo -e "\033[33m$1\033[0m"
}
Note(){
    echo_warn "Check $1 ...."
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

check(){
    # mariadb_rabbitmq host ipaddress
    host_ips=""
    for ip in `nodes 'mariadb|rabbitmq' 1`;do
        host_ips="${host_ips}${ip}|"
    done
    host_ips=${host_ips%?}
    
    # check haproxy
    Note "Controller Haproxy Files"
    grep -nri "#" $HAPROXY_DIR | egrep -v 'mysqld|rabbitmq'
    Note "Mysqld/Rabbitmq Haproxy Files"
    grep -v -nri "#" $HAPROXY_DIR | egrep 'mysqld|rabbitmq'

    # check pacemaker
    Note "Mysqld/Rabbitmq Pacemaker Resources"
    crm configure show | egrep -nri "$host_ips"

    # check neutron-l3
    Note "Controller Neutron-l3 Status"
    systemctl status neutron-l3-agent
}
check
