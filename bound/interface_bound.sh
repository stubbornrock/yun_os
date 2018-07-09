#!/bin/bash
TMP_FILE=tmp.txt
PORT=bond0

input(){
    BOUND=$bound
    ETH1=$eth1
    ETH2=$eth2
    MODE=$mode
    IP=$ip
    PREFIX=$prefix
    GATE=$gate
}

get_ovs_interfaces(){
    ovs-vsctl show > $TMP_FILE
    linenums=(`cat $TMP_FILE | grep -n Port | grep -A 1 $PORT | cut -d":" -f1`)
    line_str=""
    if [[ ${#linenums[@]} -eq 1 ]];then
        line_str="${linenums[0]},\$p"
    elif [[ ${#linenums[@]} -eq 2 ]];then
        line_str="${linenums[0]},${linenums[1]}p"
    else
        echo "No Port [$PORT] Found!";exit
    fi
    interfaces=(`sed -n "${line_str}" $TMP_FILE | grep Interface | awk '{print $2}'`)
    BOUND=$PORT
    ETH1=`echo ${interfaces[0]} | sed 's/\"//g'`
    ETH2=`echo ${interfaces[1]} | sed 's/\"//g'`
    rm -rf $TMP_FILE
    #echo $BOUND $ETH1 $ETH2
}

bonding_modprobe(){
    modprobe bonding
    #lsmod | grep bonding
}

generate_network_scripts(){
cat << __EOT__ > /etc/sysconfig/network-scripts/ifcfg-$BOUND
DEVICE=$BOUND
TYPE=Bond
NAME=$BOUND
BONDING_MASTER=yes
BOOTPROTO=static
USERCTL=no
ONBOOT=yes
IPADDR=$IP
PREFIX=$PREFIX
GATEWAY=$GATE
BONDING_OPTS="mode=$MODE miimon=100"
__EOT__

cat << __EOT__ > /etc/sysconfig/network-scripts/ifcfg-$ETH1
TYPE=Ethernet
BOOTPROTO=none
DEVICE=$ETH1
ONBOOT=yes
MASTER=$BOUND
SLAVE=yes
__EOT__

cat << __EOT__ > /etc/sysconfig/network-scripts/ifcfg-$ETH2
TYPE=Ethernet
BOOTPROTO=none
DEVICE=$ETH2
ONBOOT=yes
MASTER=$BOUND
SLAVE=yes
__EOT__
}

#input
#bonding_modprobe
#generate_network_scripts
#systemctl restart network
get_ovs_interfaces
