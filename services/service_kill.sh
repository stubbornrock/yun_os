#!/bin/bash
force_kill(){
    services=("magnum-conductor"\ 
              "magnum-key-lsyncd"\ 
              "easystack-hagent"\ 
              "ironic-conductor"\ 
              "ironic-tftp-lsyncd"\ 
              "heat-engine"\ 
              "aodh-evaluator"\ 
              "ceilometer-polling"\ 
              "neutron-ns-metadata-proxy"\ 
              "neutron-rootwrap-daemon"\ 
              "neutron-rootwrap")
    for s in ${services[@]};do
        killall -9 $s
    done
}
force_kill
