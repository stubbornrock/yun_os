#!/bin/bash
# author: chengs
set -x

INVENTORY='/tmp/yun_os/nodes.txt'
HAPROXY_BAK='/etc/haproxy/conf_bak.d/'
HAPROXY_DIR='/etc/haproxy/conf.d/'
ETC_MY_CNF='/etc/my.cnf.d/galera.cnf'
ETC_MY_CNF_BAK='/etc/my.cnf.d/galera.cnf.bak'

backup_haproxy_confd(){
    #1.prepare haproxy cfg
    if [ ! -d "$HAPROXY_BAK" ]; then
        mkdir -p $HAPROXY_BAK
        cp $HAPROXY_DIR/* $HAPROXY_BAK/
    fi
    rm -rf $HAPROXY_DIR/*
    #cp $HAPROXY_BAK/$HAPROXY_MYSQL_CFG $HAPROXY_DIR
}

update_my_cnf(){
    cp $ETC_MY_CNF $ETC_MY_CNF_BAK
    cluster_nodes=""
    for mgmt_ip in `cat $INVENTORY | egrep 'mariadb' | awk '{print $1}'`;do
        cluster_nodes="${cluster_nodes}${mgmt_ip}:4567,"
    done
    cluster_nodes=${cluster_nodes%?}
    sed -i "s/^max_connections=.*$/max_connections=18000/g" $ETC_MY_CNF
    sed -i "s/^wait_timeout=.*$/wait_timeout=1800/g" $ETC_MY_CNF
    sed -i "s/^wsrep_cluster_address=.*$/wsrep_cluster_address=\"gcomm:\/\/${cluster_nodes}?pc.wait_prim=no\"/g" $ETC_MY_CNF
}
run(){
    bootstrap=$1
    if $bootstrap;then
        while :
        do 
            grep -n safe_to_bootstrap /var/lib/mysql/grastate.dat
            if [[ $? -ne 0 ]];then
                echo "Add safe_to_bootstrap: 1 to /var/lib/mysql/grastate.dat"
                echo "safe_to_bootstrap: 1" >> /var/lib/mysql/grastate.dat
                sleep 5
            else
                break
            fi
        done
        is_exist=`ps -ef | grep -c wsrep-new-cluster`
        if [[ $is_exist -lt 2 ]];then
            /usr/libexec/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib64/mysql/plugin --user=mysql --wsrep-new-cluster &
            sleep 10
            ps -ef | grep /usr/libexec/mysqld
        else
            pkill -9 mysqld
            systemctl restart mariadb
        fi
    else
        systemctl restart mariadb
    fi
}

## --- Main ---
backup_haproxy_confd
update_my_cnf
run $1
