#/usr/bin/python
import os
import sys

INVENTORY = "%s/nodes.txt" %os.environ.get("PWD")

def roller_node():
    collect_cmd = "mkdir -p tmp;"+\
                  "rm -rf %s;"+\
                  "roller node | cut -d '|' -f3,5 > tmp/ips.txt;"+\
                  "sed -i '1,2d' tmp/ips.txt;"
    collect_cmd = collect_cmd %INVENTORY
    os.system(collect_cmd)

def _collect_nodes_infos():
    roles_to_nodes={}
    for line in open("tmp/ips.txt"):   
        name_ip = line.split('|')
        name = name_ip[0].strip().lower()
        pxe_ip = name_ip[1].strip()
        mgmt_ip = os.popen("ssh %s ifconfig br-mgmt | grep 'inet ' | awk '{print $2}'" %pxe_ip).read().strip()
        store_ip = os.popen("ssh %s ifconfig br-storagepub | grep 'inet ' | awk '{print $2}'" %pxe_ip).read().strip()
        hostname = os.popen("ssh %s hostname" %pxe_ip).read().strip()
        roles=[]
        if 'controller' in name or 'contr' in name:
            roles.append('controller')
        if 'rabbit' in name or 'rab' in name:
            roles.append('rabbitmq')
        if 'mariadb' in name or 'mysql' in name or 'mar' in name:
            roles.append('mariadb')
        if 'compute' in name or 'comp' in name:
            roles.append('compute')
        if 'mongo' in name or 'mong' in name:
            roles.append('mongo')
        if 'neutron-l3' in name or 'neutron' in name or 'neut' in name:
            roles.append('neutron-l3')
        if 'osd' in name or 'ceph' in name:
            roles.append('storage')
        if 'x-ceph' in name:
            roles.append('xceph')
        if not roles:
            roles.append('other')
        for role in roles:
            node={'mgmt_ip':mgmt_ip,'store_ip':store_ip,'pxe_ip':pxe_ip,'hostname':hostname}
            if role not in roles_to_nodes.keys():
                roles_to_nodes[role]=[node]
            else:
                roles_to_nodes[role].append(node) 
    return roles_to_nodes

def write_infos_to_file():
    roles_to_nodes = _collect_nodes_infos()
    rabbitmq_count = 0
    for role in roles_to_nodes.keys():
        nodes = roles_to_nodes[role]
        sorted_nodes = sorted(nodes, key=lambda s:s['pxe_ip'])
        for node in sorted_nodes:
            if role == 'rabbitmq':
                if rabbitmq_count >= 3:
                    new_role='rabbitmq2'
                else:
                    new_role='rabbitmq1'
                rabbitmq_count = rabbitmq_count + 1
            else:
                new_role=role
            cmd = "echo %s %s %s %s %s>> nodes.txt" %(node['mgmt_ip'],node['pxe_ip'],\
                  node['store_ip'],node['hostname'],new_role)
            os.system(cmd)

def output_infos():
    print "NOTE: Please check nodes information:"
    info = os.popen("cat %s" %INVENTORY).read()
    print info

roller_node()
write_infos_to_file()
output_infos()
