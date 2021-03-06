#!/bin/bash
NEUTRON_CFG="/etc/neutron/neutron.conf"
DHCP_CFG="/etc/neutron/dhcp_agent.ini"

DATE=`date +%Y%m%d%H`
_backup_file(){
    CFG=$1
    CFG_BAK=${CFG}.${DATE}
    if [ ! -f "$CFG_BAK" ]; then
        cp $CFG $CFG_BAK
    fi
}

_rpc_response_timeout(){
    _backup_file $NEUTRON_CFG
    egrep -n "^rpc_response_timeout" $NEUTRON_CFG
    if [[ $? -ne 0 ]];then
        echo "File $NEUTRON_CFG rpc_response_timeout need to add"
        linenum=`cat $NEUTRON_CFG | grep -n "#rpc_response_timeout" | cut -d ":" -f1`
        if [ "$linenum" -gt 0 ] 2>/dev/null ;then
            linenum=`expr $linenum + 1`
            sed -i "${linenum}i rpc_response_timeout=600" $NEUTRON_CFG
        fi
    else
        echo "File $NEUTRON_CFG rpc_response_timeout need to update"
        sed -i "s/^rpc_response_timeout.*/rpc_response_timeout=600/" $NEUTRON_CFG
    fi 
}
_force_metadata(){
    _backup_file $DHCP_CFG
    egrep -n "^force_metadata" $DHCP_CFG
    if [[ $? -ne 0 ]];then
        echo "File $DHCP_CFG force_metadata need to add"
        linenum=`cat $DHCP_CFG | grep -n "^#force_metadata" | cut -d ":" -f1`
        if [ "$linenum" -gt 0 ] 2>/dev/null ;then
            linenum=`expr $linenum + 1`
            sed -i "${linenum}i force_metadata=True" $DHCP_CFG
        fi
    else
        echo "File $DHCP_CFG force_metadata need to update"
        sed -i "s/^force_metadata.*/force_metadata=True/" $DHCP_CFG
    fi
}
_dhcp_agents_per_network(){
    _backup_file $NEUTRON_CFG
    egrep -n "^dhcp_agents_per_network" $NEUTRON_CFG
    if [[ $? -ne 0 ]];then
        echo "File $NEUTRON_CFG dhcp_agents_per_network need to add"
        linenum=`cat $NEUTRON_CFG | grep -n "^#dhcp_agents_per_network" | cut -d ":" -f1`
        if [ "$linenum" -gt 0 ] 2>/dev/null ;then
            linenum=`expr $linenum + 1`
            sed -i "${linenum}i dhcp_agents_per_network=3" $NEUTRON_CFG
        fi
    else
        echo "File $NEUTRON_CFG dhcp_agents_per_network need to update"
        sed -i "s/^dhcp_agents_per_network.*/dhcp_agents_per_network=3/" $NEUTRON_CFG
    fi
}

_rpc_response_timeout
_force_metadata
_dhcp_agents_per_network
