#!/bin/bash
WORKERS=16

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

############################
# backup functions
############################
DATE=`date +%Y%m%d%H`
_backup_file(){
    CFG=$1
    echo_info "Backup and update $CFG ..."
    CFG_BAK=${CFG}.${DATE}
    if [ ! -f "$CFG_BAK" ]; then
        cp $CFG $CFG_BAK
    fi
}

update(){
    #/etc/magnum/magnum.conf
    _backup_file /etc/magnum/magnum.conf
    sed -i "s/#workers =.*/workers = $WORKERS/g" /etc/magnum/magnum.conf
    sed -i "s/^workers =.*/workers = $WORKERS/g" /etc/magnum/magnum.conf
    
    #/etc/heat/heat.conf
    _backup_file /etc/heat/heat.conf
    sed -i "s/#workers =.*/workers = 2/g" /etc/heat/heat.conf
    sed -i "s/^workers =.*/workers = 2/g" /etc/heat/heat.conf
    sed -i "s/^#num_engine_workers =.*/num_engine_workers = $WORKERS/" /etc/heat/heat.conf
    sed -i "s/^num_engine_workers =.*/num_engine_workers = $WORKERS/" /etc/heat/heat.conf
    
    #/etc/keystone/keystone.conf
    _backup_file /etc/keystone/keystone.conf
    sed -i "s/^public_workers =.*/public_workers = $WORKERS/" /etc/keystone/keystone.conf
    sed -i "s/^admin_workers =.*/admin_workers = $WORKERS/" /etc/keystone/keystone.conf
    
    #/etc/neutron/neutron.conf
    _backup_file /etc/neutron/neutron.conf
    sed -i "s/^api_workers=.*/api_workers = $WORKERS/g" /etc/neutron/neutron.conf
    sed -i "s/^api_workers =.*/api_workers = $WORKERS/g" /etc/neutron/neutron.conf
    
    #etc/neutron/metadata_agent.ini
    _backup_file /etc/neutron/metadata_agent.ini
    sed -i "s/^metadata_workers = .*/metadata_workers = $WORKERS/g" /etc/neutron/metadata_agent.ini
    
    #/etc/aodh/aodh.conf
    #Default : 1

    #/etc/ceilometer/ceilometer.conf
    #Default : 1

    #/etc/cinder/cinder.conf
    _backup_file /etc/cinder/cinder.conf
    sed -i "s/^osapi_volume_workers =.*/osapi_volume_workers = $WORKERS/g" /etc/cinder/cinder.conf

    #/etc/sahara/sahara.conf
    #Default: 1

    #/etc/nova/nova.conf
    _backup_file /etc/nova/nova.conf
    sed -i "s/^metadata_workers=.*/metadata_workers = $WORKERS/g" /etc/nova/nova.conf
    sed -i "s/^metadata_workers =.*/metadata_workers = $WORKERS/g" /etc/nova/nova.conf
    sed -i "s/^osapi_compute_workers=.*/osapi_compute_workers = $WORKERS/g" /etc/nova/nova.conf
    sed -i "s/^osapi_compute_workers =.*/osapi_compute_workers = $WORKERS/g" /etc/nova/nova.conf

    #/etc/trove/trove.conf
    _backup_file /etc/trove/trove.conf
    sed -i "s/^trove_api_workers=.*/trove_api_workers = $WORKERS/g" /etc/trove/trove.conf
    sed -i "s/^trove_api_workers =.*/trove_api_workers = $WORKERS/g" /etc/trove/trove.conf
    
    #/etc/trove/trove-conductor.conf
    egrep "^trove_conductor_worker" /etc/trove/trove-conductor.conf
    if [[ $? -ne 0 ]];then
        sed -i "4i trove_conductor_workers = $WORKERS" /etc/trove/trove-conductor.conf
    fi

    #/etc/glance/glance-api.conf
    _backup_file /etc/glance/glance-api.conf
    sed -i "s/^workers =.*/workers = $WORKERS/g" /etc/glance/glance-api.conf

    #/etc/glance/glance-registry.conf
    _backup_file /etc/glance/glance-registry.conf
    sed -i "s/^workers =.*/workers = $WORKERS/g" /etc/glance/glance-registry.conf
}

_check_workers(){
    File=$1
    Options=$2
    echo_info "Checking File $File Options $Options ..."
    cat $File | egrep "$Options"
}

check(){
    echo_warn " ---------------------- Check file workers ----------------------"
    _check_workers /etc/magnum/magnum.conf "^workers"
    _check_workers /etc/heat/heat.conf "^workers|^num_engine_workers"
    _check_workers /etc/keystone/keystone.conf "^admin_workers|^public_workers"
    _check_workers /etc/neutron/neutron.conf "^api_workers"
    _check_workers /etc/neutron/metadata_agent.ini "^metadata_workers"
    _check_workers /etc/aodh/aodh.conf "workers"
    _check_workers /etc/ceilometer/ceilometer.conf "workers"
    _check_workers /etc/cinder/cinder.conf "^osapi_volume_workers"
    _check_workers /etc/sahara/sahara.conf "workers"
    _check_workers /etc/nova/nova.conf "^metadata_workers|^osapi_compute_workers"
    _check_workers /etc/trove/trove.conf "^trove_api_workers"
    _check_workers /etc/trove/trove-conductor.conf "^trove_conductor_workers"
    _check_workers /etc/glance/glance-api.conf "^workers"
    _check_workers /etc/glance/glance-registry.conf "^workers"
}

start_services(){
    systemctl restart openstack-magnum-api openstack-heat-api openstack-keystone
    systemctl restart neutron-server neutron-metadata-agent
    systemctl restart openstack-aodh-api openstack-aodh-notifier openstack-aodh-listener
    systemctl restart openstack-trove-api openstack-trove-conductor openstack-trove-taskmanager
    systemctl restart openstack-nova-api 
    systemctl restart openstack-glance-api openstack-glance-registry
}

update
check
start_services
