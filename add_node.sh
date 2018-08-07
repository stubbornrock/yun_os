#!/bin/bash

ETC_DIR="/etc/"
CONFIG_FILES=(
"$ETC_DIR/ceilometer/ceilometer.conf"
"$ETC_DIR/neutron/neutron.conf"
"$ETC_DIR/nova/nova.conf"
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
############################
# main functions
############################
_update_ntpd_conf(){
    local master_ip=`cat $ETC_DIR/astute.yaml | grep master_ip: | awk '{print $2}'`
    echo_warn "Update NTP ipaddr from $master_ip to $OLD_MASTER_IP"
    sed -i "s/$master_ip/$OLD_MASTER_IP/g" /etc/ntp.conf 
    # systemctl restart ntpd
}
_update_controller_ip(){
    local new_cluster_vip=`cat $ETC_DIR/astute.yaml | grep management_vip: | awk '{print $2}'`
    echo_warn "Update Controller vip from $new_cluster_vip to $OLD_CLUSTER_VIP"
    for file in ${CONFIG_FILES[@]};do
        if [[ -f $file ]];then
            _backup_file $file
            sed -i "s/$new_cluster_vip/$OLD_CLUSTER_VIP/g" $file
        fi
    done
}
_restart_all_services(){
    systemctl restart ntpd openstack-nova-compute openstack-ceilometer-compute neutron-openvswitch-agent
}

# ----- Main -----
OLD_CLUSTER_VIP=$1
OLD_MASTER_IP=$2
