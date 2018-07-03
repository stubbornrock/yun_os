import yaml
file_path = "/etc/nailgun/settings.yaml"
with open(file_path,'r') as f:
    data = yaml.load(f)
dbdata = data['DATABASE']
host = dbdata['host']
passwd = dbdata['passwd']

print "psql -h %s nailgun nailgun" %host
print passwd
print "select id,name,status from nodes where status='error';"
print "update nodes set status='ready' where id in (20,21,22,25,32,33,13,17);"
