update(){
    #/etc/trove/trove.conf:15:trove_api_workers=16
    #/etc/trove/trove-conductor.conf trove_conductor_workers=4
    #/etc/nova/nova.conf:332:metadata_workers=16
    #/etc/neutron/neutron.conf:214:api_workers=16
    #/etc/heat/heat.conf:1163:#workers = 0
    #/etc/heat/heat.conf:1255:#workers = 1
    #/etc/glance/glance-api.conf:164:workers = 16
    #/etc/glance/glance-registry.conf:155:workers = 16
    #/etc/cinder/cinder.conf:814:osapi_volume_workers = 16

    sed -i 's/^trove_api_workers=.*/trove_api_workers=16/g' /etc/trove/trove.conf
    sed -i '4i trove_conductor_workers=16' /etc/trove/trove-conductor.conf
    sed -i 's/^metadata_workers=.*/metadata_workers=16/g' /etc/nova/nova.conf
    sed -i 's/^osapi_compute_worker=.*/osapi_compute_worker=16/g' /etc/nova/nova.conf
    sed -i 's/^api_workers=.*/api_workers=16/g' /etc/neutron/neutron.conf
    sed -i 's/^#num_engine_workers =.*/num_engine_workers=16/g' /etc/heat/heat.conf
    sed -i '1164i workers = 16' /etc/heat/heat.conf
    sed -i 's/^workers =.*/workers =16/g' /etc/glance/glance-api.conf
    sed -i 's/^workers =.*/workers =16/g' /etc/glance/glance-registry.conf
    sed -i 's/^osapi_volume_workers =.*/osapi_volume_workers =16/g' /etc/cinder/cinder.conf
}

check(){
    cat /etc/trove/trove.conf | egrep '^trove_api_workers'
    cat /etc/trove/trove-conductor.conf | egrep '^trove_conductor_workers'
    cat /etc/nova/nova.conf | egrep '^metadata_workers|^osapi_compute_worker'
    cat /etc/neutron/neutron.conf | egrep '^api_workers'
    cat /etc/heat/heat.conf | egrep '^num_engine_workers|^wokers'
    cat /etc/glance/glance-api.conf | egrep '^workers'
    cat /etc/glance/glance-registry.conf | egrep '^workers'
    cat /etc/cinder/cinder.conf | egrep '^osapi_volume_workers'
}

start_services(){
    systemctl restart openstack-trove-api openstack-trove-conductor openstack-trove-taskmanager
    systemctl restart openstack-nova-api neutron-server
    systemctl restart openstack-heat-api
    systemctl restart openstack-glance-api openstack-glance-registry
    # status
    systemctl status openstack-trove-api openstack-trove-conductor openstack-trove-taskmanager openstack-nova-api neutron-server openstack-heat-api openstack-glance-api openstack-glance-registry | grep Active:
}
update
check
start_services
