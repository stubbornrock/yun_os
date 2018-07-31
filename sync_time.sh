for pxe_ip in `roller node | awk '{print $9}'| sed '1,2d'`;do
    d=`date | awk '{print $4}'`
    ssh $pxe_ip "date -s $d"
done
