#/usr/bin/python
# author: chengs
set -ex

INVENTORY="/tmp/yun_os/nodes.txt"
HAPROXY_BAK='/etc/haproxy/conf_bak.d/'
HAPROXY_DIR='/etc/haproxy/conf.d/'
HAPROXY_CFG='/etc/haproxy/haproxy.cfg'
HAPROXY_MYSQL_CFG=('110-mysqld.cfg' '111-mysqld-neutron.cfg' '112-mysqld-nova.cfg')
HAPROXY_RABBITMQ1_CFG='100-rabbitmq.cfg'
HAPROXY_RABBITMQ2_CFG='101-rabbitmq2.cfg'

backup_haproxy_confd(){
    if [ ! -d "$HAPROXY_BAK" ]; then
        mkdir -p $HAPROXY_BAK
        cp $HAPROXY_DIR/* $HAPROXY_BAK/
    fi
}
update_haproxy_cfg(){
    line_number=`cat $HAPROXY_CFG | grep -n maxconn | cut -d':' -f1 | head -1`
    sed -i "${line_number}s/^.*$/  maxconn  32000/g" $HAPROXY_CFG
}
update_haproxy_confd_files(){
    host_ips=""
    for ip in `cat $INVENTORY | egrep 'mariadb|rabbitmq' | awk '{print $1}'`;do
        host_ips="${host_ips}${ip}|"
    done
    host_ips=${host_ips%?}
    for line in `egrep -nri "$host_ips" $HAPROXY_DIR | cut -d':' -f1,2`;do
        file_lineno=(${line//:/ })
        file_path=${file_lineno[0]}
        line_number=${file_lineno[1]}
        line_content=`sed -n "${line_number}p" $file_path`
        [[ $line_content =~ "#" ]] || sed -i "${line_number}s/^/#/g" $file_path
    done
}
update_haproxy_mysql_rabbitmq_files(){
    # mariadb
    for file in ${HAPROXY_MYSQL_CFG[@]};do
        cp $HAPROXY_BAK/$file $HAPROXY_DIR/
        other_mysql_ips=""
        for ip in `cat $INVENTORY | egrep 'rabbitmq|controller' | awk '{print $1}'`;do
            other_mysql_ips="${other_mysql_ips}${ip}|"
        done
        other_mysql_ips=${other_mysql_ips%?}
        for line in `egrep -nri "$other_mysql_ips" $HAPROXY_DIR/$file | cut -d':' -f1`;do
            file_path=$HAPROXY_DIR/$file
            line_number=$line
            line_content=`sed -n "${line_number}p" $file_path`
            [[ $line_content =~ "#" ]] || sed -i "${line_number}s/^/#/g" $file_path
        done
        mariadb_active_ip=`cat $INVENTORY | egrep 'mariadb' | awk '{print $1}'|head -1`
        line_number=`egrep -nri "$mariadb_active_ip" $HAPROXY_DIR/$file | cut -d':' -f1`
        sed -i "${line_number}s/backup//g" $HAPROXY_DIR/$file

    done
    # rabbitmq1
    cp $HAPROXY_BAK/$HAPROXY_RABBITMQ1_CFG $HAPROXY_DIR/
    other_rabbitmq1_ips=""
    for ip in `cat $INVENTORY | egrep 'mariadb|controller|rabbitmq2' | awk '{print $1}'`;do
        other_rabbitmq1_ips="${other_rabbitmq1_ips}${ip}|"
    done
    other_rabbitmq1_ips=${other_rabbitmq1_ips%?}
    for line in `egrep -nri "$other_rabbitmq1_ips" $HAPROXY_DIR/$HAPROXY_RABBITMQ1_CFG | cut -d':' -f1`;do
        file_path=$HAPROXY_DIR/$HAPROXY_RABBITMQ1_CFG
        line_number=$line
        line_content=`sed -n "${line_number}p" $file_path`
        [[ $line_content =~ "#" ]] || sed -i "${line_number}s/^/#/g" $file_path
    done

    # rabbitmq2
    cp $HAPROXY_BAK/$HAPROXY_RABBITMQ1_CFG $HAPROXY_DIR/$HAPROXY_RABBITMQ2_CFG
    other_rabbitmq2_ips=""
    for ip in `cat $INVENTORY | egrep 'mariadb|controller|rabbitmq1' | awk '{print $1}'`;do
        other_rabbitmq2_ips="${other_rabbitmq2_ips}${ip}|"
    done
    other_rabbitmq2_ips=${other_rabbitmq2_ips%?}
    for line in `egrep -nri "$other_rabbitmq2_ips" $HAPROXY_DIR/$HAPROXY_RABBITMQ2_CFG | cut -d':' -f1`;do
        file_path=$HAPROXY_DIR/$HAPROXY_RABBITMQ2_CFG
        line_number=$line
        line_content=`sed -n "${line_number}p" $file_path`
        [[ $line_content =~ "#" ]] || sed -i "${line_number}s/^/#/g" $file_path
    done
    for line in `egrep -nri bind $HAPROXY_DIR/$HAPROXY_RABBITMQ2_CFG | cut -d':' -f1`;do
        sed -i "${line}s/5672/5673/g" $HAPROXY_DIR/$HAPROXY_RABBITMQ2_CFG
    done
}

## --- Main ---
backup_haproxy_confd
update_haproxy_cfg
update_haproxy_confd_files
update_haproxy_mysql_rabbitmq_files
