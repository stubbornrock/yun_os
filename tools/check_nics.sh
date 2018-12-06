#!/bin/bash
set -e
check(){
    echo "UP interfaces:"
    sql="SELECT node_id,name,state FROM node_nic_interfaces WHERE state='up' AND node_id=$1;"
    psql -U nailgun nailgun -h localhost -c "$sql"
    echo "Bond interfaces:"
    sql="SELECT node_nic_interfaces.node_id,node_nic_interfaces.name,node_nic_interfaces.state,node_bond_interfaces.name FROM node_nic_interfaces RIGHT OUTER JOIN node_bond_interfaces ON node_nic_interfaces.parent_id = node_bond_interfaces.id WHERE node_nic_interfaces.node_id=$1;"
    psql -U nailgun nailgun -h localhost -c "$sql"
}

# -------------------- Main -----------------------
usage="USAGE:
./check_nics.sh 2    # check node nic status
./check_nics.sh 2 10 # check node 2-10 status"

if [[ $# -eq 1 ]];then
    export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
    id=$1
    check $id
elif [[ $# -eq 2 ]];then
    export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
    start_id=$1
    end_id=$2
    for id in `seq $start_id $end_id`;do
        echo "-------------------------------------------node-$id"
        check $id
    done
else
    echo "$usage"
fi
