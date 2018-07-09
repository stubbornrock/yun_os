#!/bin/bash
set -x
INVENTORY="/tmp/yun_os/nodes.txt"
clear_pacemaker_ra(){
    # delete resource
    for name in `cat ${INVENTORY} | egrep 'mariadb|rabbitmq' | awk '{print $4}'`;do
        echo "---------- pacemaker clear $name resources ----------"
        crm configure delete easystack-hagent-on-$name
        crm configure delete p_ironic-conductor-on-$name
        crm configure delete p_ironic-tftp-lsyncd-on-$name
        crm configure delete p_magnum-conductor-on-$name
        crm configure delete p_magnum-key-lsyncd-on-$name
        crm configure delete p_nova-compute-on-$name
        crm configure delete p_openstack-aodh-evaluator-on-$name
        crm configure delete p_openstack-ceilometer-central-on-$name
        crm configure delete p_openstack-heat-engine-on-$name
        crm configure delete vip__management-on-$name
        crm configure delete vip__public-on-$name
        crm configure delete vip_no_ns__baremetal_mgmt-on-$name
    done
    ## restart resource
    crm resource restart easystack-hagent
    crm resource restart p_ironic-conductor
    crm resource restart p_ironic-tftp-lsyncd
    crm resource restart p_magnum-conductor
    crm resource restart p_magnum-key-lsyncd
    crm resource restart p_nova-compute
    crm resource restart p_openstack-aodh-evaluator
    crm resource restart p_openstack-ceilometer-central
    crm resource restart p_openstack-heat-engine
    crm resource restart vip__management
    crm resource restart vip__public
    crm resource restart vip_no_ns__baremetal_mgmt 
    ## mysql
    crm resource stop p_mysql
    crm configure delete p_mysql
    crm configure delete clone_p_mysql
    ## commit
    crm configure commit
    crm resource refresh
}

clear_pacemaker_ra
