#!/bin/bash
#adminUsername=trend
#Firstname=Chef
#Lastname=Automate
#mailid=nvtuluva@sysgain.com
#adminpassword='Sysgain@1234'
#orguser=ChefInc
#FQDNOrch=publicdnsorcserverphqrxg3pguym4.westus.cloudapp.azure.com:33001/key
#-----------------------------------------------------------------------------------------------------------------------------------------
adminUsername=$1
Firstname=$2
Lastname=$3
mailid=$4
adminpassword=$5
orguser=$6

#-----------------------------------------------------------------------------------------------------------------------------------------
#echo $adminUsername
#echo $Firstname
#echo $Lastname
#echo $mailid
#echo $adminpassword
#echo $orguser
#echo $FQDNOrch
#sleep 180
##pull files from repo
#wget https://trendmicrop2p.blob.core.windows.net/trendmicropushtopilot/files/validatorkey.txt  -O /tmp/validatorkey.txt
#wget https://trendmicrop2p.blob.core.windows.net/trendmicropushtopilot/files/userkey.txt -O /tmp/userkey.txt
##Assigning variable to construct and update key and key-value
#validatorkey=`cat /tmp/validatorkey.txt`
#userkey=`cat /tmp/userkey.txt`
##Chef-Automate Upgrade
##Creating user for Chef Web UI
sudo chef-marketplace-ctl upgrade -y
chef-server-ctl reconfigure
chef-server-ctl restart
touch /var/opt/delivery/.telemetry.disabled
automate-ctl create-user default $1 --password $5
chef-server-ctl user-create $1 $2 $3 $4 $5 > /etc/opscode/$1.pem
chef-server-ctl org-create $6 "New Org" -a $1 > /etc/opscode/$6-validator.pem
#Upload key value.
#FINAL="\"}' "$7
#echo $validatorkey`cat /etc/opscode/${6}-validator.pem | base64 | tr -d '\n'`$FINAL| bash
#echo $userkey`cat /etc/opscode/${1}.pem | base64 | tr -d '\n'`$FINAL | bash
