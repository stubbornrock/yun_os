#!/bin/bash
BOUND_NAME=${1:-bond1}
STORAGE_VLAN=${2:-114}
STORAGEPUB_VLAN=${3:-114}

OVS_PORT=ovs-${BOUND_NAME}
LINUX_BOUND=${BOUND_NAME}

# ------------ utils -------------
TMP_FILE=/tmp/tmp.txt
BACKUP_DIR=/tmp/interfaces/
_backup_interface_cfg(){
    mkdir -p $BACKUP_DIR
    CFG=$1
    CFG_NAME=${CFG##*/}
    CFG_BAK=$BACKUP_DIR/${CFG_NAME}.bak
    if [ ! -f "$CFG_BAK" ]; then
        if [ -f "$CFG" ]; then
            mv $CFG $CFG_BAK
        fi
    fi
}
_restore_interface_cfg(){
    CFG=$1
    CFG_NAME=${CFG##*/}
    CFG_BAK=$BACKUP_DIR/${CFG_NAME}.bak
    mv $CFG_BAK $CFG
}
_bonding_modprobe(){
    modprobe bonding
    modprobe -a 8021q
    lsmod | egrep 'bonding|8021q'
}
# ----------- methods ------------
_get_ovs_interfaces(){
    ovs-vsctl show > $TMP_FILE
    linenums=(`cat $TMP_FILE | grep -n Port | grep -A 1 \"$OVS_PORT\" | cut -d":" -f1`)
    line_str=""
    if [[ ${#linenums[@]} -eq 1 ]];then
        line_str="${linenums[0]},\$p"
    elif [[ ${#linenums[@]} -eq 2 ]];then
        line_str="${linenums[0]},${linenums[1]}p"
    else
        echo "No Port [$OVS_PORT] Found!";exit 0
    fi
    interfaces=(`sed -n "${line_str}" $TMP_FILE | grep Interface | awk '{print $2}'`)
    BOUND=$OVS_PORT
    ETH1=`echo ${interfaces[0]} | sed 's/\"//g'`
    ETH2=`echo ${interfaces[1]} | sed 's/\"//g'`
    rm -rf $TMP_FILE
    echo "Information:"
    echo $BOUND $ETH1 $ETH2
    #read -p "Are U to Change $BOUND from ovs to linux (y/n): " c
    #if [[ $c != "y" ]];then
    #    exit
    #fi
}

_generate_network_scripts(){
#------config  bond -------
echo "Generate /etc/sysconfig/network-scripts/ifcfg-$LINUX_BOUND"
#_backup_interface_cfg /etc/sysconfig/network-scripts/ifcfg-$LINUX_BOUND
cat << __EOT__ > /etc/sysconfig/network-scripts/ifcfg-$LINUX_BOUND
NAME=$LINUX_BOUND
DEVICE=$LINUX_BOUND
TYPE=Bond
BOOTPROTO=none
BONDING_MASTER=yes
DEFROUTE=yes
PEERDNS=yes
PEERROUTES=yes
IPV6INIT=no
USERCTL=no
ONBOOT=yes
NM_CONTROLLED=no
BONDING_OPTS="mode=1 miimon=100"
__EOT__

#------config  bond  vlan -------
echo "Generate /etc/sysconfig/network-scripts/ifcfg-${LINUX_BOUND}.${STORAGE_VLAN}"
STORAGE_IPADDR=`ifconfig br-storage | grep netmask | awk '{print $2}'`
STORAGE_NETMASK=`ifconfig br-storage | grep netmask | awk '{print $4}'`
cat << __EOT__ > /etc/sysconfig/network-scripts/ifcfg-${LINUX_BOUND}.${STORAGE_VLAN}
NAME=${LINUX_BOUND}.${STORAGE_VLAN}
DEVICE=${LINUX_BOUND}.${STORAGE_VLAN}
VLAN=yes
TYPE=Ethernet
BOOTPROTO=static
IPV6INIT=no
USERCTL=no
ONBOOT=yes
NM_CONTROLLED=no
IPADDR=$STORAGE_IPADDR
NETMASK=$STORAGE_NETMASK
__EOT__

echo "Generate /etc/sysconfig/network-scripts/ifcfg-${LINUX_BOUND}.${STORAGEPUB_VLAN}"
STORAGEPUB_IPADDR=`ifconfig br-storagepub | grep netmask | awk '{print $2}'`
STORAGEPUB_NETMASK=`ifconfig br-storagepub | grep netmask | awk '{print $4}'`
cat << __EOT__ > /etc/sysconfig/network-scripts/ifcfg-${LINUX_BOUND}.${STORAGEPUB_VLAN}
NAME=${LINUX_BOUND}.${STORAGEPUB_VLAN}
DEVICE=${LINUX_BOUND}.${STORAGEPUB_VLAN}
VLAN=yes
TYPE=Ethernet
BOOTPROTO=static
IPV6INIT=no
USERCTL=no
ONBOOT=yes
NM_CONTROLLED=no
IPADDR=$STORAGEPUB_IPADDR
NETMASK=$STORAGEPUB_NETMASK
__EOT__

#------config  card  1 -------
echo "Generate /etc/sysconfig/network-scripts/ifcfg-$ETH1"
_backup_interface_cfg /etc/sysconfig/network-scripts/ifcfg-$ETH1
cat << __EOT__ > /etc/sysconfig/network-scripts/ifcfg-$ETH1
NAME=$ETH1
DEVICE=$ETH1
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
MASTER=$LINUX_BOUND
SLAVE=yes
IPV6INIT=no
USERCTL=no
ONBOOT=yes
__EOT__

#------config  card  2 -------
echo "Generate /etc/sysconfig/network-scripts/ifcfg-$ETH2"
_backup_interface_cfg /etc/sysconfig/network-scripts/ifcfg-$ETH2
cat << __EOT__ > /etc/sysconfig/network-scripts/ifcfg-$ETH2
NAME=$ETH2
DEVICE=$ETH2
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
MASTER=$LINUX_BOUND
SLAVE=yes
IPV6INIT=no
USERCTL=no
ONBOOT=yes
__EOT__
}
_clear_ovs_bridge(){
    ovs-vsctl del-br br-storage
    ovs-vsctl del-br br-storagepub
    ovs-vsctl del-br br-$OVS_PORT
    _backup_interface_cfg /etc/sysconfig/network-scripts/ifcfg-br-storage
    _backup_interface_cfg /etc/sysconfig/network-scripts/ifcfg-br-storagepub
}

# ----- Main -----
_get_ovs_interfaces
run(){
    _bonding_modprobe
    _generate_network_scripts
    _clear_ovs_bridge
    systemctl restart network
}
restore(){
    _restore_interface_cfg /etc/sysconfig/network-scripts/ifcfg-$LINUX_BOUND
    _restore_interface_cfg /etc/sysconfig/network-scripts/ifcfg-$ETH1
    _restore_interface_cfg /etc/sysconfig/network-scripts/ifcfg-$ETH2
    _restore_interface_cfg /etc/sysconfig/network-scripts/ifcfg-br-storage
    _restore_interface_cfg /etc/sysconfig/network-scripts/ifcfg-br-storagepub
    rm -rf /etc/sysconfig/network-scripts/ifcfg-${LINUX_BOUND}.${STORAGE_VLAN}
    rm -rf /etc/sysconfig/network-scripts/ifcfg-${LINUX_BOUND}.${STORAGEPUB_VLAN}
}

run
