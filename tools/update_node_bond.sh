NODE_ID=$1
BOND_NAME=$2
NIC_1=$3
NIC_2=$4

if [[ $# -ne 4 ]];then
    echo "./update_node_bond.sh NODE_ID BOND_NAME NIC_NAME1 NIC_NAME2"
else
    read -p "update node-$NODE_ID [$NIC_1 and $NIC_2] to $BOND_NAME ?(y/n) :" p
    if [[ $p != "y" ]];then
        exit
    fi
    export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
    
    #check bond id
    sql="SELECT id FROM node_bond_interfaces WHERE name='$BOND_NAME' AND node_id=$NODE_ID;"
    bond_id=`psql -U nailgun nailgun -h localhost -c "$sql"`
    
    #delete old interfaces
    sql="DELETE FROM node_nic_interfaces WHERE parent_id=$bond_id;"
    psql -U nailgun nailgun -h localhost -c "$sql"

    #add new interfaces
    sql="UPDATE node_nic_interfaces SET parent_id=$bond_id WHERE node_id=$NODE_ID AND name in ($NIC_1,$NIC_2)"
    psql -U nailgun nailgun -h localhost -c "$sql"
fi
