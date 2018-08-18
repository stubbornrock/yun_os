# -*- coding: utf-8 -*-
import os
import sys
import yaml
import signal
import argparse


SERVICE_DISABLE_FILE='/tmp/yun_os/services/service_disable.yaml'
SERVICE_RESTART_FILE='/tmp/yun_os/services/service_restart.yaml'

FUNCTIONS = {}
OPENSTACK_COMMON_SERVICES = ['libvirtd','httpd','mongod']

def signal_handler(signo, frame):
    sys.exit(-signo)

class LOG():
    @staticmethod
    def info(content):
        code = "32;40"
        print "\033[1;%sm%s\033[0m" %(code,content)
    @staticmethod
    def warn(content):
        code = "33;40"
        print "\033[1;%sm%s\033[0m" %(code,content)
    @staticmethod
    def error(content):
        code = "31;40"
        print "\033[1;%sm%s\033[0m" %(code,content)

def register(role):
    def dec(func):
        FUNCTIONS[role] = func
        def wrapper(*args, **kwargs):
            func(*args, **kwargs)
        return wrapper
    return dec

# filter openstack services from os
def _openstack_service_filter(service):
    if service.endswith(".service"):
        service = service[:-8]
    if '@' in service:
        return None
    if service.startswith("openstack") or service.startswith("neutron") \
           or service in OPENSTACK_COMMON_SERVICES:
        return service
    return None

def _check_service_state(service):
    check_cmd="systemctl is-active %s" %service
    state = os.popen(check_cmd).read().strip()
    return state

def _installed_openstack_services():
    openstack_services = []
    list_units_cmd = "systemctl list-unit-files --type=service | awk '{print $1\",\"$2}'" 
    installed_services = os.popen(list_units_cmd).read().split("\n")
    for service in installed_services:
        item = {}
        if not service:
            continue
        name, enabled = tuple(service.split(','))
        name =  _openstack_service_filter(name)
        if name:
            item['name'] = name
            item['enabled'] = enabled
            item['state'] =  _check_service_state(name)
            openstack_services.append(item)
    return openstack_services

def _service_show(service):
    name = service['name']
    enabled = service['enabled']
    state =  service['state']
    msg = "%-40s => %-10s => %s" %(name,enabled,state)
    if enabled == 'enabled' and state == 'active':
        LOG.error(msg)
    else:
        LOG.info(msg)

@register('restart')
def restart_openstack_services(arguments):
    role = arguments['role']
    stype = arguments['type']
    with open(SERVICE_RESTART_FILE,'r') as f:
        services = yaml.load(f)
    systemd_services = []
    pacemaker_services = []
    if role == 'controller':
        for service_list in services['systemd']['controller'].values():
            systemd_services.extend(service_list)
        pacemaker_services = services['pacemaker']
    elif role == 'compute':
        for service_list in services['systemd']['compute'].values():
            systemd_services.extend(service_list)
    if stype == "systemd":
        systemd_services_str = " ".join(systemd_services)
        systemd_services_cmd = "systemctl restart %s" %systemd_services_str
        print systemd_services_cmd
        os.popen(systemd_services_cmd)
    else:
        for s in pacemaker_services:
            cmd="crm resource restart %s" %s
            os.popen(cmd)

@register('disable')
def disable_openstack_services(arguments):
    with open(SERVICE_DISABLE_FILE,'r') as f:
        services = yaml.load(f)
    user_services = []
    for service_list in services['systemd'].values():
        user_services.extend(service_list)
    for service in user_services:
        cmd = "systemctl disable %s;systemctl stop %s" %(service,service)
        print cmd
        os.popen(cmd)

@register('check')
def check_openstack_services(arguments):
    with open(SERVICE_DISABLE_FILE,'r') as f:
        services = yaml.load(f)
    user_services = []
    for service_list in services['systemd'].values():
        user_services.extend(service_list)
    openstack_services = _installed_openstack_services()
    openstack_services_names = [ s['name'] for s in openstack_services]
    os_not_installed_service = [s for s in user_services if s not in openstack_services_names]
    os_has_installed_service = [s for s in user_services if s in openstack_services_names]
    need_define = [ s for s in openstack_services if s['name'] not in user_services]
    if need_define:
        print "The following services have been installed in the system and need to define in yaml file:"
        for service in need_define:
            _service_show(service)
        #sys.exit(0)
    # output define service states
    if os_not_installed_service:
        print "The following services are not installed in system:"
        for name in os_not_installed_service:
            LOG.warn("%-40s not installed" %name)
    LOG.warn("The following services states in system:")
    for name in os_has_installed_service:
        for service in openstack_services:    
            if name == service['name']:
                _service_show(service)

if __name__ == '__main__':
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    # Main parser
    parser = argparse.ArgumentParser(
        prog='roller2',
        description='%(prog)s Kubernetes cluster deployment extend tool',
        add_help=False
    )
    subparsers = parser.add_subparsers(help='commands')
    # parent parser
    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument(
        '-r', '--role', choices=['controller','compute'], required=False,
        help='Controller or Compute node.'
    )
    parent_parser.add_argument(
        '-t', '--type', choices=['pacemaker','systemd'], required=False,
        help='Service Start type.'
    )
    # sub parser
    for role in FUNCTIONS.keys():
        p = subparsers.add_parser(
             role, parents=[parent_parser],
        )
        p.set_defaults(func=FUNCTIONS[role])
    ## run
    args = parser.parse_args()
    arguments = dict(args._get_kwargs())
    args.func(arguments)
