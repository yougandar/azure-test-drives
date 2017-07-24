#!/bin/bash

function softnas_configure()
{

echo "Sript execution started - `date`" > /tmp/cftemplate.txt
/var/www/softnas/scripts/firstinit.sh
service httpd restart
# workaround of apache first time boot 500 internal error 
wget --no-check-certificate -O - https://localhost/softnas/ > /dev/null 2>&1
wget --no-check-certificate -O - https://localhost/softnas/ > /dev/null 2>&1

USERN=softnas
PASSW=$1
POOLNAME=softnas_pool
VOLNAME=softnas_vol
APPDIR=/var/www/softnas
APICMD=$APPDIR/api/softnas-cmd


$APICMD login $USERN $PASSW
$APICMD parted_command add_partition /dev/sdc
$APICMD createpool /dev/sdc $POOLNAME 0 on -t
$APICMD createvolume vol_name=$VOLNAME pool=$POOLNAME vol_type=filesystem provisioning=thin exportNFS=on shareCIFS=on dedup=on enable_snapshot=on schedule_name=Default hourlysnaps=5 dailysnaps=10 weeklysnaps=0

$APICMD createvolume vol_name=softnas_iscsi pool=$POOLNAME vol_type=blockdevice provisioning=thin shareISCS=on

echo "Sript execution completed - `date`" >> /tmp/cftemplate.txt

}

softnas_configure $1 >> /tmp/cftemplate.txt 2>&1

exit 0
