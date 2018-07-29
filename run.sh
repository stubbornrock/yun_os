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

############################
# prepare
############################
function _copy_files(){
    for pxe_ip in `cat nodes.txt | egrep 'controller|mariadb|rabbitmq|compute|storage|xsky'| awk '{print $2}'`;do
        echo_info "***** Copy update scripts to :[$pxe_ip] *****"
        ssh $pxe_ip "mkdir -p $DEST_DIR;rm -rf $DEST_DIR/*"
        scp -r ./* $pxe_ip:$DEST_DIR/
    done
}
function _sync_time(){
    for pxe_ip in `cat nodes.txt | awk '{print $2}'`;do
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
    pxe_ip=`cat nodes.txt | egrep 'controller' | awk '{print $2}'|head -1`
    ssh $pxe_ip "sh $DEST_DIR/controller/controller_clear_ra.sh"
}
function _controller_update_haproxy_files(){
    Note "Prepare haproxy files for all services"
    for pxe_ip in `cat nodes.txt | egrep 'controller' | awk '{print $2}'`;do
        ssh $pxe_ip "sh $DEST_DIR/controller/controller_haproxy.sh"
    done 
}
function _close_controller_services(){
    Note "Close neutron-l3 services on controller node"
    for pxe_ip in `cat nodes.txt | egrep 'controller' | awk '{print $2}'`;do
        ssh $pxe_ip "sh $DEST_DIR/services/service_controller_close.sh"
    done
}
function _close_neutron_services(){
    Note "Close neutron services on rabbitmq|mariadb node"
    for pxe_ip in `cat nodes.txt | egrep 'rabbitmq|mariadb' | awk '{print $2}'`;do
        ssh $pxe_ip "sh $DEST_DIR/services/service_neutron_close.sh"
    done
}
function _controller_delete_agent(){
    Note "Remove mariadb|rabbitmq openstack service/agent"
    pxe_ip=`cat nodes.txt | egrep 'controller' | awk '{print $2}'|head -1`
    ssh $pxe_ip "sh $DEST_DIR/controller/controller_delete_agent.sh"
}
function _controller_enable_agent(){
    Note "Enable mariadb|rabbitmq database openstack service/agent"
    pxe_ip=`cat nodes.txt | egrep 'controller' | awk '{print $2}'|head -1`
    ssh $pxe_ip "sh $DEST_DIR/controller/controller_enable_agent.sh"
}
function controller_check(){
    Note "Controller state Check!"
    for pxe_ip in `cat nodes.txt | egrep 'controller' | awk '{print $2}'`;do
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
# mariadb service
############################
function _mariadb_close_openstack_services(){
    Note "Close openstack_services on mariadb nodes"
    for pxe_ip in `cat nodes.txt | egrep 'mariadb' | awk '{print $2}'`;do
        echo_info "---------- [mariadb: $pxe_ip] ----------"
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py disable"
        ssh $pxe_ip "sh $DEST_DIR/services/service_kill.sh"
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py check"
    done
}
function _mariadb_new_cluster(){
    Note "Setup new mariadb cluster"
    local bootstrap=false
    for pxe_ip in `cat nodes.txt | egrep 'mariadb' | awk '{print $2}'`;do
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
    for pxe_ip in `cat nodes.txt | egrep 'mariadb' | awk '{print $2}'`;do
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
    for pxe_ip in `cat nodes.txt | egrep 'rabbitmq' | awk '{print $2}'`;do
        echo_info "---------- [rabbitmq: $pxe_ip] ----------"
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py disable"
        ssh $pxe_ip "sh $DEST_DIR/services/service_kill.sh"
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py check"
    done
}
function _rabbitmq_node_out_from_cluster1(){
    Note "node stop/reset from rabbitmq cluster1"
    for pxe_ip in `cat nodes.txt | egrep 'controller|mariadb|rabbitmq2' | awk '{print $2}'`;do    
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/rabbitmq.sh delete"
    done
}
function _forget_rabbitmq_nodes_from_cluster1(){
    Note "rabbitmq cluster1 forget nodes"
    pxe_ip=`cat nodes.txt | egrep 'rabbitmq1' | awk '{print $2}'|head -1`
    for hostname in `cat nodes.txt | egrep 'controller|mariadb|rabbitmq2' | awk '{print $4}'`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        rabbitmq_host="rabbit@$short_hostname"
        ssh $pxe_ip "rabbitmqctl forget_cluster_node $rabbitmq_host"
    done
}
function _update_rabbitmq_cluster1(){
    Note "Update new rabbitmq cluster1 configs"
    rabbitmq1_cluster_nodes=""
    for hostname in `cat nodes.txt | egrep 'rabbitmq1' | awk '{print $4}'`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        rabbitmq_host="'rabbit@$short_hostname'"
        rabbitmq1_cluster_nodes="${rabbitmq1_cluster_nodes}${rabbitmq_host},"
    done
    rabbitmq1_cluster_nodes=${rabbitmq1_cluster_nodes%?}
    ##
    for pxe_ip in `cat nodes.txt | egrep 'rabbitmq1' | awk '{print $2}'`;do
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/rabbitmq.sh update \"$rabbitmq1_cluster_nodes\""
    done
}

function rabbitmq1_check(){
    Note "Check rabbitmq1 cluster status"
    for pxe_ip in `cat nodes.txt | egrep 'rabbitmq1' | awk '{print $2}'`;do
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
    for hostname in `cat nodes.txt | egrep 'rabbitmq2' | awk '{print $4}'`;do
        hostname_list=(${hostname//./ })
        short_hostname=${hostname_list[0]}
        rabbitmq_host="'rabbit@$short_hostname'"
        rabbitmq2_cluster_nodes="${rabbitmq2_cluster_nodes}${rabbitmq_host},"
    done
    rabbitmq2_cluster_nodes=${rabbitmq2_cluster_nodes%?}
    ##
    local bootstrap=false
    for pxe_ip in `cat nodes.txt | egrep 'rabbitmq2' | awk '{print $2}'`;do
        echo_info "---------- [rabbitmq2: $pxe_ip] ----------" 
        if ! $bootstrap;then
            ssh $pxe_ip "sh $DEST_DIR/rabbitmq/rabbitmq.sh add \"$rabbitmq2_cluster_nodes\" true"
            bootstrap=true
        else
            ssh $pxe_ip "sh $DEST_DIR/rabbitmq/rabbitmq.sh add \"$rabbitmq2_cluster_nodes\" false"
        fi
    done
}
function _update_service_notification_transport(){
    Note "Update openstack service use notification_transport"
    #rabbit://guest:guest@172.17.4.55:5673/
    for pxe_ip in `cat nodes.txt | egrep 'controller|compute' |awk '{print $2}'`;do
        echo_info "---------- [node: $pxe_ip] ----------" 
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/update_notification_tranport.sh add"
    done
}
function _rabbitmq2_used_by_services(){
    for pxe_ip in `cat nodes.txt | egrep 'controller' | awk '{print $2}'`;do
        echo_info "---------- [controller: $pxe_ip] ----------" 
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py restart --role=controller --type=systemd"
    done
    pxe_ip=`cat nodes.txt | egrep 'controller' | awk '{print $2}'|head -1`
    echo_info "---------- [controller: $pxe_ip] ----------" 
    ssh $pxe_ip "python $DEST_DIR/services/service_manager.py restart --role=controller --type=pacemaker"

    for pxe_ip in `cat nodes.txt | egrep 'compute' | awk '{print $2}'`;do
        echo_info "---------- [compute: $pxe_ip] ----------" 
        ssh $pxe_ip "python $DEST_DIR/services/service_manager.py restart --role=compute --type=systemd"
    done
}

function rabbitmq2_check(){
    Note "Check rabbitmq2 cluster status"
    for pxe_ip in `cat nodes.txt | egrep 'rabbitmq2' | awk '{print $2}'`;do
        echo_info "---------- [rabbitmq2: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/rabbitmq/check.sh"
    done
}
rabbitmq2(){
    _create_new_rabbitmq_cluster2
}

############################
# ceph service
############################
function _ceph_rm_mon(){
    Note "Exec remove ceph monitors"
    pxe_ip=`cat nodes.txt | egrep 'controller' | awk '{print $2}'|head -1`
    ssh $pxe_ip "sh $DEST_DIR/ceph/ceph_rm_mon.sh"
}
function _update_ceph_conf(){
    Note "Update /etc/ceph/ceph.conf conf files"
    for pxe_ip in `cat nodes.txt | egrep 'controller|rabbitmq|mariadb|compute|storage' | awk '{print $2}'`;do
        echo_info "---------- [ceph: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/ceph/ceph_update_conf.sh"
    done
}
function _disable_ceph_services(){
    Note "Stop disable mariadb/rabbitmq[1|2] files"
    for pxe_ip in `cat nodes.txt | egrep 'rabbitmq|mariadb' | awk '{print $2}'`;do
        echo_info "---------- [ceph: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/ceph/ceph_disable_service.sh disable"
    done
}
ceph_check(){
    Note "Check ceph monitors"
    pxe_ip=`cat nodes.txt | egrep 'controller' | awk '{print $2}'|head -1`
    ssh $pxe_ip "ceph -s"

    Note "Check /etc/ceph/ceph.conf conf"
    for pxe_ip in `cat nodes.txt | egrep 'controller|rabbitmq|mariadb|compute|storage' | awk '{print $2}'`;do
        echo_info "---------- [ceph: $pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/ceph/check.sh"
    done
    
    Note "Check disable mariadb/rabbitmq[1|2] files"
    for pxe_ip in `cat nodes.txt | egrep 'rabbitmq|mariadb' | awk '{print $2}'`;do
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
    _controller_delete_agent
    _close_neutron_services
    _close_controller_services
    _controller_enable_agent
    #_update_service_notification_transport
    #_rabbitmq2_used_by_services
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
    for pxe_ip in `cat nodes.txt | egrep 'xsky' | awk '{print $2}'`;do
        echo_info "---------- [$pxe_ip] ----------"
        ssh $pxe_ip "sh $DEST_DIR/bound/interface_bound.sh"
    done
}
linux_bond(){
    _storage_bond_to_linux
}

############################
# menu
############################
function validate(){
    local action=$1
    local result=false
    actions=("--update" "--check")
    for a in ${actions[@]};do
        if [[ $a == $action ]];then result=true;break;fi
    done
    if ! $result;then usage;exit 1;fi
}
function usage(){
    echo_warn "Usage:"
    echo_warn "./run.sh prepare                       :sync time and prepare scripts"
    echo_warn "./run.sh controller [--update|--check] :clear pacemaker resources,update haproxy files"
    echo_warn "./run.sh mariadb    [--update|--check] :setup new mariadb cluster on database nodes"
    echo_warn "./run.sh rabbitmq1  [--update|--check] :reduce rabbitmqcluster to 3 node on rabbitmq1 cluster"
    echo_warn "./run.sh rabbitmq2  [--update|--check] :setup new rabbitmq custer,set permissions,policies"
    echo_warn "./run.sh ceph       [--update|--check] :disable mariadb/rabbitmq ceph services and update all node ceph.conf"
    echo_warn "./run.sh post                          :before test, disable,clean some services"
    echo_warn "./run.sh linux_bond                    :Change ovs bond to linux bond"
}

# ---------- Main ----------
if [[ $# -eq 0 || $# -gt 2 ]]; then usage;exit;fi
role=$1
action=$2
#limit actions
if [[ $# -eq 2 ]];then
    validate $action
fi
if   [[ $role == "prepare" ]];then prepare
elif [[ $role == "controller" ]];then
    if [[ $action == "--update" ]];then
        controller
    elif [[ $action == "--check" ]];then
        controller_check
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
elif [[ $role == "post" ]];then post
elif [[ $role == "linux_bond" ]];then linux_bond
else usage
fi
