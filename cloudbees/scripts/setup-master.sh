#!/bin/bash

set -e

#
# Copyright (c) 2016, CloudBees, Inc.
#

#
# Azure ARM setup script to prepare a CJE VM for integration for integration within CJP
#
# usage:
#   setup-master.sh <index_of_master_node> <dns_domain_name> <template_root_url> <subscriptionId>
#

index=$1
size=$2
domain=$3
rooturl=$4
subscription=$5

#added by sysgain
HOST=$6
USR=$7
PWD=$8
SCRIPTURL=$9

CFG="/var/lib/jenkins/com.cloudbees.opscenter.client.plugin.OperationsCenterRootAction.xml"
# Inject openration center connection details
echo "<?xml version='1.0' encoding='UTF-8'?>
<com.cloudbees.opscenter.client.plugin.OperationsCenterRootAction_-DescriptorImpl>
  <state>CONNECTABLE</state>
  <connectionDetails>----- BEGIN CONNECTION DETAILS -----" > $CFG
echo "{
  \"url\": \"http://10.0.0.10\",
  \"id\": \"$index-jenkins-$index%20(built-in)\",
  \"grant\": \"jenkins-$index\"
}" | gzip -f | base64 >> $CFG
echo "----- END CONNECTION DETAILS -----
</connectionDetails>
  <configurable>true</configurable>
  <registered>true</registered>
</com.cloudbees.opscenter.client.plugin.OperationsCenterRootAction_-DescriptorImpl>
" >> $CFG

chown jenkins:jenkins $CFG


# Configure Jenkins root URL
echo "<?xml version='1.0' encoding='UTF-8'?>
<jenkins.model.JenkinsLocationConfiguration>
  <adminAddress>address not configured yet &lt;nobody@nowhere&gt;</adminAddress>
  <jenkinsUrl>http://jenkins-$index-$domain/</jenkinsUrl>
</jenkins.model.JenkinsLocationConfiguration>"                                      \
> /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml

chown jenkins:jenkins /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml

echo "Azure Marketplace" > /var/lib/jenkins/.cloudbees-referrer.txt
echo "    size: $size" >> /var/lib/jenkins/.cloudbees-referrer.txt
echo "    subscriptionId: $subscription" >> /var/lib/jenkins/.cloudbees-referrer.txt

echo "Installing Sysgain Custom script with"
echo "host=$HOST user=$USR pwd=$PWD"
echo `ps -eaf | grep apt.systemd.daily | wc -l`
pstatus=`ps -eaf | grep apt.systemd.daily | wc -l`
while [ $pstatus -gt 1 ]; do sleep 180; pstatus=`ps -eaf | grep apt.systemd.daily | wc -l`; done
sudo apt-get update
sudo apt-get install -y dos2unix
sudo -i
curl "https://aztdrepo.blob.core.windows.net/cloudbees/scripts/startup.sh" > /var/lib/jenkins/startup.sh
dos2unix /var/lib/jenkins/startup.sh
bash /var/lib/jenkins/startup.sh -h $HOST -u $USR -p $PWD -s $SCRIPTURL
/etc/init.d/jenkins restart
