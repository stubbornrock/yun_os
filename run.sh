#!/bin/bash
#set -x

DEST_DIR="/tmp/yun_os/"

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
Note(){
    echo_warn "############## $1 ############"
}
nodes(){
    local roles="$1"
    local field="$2" #1:management 2:pxe 3:storagepub 4:hostname 5:role
    if [[ $roles == "all" ]];then
        cat nodes.txt | awk "{print \$${field}}" | sort | uniq
    else
        cat nodes.txt | egrep -e "$roles" | awk "{print \$${field}}" | sort | uniq
    fi
}
############################
# prepare
############################
function _check_nodes(){
    printf "%-15s %2s\n" "NODE" "NUM"
    for node_role in `nodes "all" 5`;do
        node_num=`cat nodes.txt | grep $node_role | wc -l`
        printf "%-15s %2s\n" $node_role $node_num
    done
    echo_warn "Are Node's roles and numbers correct in nodes.txt?"
    read -p "Y/N?:" is_ok
    if [[ $is_ok != "Y" ]];then exit 0;fi
}
function _copy_files(){
    for pxe_ip in `nodes "all" 2`;do
        echo_info "***** Copy update scripts to :[$pxe_ip] *****"
        ssh $pxe_ip "mkdir -p $DEST_DIR;rm -rf $DEST_DIR/*"
        scp -r ./* $pxe_ip:$DEST_DIR/
    done
}
function _sync_time(){
    for pxe_ip in `nodes "all" 2`;do
        echo_info "***** Sync [$pxe_ip] time to Roller *****"
        d=`date | awk '{print $4}'`
        ssh $pxe_ip "date -s $d"
    done
}
prepare(){
    Note "Prepare infos before to split controller/mongo/mariadb"
    #_sync_time
    _copy_files
}

############################
# controller service
############################
function _controller_clear_pacemaker_resources(){
    Note "Exec clear pacemaker resources & controller services"
    pxe_ip=`nodes controller 2|head -1`
    ssh $pxe_ip "sh $DEST_DIR/controller/controller_clear_ra.sh"
}
function _controller_update_haproxy_files(){
    Note "Prepare haproxy files for all services"
    for pxe_ip in `nodes controller 2`;do
        ssh $pxe_ip "sh $DEST_DIR/controller/controller_haproxy.sh"
    done 
}
function _close_controller_services(){
    Note "Close neutron-l3 services on controller node"
    for pxe_ip in `nodes controller 2`;do
        ssh $pxe_ip "sh $DEST_DIR/services/service_controller_close.sh"
    done
}
function _close_neutron_services(){
    Note "Close neutron services on rabbitmq|mariadb node"
    for pxe_ip in `nodes 'rabbitmq|mariadb' 2`;do
        ssh $pxe_ip "sh $DEST_DIR/services/service_neutron_close.sh"
    done
}
function _controller_delete_agent(){
    Note "Remove mariadb|rabbitmq openstack service/agent"
    pxe_ip=`nodes controller 2|head -1`
    ssh $pxe_ip "sh $DEST_DIR/controller/controller_delete_agent.sh"
}
function _controller_enable_agent(){
    Note "Enable mariadb|rabbitmq database openstack service/agent"
    pxe_ip=`nodes controller 2|head -1`
    ssh $pxe_ip "sh $DEST_DIR/controller/controller_enable_agent.sh"
}
function controller_check(){
    Note "Controller state Check!"
    for pxe_ip in `nodes controller 2`;do
        echo_info "---------- [controller: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/controller/check.sh"
    done
}
controller(){
    Note "Controller update"
    _controller_update_haproxy_files
    _controller_clear_pacemaker_resources
}
############################
# pacemaker service
############################
function _pacemaker_kick_out_nodes(){
    Note "Pacemaker kick out rabbitmq/mariadb nodes"
    for pxe_ip in `nodes 'mariadb|rabbitmq' 2`;do
        echo_info "---------- [$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/pacemaker/pacemaker.sh disable"
        pxe_ip=`nodes controller 2|head -1`
        ssh $pxe_ip "sh $DEST_DIR/pacemaker/pacemaker.sh remove $pxe_ip"
    done
}
function _update_corosync_file(){
    Note "Update controller corosync.conf"
    for pxe_ip in `nodes controller 2`;do
        echo_info "---------- [controller:$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/pacemaker/pacemaker.sh update"
    done
}
pacemaker(){
    _pacemaker_kick_out_nodes
    _update_corosync_file
}
pacemaker_check(){
    Note "Update controller corosync.conf"
    for pxe_ip in `nodes controller 2`;do
        echo_info "---------- [controller:$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/pacemaker/pacemaker.sh check"
    done
    pxe_ip=`nodes controller 2|head -1`
    ssh $pxe_ip "crm_node --list"
}

############################
# mariadb service
############################
function _mariadb_close_openstack_services(){
    Note "Close openstack_services on mariadb nodes"
    for pxe_ip in `nodes mariadb 2`;do
        echo_info "---------- [mariadb: $pxe_ip] ----------"
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py disable"
        ssh $pxe_ip "sh $DEST_DIR/services/service_kill.sh"
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py check"
    done
}
function _mariadb_new_cluster(){
    Note "Setup new mariadb cluster"
    local bootstrap=false
    for pxe_ip in `nodes mariadb 2`;do
        echo_info "---------- [mariadb: $pxe_ip] ----------"
        if ! $bootstrap;then
            ssh $pxe_ip "sh $DEST_DIR/mariadb/mariadb.sh true"
            bootstrap=true
        else
            ssh $pxe_ip "sh $DEST_DIR/mariadb/mariadb.sh false"
        fi
    done
}
function mariadb_check(){
    for pxe_ip in `nodes mariadb 2`;do
        echo_info "---------- [mariadb: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/mariadb/check.sh"
    done
}
function mariadb(){
    Note "Mariadb cluster"
    _mariadb_close_openstack_services
    _mariadb_new_cluster
}
############################
# rabbitmq1 service
############################
#rabbitmq1
function _rabbitmq_close_openstack_services(){
    Note "Close openstack_services on rabbitmq nodes"
    for pxe_ip in `nodes rabbitmq 2`;do
        echo_info "---------- [rabbitmq: $pxe_ip] ----------"
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py disable"
        ssh $pxe_ip "sh $DEST_DIR/services/service_kill.sh"
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py check"
    done
}
function _rabbitmq_node_out_from_cluster1(){
    Note "node stop/reset from rabbitmq cluster1"
    for pxe_ip in `nodes 'controller|mariadb|rabbitmq2' 2`;do    
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/rabbitmq.sh delete"
    done
}
function _forget_rabbitmq_nodes_from_cluster1(){
    Note "rabbitmq cluster1 forget nodes"
    pxe_ip=`nodes rabbitmq1 2|head -1`
    for hostname in `nodes 'controller|mariadb|rabbitmq2' 4`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        rabbitmq_host="rabbit@$short_hostname"
        ssh $pxe_ip "rabbitmqctl forget_cluster_node $rabbitmq_host"
    done
}
function _update_rabbitmq_cluster1(){
    Note "Update new rabbitmq cluster1 configs"
    rabbitmq1_cluster_nodes=""
    for hostname in `nodes rabbitmq1 4`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        rabbitmq_host="'rabbit@$short_hostname'"
        rabbitmq1_cluster_nodes="${rabbitmq1_cluster_nodes}${rabbitmq_host},"
    done
    rabbitmq1_cluster_nodes=${rabbitmq1_cluster_nodes%?}
    ##
    for pxe_ip in `nodes rabbitmq1 2`;do
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/rabbitmq.sh update \"$rabbitmq1_cluster_nodes\""
    done
}

function rabbitmq1_check(){
    Note "Check rabbitmq1 cluster status"
    for pxe_ip in `nodes rabbitmq1 2`;do
        echo_info "---------- [rabbitmq1: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/check.sh"
    done
}
rabbitmq1(){
    _rabbitmq_close_openstack_services    
    _rabbitmq_node_out_from_cluster1
    _update_rabbitmq_cluster1
    _forget_rabbitmq_nodes_from_cluster1
}

############################
# rabbitmq2 service
############################
#rabbitmq2
function _create_new_rabbitmq_cluster2(){
    Note "Create new rabbitmq cluster2"
    rabbitmq2_cluster_nodes=""
    for hostname in `nodes rabbitmq2 4`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        rabbitmq_host="'rabbit@$short_hostname'"
        rabbitmq2_cluster_nodes="${rabbitmq2_cluster_nodes}${rabbitmq_host},"
    done
    rabbitmq2_cluster_nodes=${rabbitmq2_cluster_nodes%?}
    ##
    local bootstrap=false
    for pxe_ip in `nodes rabbitmq2 2`;do
        echo_info "---------- [rabbitmq2: $pxe_ip] ----------" 
        if ! $bootstrap;then
            ssh $pxe_ip "sh $DEST_DIR/rabbitmq/rabbitmq.sh add \"$rabbitmq2_cluster_nodes\" true"
            bootstrap=true
        else
            ssh $pxe_ip "sh $DEST_DIR/rabbitmq/rabbitmq.sh add \"$rabbitmq2_cluster_nodes\" false"
        fi
    done
}

function rabbitmq2_check(){
    Note "Check rabbitmq2 cluster status"
    for pxe_ip in `nodes rabbitmq2 2`;do
        echo_info "---------- [rabbitmq2: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/check.sh"
    done
}
rabbitmq2(){
    _create_new_rabbitmq_cluster2
}

function _restart_openstack_services(){
    for pxe_ip in `nodes controller 2`;do
        echo_info "---------- [controller: $pxe_ip] ----------" 
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py restart --role=controller --type=systemd"
    done
    pxe_ip=`nodes controller 2|head -1`
    echo_info "---------- [controller: $pxe_ip] ----------" 
    ssh $pxe_ip "python $DEST_DIR/services/service_manager.py restart --role=controller --type=pacemaker"

    for pxe_ip in `nodes 'compute|storage|xceph' 2`;do
        echo_info "---------- [compute: $pxe_ip] ----------" 
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py restart --role=compute --type=systemd"
    done
}

############################
# update rabbitmq hosts
############################
function _update_service_notification_transport(){
    Note "Update openstack service use notification_transport"
    #rabbit://guest:guest@172.17.4.55:5673/
    for pxe_ip in `nodes 'controller|compute|storage|xceph' 2`;do
        echo_info "---------- [node: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/update_notification_transport.sh add"
    done
}

function _update_service_rpc_transport(){
    Note "Update openstack service use rabbit_hosts"
    #rabbit://guest:guest@172.17.4.55:5673/
    for pxe_ip in `nodes 'controller|compute|storage|xceph' 2`;do
        echo_info "---------- [node: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/update_rpc_transport.sh add"
    done
}

function _restore_service_notification_transport(){
    Note "Update openstack service use notification_transport"
    #rabbit://guest:guest@172.17.4.55:5673/
    for pxe_ip in `nodes 'controller|compute|storage|xceph' 2`;do
        echo_info "---------- [node: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/update_notification_transport.sh delete"
    done
}

function _restore_service_rpc_transport(){
    Note "Update openstack service use rabbit_hosts"
    #rabbit://guest:guest@172.17.4.55:5673/
    for pxe_ip in `nodes 'controller|compute|storage|xceph' 2`;do
        echo_info "---------- [node: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/update_rpc_transport.sh delete"
    done
}

rabbit_hosts_add(){
    _update_service_notification_transport
    _update_service_rpc_transport
}
rabbit_hosts_delete(){
    _restore_service_notification_transport
    _restore_service_rpc_transport
}

############################
# ceph service
############################
function _ceph_rm_mon(){
    Note "Exec remove ceph monitors"
    pxe_ip=`nodes controller 2|head -1`
    ssh $pxe_ip "sh $DEST_DIR/ceph/ceph_rm_mon.sh"
}
function _update_ceph_conf(){
    Note "Update /etc/ceph/ceph.conf conf files"
    for pxe_ip in `nodes 'controller|rabbitmq|mariadb|compute|storage|xceph' 2`;do
        echo_info "---------- [ceph: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/ceph/ceph_update_conf.sh"
    done
}
function _disable_ceph_services(){
    Note "Stop disable mariadb/rabbitmq[1|2] files"
    for pxe_ip in `nodes 'rabbitmq|mariadb' 2`;do
        echo_info "---------- [ceph: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/ceph/ceph_disable_service.sh disable"
    done
}
ceph_check(){
    Note "Check ceph monitors"
    pxe_ip=`nodes controller 2|head -1`
    ssh $pxe_ip "ceph -s"

    Note "Check /etc/ceph/ceph.conf conf"
    for pxe_ip in `nodes 'controller|rabbitmq|mariadb|compute|storage|xceph' 2`;do
        echo_info "---------- [ceph: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/ceph/check.sh"
    done
    
    Note "Check disable mariadb/rabbitmq[1|2] services"
    for pxe_ip in `nodes 'rabbitmq|mariadb' 2`;do
        echo_info "---------- [ceph: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/ceph/ceph_disable_service.sh check"
    done
}
ceph(){
    _ceph_rm_mon
    _update_ceph_conf
    _disable_ceph_services
}

############################
# post
############################
function post(){
    echo_warn "Please ensure nova/neutron command is ok?"
    read -p "Y/N?:" is_service_ok
    if [[ $is_service_ok == "Y" ]];then
        _controller_delete_agent
        _close_neutron_services
        _close_controller_services
        _controller_enable_agent
        #_restart_openstack_services
    else
        echo_warn "Please check cluster services!"
    fi
}

############################
# check
############################
function check(){
    _controller_check
    _mariadb_check
    _rabbitmq1_check
    _rabbitmq2_check
}

############################
# storage bond split
############################
function _storage_bond_to_linux(){
    Note "Change br-storage,br-storagepub from ovs to linux bond"
    read -p "Please input bond name:" bn
    BOND_NAME=$bn
    read -p "Please input storage vlan:" sv
    STORAGE_VLAN=$sv
    read -p "Please input storagepub vlan:" spv
    STORAGEPUB_VLAN=$spv
    for pxe_ip in `nodes 'controller|compute|storage|xceph' 2`;do
        echo_info "---------- [$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/bond/interface_bond.sh $BOND_NAME $STORAGE_VLAN $STORAGEPUB_VLAN"
    done
}
linux_bond(){
    _storage_bond_to_linux
}

############################
#  update_live_migrate_addr
############################
function _update_live_migrate_addr(){
    Note "Change compute node use storagepub to live migrate"
    for pxe_ip in `nodes 'controller|compute|storage|xceph' 2`;do
        echo_info "---------- [$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/compute/update_live_migrate_addr.sh add"
    done
}
function _check_live_migrate_addr(){
    Note "Check compute node use storagepub to live migrate"
    for pxe_ip in `nodes 'controller|compute|storage|xceph' 2`;do
        echo_info "---------- [$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/compute/update_live_migrate_addr.sh check"
    done
}

############################
# update workers
############################
update_workers(){
    Note "Update some controller process workers"
    for pxe_ip in `nodes controller 2`;do
        echo_info "---------- [$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/workers/update_workers.sh"
    done
}

############################
# force metadata
############################
dhcp(){
    Note "Update neutron dhcp_metadata/dhcp_per_network/response_timeout"
    for pxe_ip in `nodes 'controller|neutron-l3' 2`;do
        echo_info "---------- [$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/network/other_network_agent.sh"
    done
}

############################
# menu
############################
function validate(){
    local action=$1
    local result=false
    actions=("--update" "--check" "--restore")
    for a in ${actions[@]};do
        if [[ $a == $action ]];then result=true;break;fi
    done
    if ! $result;then usage;exit 1;fi
}
function usage(){
    echo_error "******************************************"
    echo_error "* NOTE!                                  *"
    echo_error "* You must execute the script by order!! *"
    echo_error "******************************************"
    echo_warn "Usage:"
    echo_warn "sh run.sh prepare                             :sync time and prepare scripts"
    echo_warn "sh run.sh controller   [--update|--check]     :clear pacemaker resources,update haproxy files"
    echo_warn "sh run.sh pacemaker    [--update|--check]     :pacemaker cluster kick out rabbitmq/mariadb ndoes"
    echo_warn "sh run.sh mariadb      [--update|--check]     :setup new mariadb cluster on database nodes"
    echo_warn "sh run.sh rabbitmq1    [--update|--check]     :reduce rabbitmqcluster to 3 node on rabbitmq1 cluster"
    echo_warn "sh run.sh rabbitmq2    [--update|--check]     :setup new rabbitmq custer,set permissions,policies"
    echo_warn "sh run.sh ceph         [--update|--check]     :disable mariadb/rabbitmq ceph services and update all node ceph.conf"
    echo_warn "sh run.sh post                                :before test, disable,clean some services"
    echo_warn "sh run.sh linux_bond                          :Change ovs bond to linux bond"
    echo_warn "sh run.sh rabbit_hosts [--update|--restore]   :Add notification_transport and change to rabbitmq host list"
    echo_warn "sh run.sh live_migrate_addr [--update|--check]:change nova live migrate addr use storagepub"
    echo_warn "sh run.sh update_workers                      :update controller some process workers"
    echo_warn "sh run.sh dhcp                                :neutron dhcp force_metadata/dhcp_per_network/response_timeout"
    echo_warn "sh run.sh restart_services                    :restart controller compute openstack services"
}

# ---------- Main ----------
if [[ $# -eq 0 || $# -gt 2 ]]; then usage;exit;fi
role=$1
action=$2
#limit actions
if [[ $# -eq 2 ]];then
    validate $action
fi
_check_nodes 
if   [[ $role == "prepare" ]];then prepare
elif [[ $role == "controller" ]];then
    if [[ $action == "--update" ]];then
        controller
    elif [[ $action == "--check" ]];then
        controller_check
    fi
elif [[ $role == "pacemaker" ]];then
    if [[ $action == "--update" ]];then
        pacemaker
    elif [[ $action == "--check" ]];then
        pacemaker_check
    fi
elif [[ $role == "mariadb" ]];then
    if [[ $action == "--update" ]];then
        mariadb
    elif [[ $action == "--check" ]];then
        mariadb_check
    fi
elif [[ $role == "rabbitmq1" ]];then
    if [[ $action == "--update" ]];then
        rabbitmq1
    elif [[ $action == "--check" ]];then
        rabbitmq1_check
    fi
elif [[ $role == "rabbitmq2" ]]; then
    if [[ $action == "--update" ]];then
        rabbitmq2
    elif [[ $action == "--check" ]];then
        rabbitmq2_check
    fi
elif [[ $role == "ceph" ]]; then
    if [[ $action == "--update" ]];then
        ceph
    elif [[ $action == "--check" ]];then
        ceph_check
    fi
elif [[ $role == "linux_bond" ]];then
    linux_bond
elif [[ $role == "rabbit_hosts" ]];then
    if [[ $action == "--update" ]];then
        rabbit_hosts_add
    elif [[ $action == "--restore" ]];then
        rabbit_hosts_delete
    fi
elif [[ $role == "update_workers" ]];then
    update_workers
elif [[ $role == "dhcp" ]];then
    dhcp
elif [[ $role == "restart_services" ]];then
    _restart_openstack_services
elif [[ $role == "live_migrate_addr" ]];then
    if [[ $action == "--update" ]];then
        _update_live_migrate_addr
    elif [[ $action == "--check" ]];then
        _check_live_migrate_addr
    fi
elif [[ $role == "post" ]];then post
else usage
fi
