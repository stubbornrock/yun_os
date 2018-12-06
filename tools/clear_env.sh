delete_nodes(){
    for id in `roller node | awk '{print $1}'| sed '1,2d'`;do
        roller node --node-id $id --delete-from-db
        cobbler system remove --name=node-$id
    done
    cobbler sync
}

reset_id(){
    export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
    psql -U nailgun nailgun -h localhost -c "ALTER SEQUENCE nodes_id_seq RESTART WITH 1;"
}

check(){
    roller node
    cobbler system list
    export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
    psql -U nailgun nailgun -h localhost -c "\d nodes_id_seq"
    sql="SELECT name,first,last FROM network_groups LEFT OUTER JOIN ip_addr_ranges ON network_groups.id=ip_addr_ranges.network_group_id;"
   psql -U nailgun nailgun -h localhost -c "$sql"
}

delete_nodes
reset_id
check

