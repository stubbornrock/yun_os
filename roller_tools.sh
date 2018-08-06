#!/bin/bash
echo_info(){
    echo -e "\033[32m$1\033[0m"
}
echo_error(){
    echo -e "\033[31m$1\033[0m"
}
echo_warn(){
    echo -e "\033[33m$1\033[0m"
}

_delete_node(){
    id=$1
    echo_warn "Delete node-$id from database ..."
    roller node --node-id $id --delete-from-db
    roller node | grep node-$id
    echo_warn "Delete node-$id from cobbler ..."
    cobbler system remove --name node-$id
    cobbler sync
    cobbler system list | grep node-$id
}
_node_ready(){
    export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
    echo_warn "Update node state form error to ready ..."
    sql="UPDATE nodes SET status='ready' WHERE id in (SELECT id FROM nodes WHERE status='error')"
    psql -U nailgun nailgun -h localhost -c "$sql"
}

_update_start_id(){
    id=$1
    export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
    #echo $PGPASSWORD
    echo_warn "Update roller node id start from $id  ..."
    psql -U nailgun nailgun -h localhost -c "ALTER SEQUENCE nodes_id_seq RESTART WITH $id;"
    psql -U nailgun nailgun -h localhost -c "\d nodes_id_seq"
}

_truncate_ip_addrs(){
   export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
   #echo $PGPASSWORD
   echo_warn "Truncate table ip_addrs ..."
   psql -U nailgun nailgun -h localhost -c "TRUNCATE ip_addrs;"
   psql -U nailgun nailgun -h localhost -c "SELECT * FROM ip_addrs;"
   ##
   #roller deployment --env 1 --default
}


_update_ip_range(){
   network=$1
   iprange=$2
   validate_network $network
   export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
   #echo $PGPASSWORD
   echo_warn "Update cluster network $netowrk iprange $iprange  ..."
   echo $iprange | grep "^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$" > /dev/null
   if [[ $? -eq 0 ]];then
       sql="UPDATE ip_addr_ranges SET first='$iprange' WHERE network_group_id in (SELECT id FROM network_groups where name='$network');" 
       psql -U nailgun nailgun -h localhost -c "$sql"
   fi
   sql="SELECT name,first,last FROM network_groups LEFT OUTER JOIN ip_addr_ranges ON network_groups.id=ip_addr_ranges.network_group_id;"
   psql -U nailgun nailgun -h localhost -c "$sql"
}

# ------------------------- Main -----------------------
validate_action(){
    local action=$1
    local result=false
    actions=("delete-node" "start-id" "ip-range" "ready-node" "truncate-node-ips")
    for a in ${actions[@]};do
        if [[ $a == $action ]];then result=true;break;fi
    done
    if ! $result;then usage;exit 1;fi
}

validate_network(){
    local action=$1
    local result=false
    actions=("storage" "storagepub" "management" "vxlan")
    actions_str=""
    for a in ${actions[@]};do
        if [[ $a == $action ]];then result=true;break;fi
    done
    if ! $result;then 
        echo_warn "Only Support storage|storagepub|management|vxlan";exit 1
    fi
}

usage(){
    echo_info "Usage:"
    echo_info "  sh roller_tool.sh delete-node nodeid"
    echo_info "  sh roller_tool.sh ready-node"
    echo_info "  sh roller_tool.sh truncate-node-ips"
    echo_info "  sh roller_tool.sh start-id nodeid"
    echo_info "  sh roller_tool.sh ip-range network ipaddr"
}

action=$1
validate_action $action
if [[ $action == "delete-node" ]];then
    _delete_node $2
elif [[ $action == "ready-node" ]];then
    _node_ready
elif [[ $action == "truncate-node-ips" ]];then
    _truncate_ip_addrs
elif [[ $action == "start-id" ]];then
    _update_start_id $2
elif [[ $action == "ip-range" ]];then
    _update_ip_range $2 $3
else
    usage;
fi
