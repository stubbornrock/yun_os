export PGPASSWORD=`cat /etc/roller/astute.yaml |grep nailgun_password |awk '{print $2}'`
sql="SELECT id,name,status,progress FROM nodes"
psql -U nailgun nailgun -h localhost -c "$sql"
