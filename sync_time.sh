TEMP_FILE='/tmp/pxe_ips.txt'
mkdir -p tmp
rm -rf $TEMP_FILE
roller node | cut -d '|' -f5 > $TEMP_FILE
sed -i '1,2d' $TEMP_FILE
for pxe_ip in `cat $TEMP_FILE`;do
    d=`date | awk '{print $4}'`
    ssh $pxe_ip "date -s $d"
done
rm -rf $TEMP_FILE
