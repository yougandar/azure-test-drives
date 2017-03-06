#!/bin/bash

if [ -e "DgSecure-linux-x64-sn-installer.run" ] 
then
  echo "DgSecure setup already exists, skipping download"
else
  echo "Downloading DgSecure binaries"
  wget https://s3.amazonaws.com/dgsecure/azure/DgSecure-linux-x64-sn-installer.run -O DgSecure-linux-x64-sn-installer.run
fi

wget https://s3.amazonaws.com/dgsecure/azure/InstallDgSecureSN.sh -O InstallDgSecureSN.sh

chmod +x InstallDgSecureSN.sh
chmod +x DgSecure-linux-x64-sn-installer.run

if which java >/dev/null 2>&1 ; then
  echo "Java installation found, skipping Java install."
else
  echo "Java not found. Downloading and installing Java."
  echo "\n" | sudo add-apt-repository ppa:webupd8team/java
  sudo apt-get update
  echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
  sudo apt-get -y install oracle-java7-installer
  sudo apt-get install oracle-java7-set-default

fi

echo "Creating /var/lock/subsys directory"
sudo mkdir /var/lock/subsys 

echo "Installing DgSecure.."
sudo sh InstallDgSecureSN.sh
echo "DgSecure Installation finished."

echo "Copying hadoop jars to DgSecure Agent lib folder."
sudo rm -rf /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/lib/*-2041.jar
sudo rm -rf /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/lib/*-2041.jar

sudo cp /usr/hdp/*/hadoop/hadoop-azure-*.jar /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/lib
sudo cp /usr/hdp/*/hadoop/client/azure-*.jar /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/lib
sudo cp /usr/hdp/*/hadoop/client/hadoop-*.jar /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/lib
sudo cp /usr/hdp/*/hadoop/client/jetty-util*.jar /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/lib
sudo cp /usr/hdp/*/hadoop-mapreduce/hadoop-mapreduce-client-hs*.jar /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/lib

sudo cp /usr/hdp/*/hadoop/hadoop-azure-*.jar /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/lib
sudo cp /usr/hdp/*/hadoop/client/azure-*.jar /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/lib
sudo cp /usr/hdp/*/hadoop/client/hadoop-*.jar /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/lib
sudo cp /usr/hdp/*/hadoop/client/jetty-util*.jar /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/lib
sudo cp /usr/hdp/*/hadoop-mapreduce/hadoop-mapreduce-client-hs*.jar /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/lib

sudo chmod 755 /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/lib/*
sudo chmod 755 /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/lib/*

echo "Remove jersey-core-1.9.jar file for MonitoringAgent"
sudo rm -rf /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/lib/jersey-core-1.9.jar

echo "Updating HDFSAgentConfig.properties with correct cluster values.."
fsname=`grep wasb.*\/.*blob.core.windows.net /etc/hadoop/conf/core-site.xml -o`
tracker=`echo $fsname | cut -c 8-`
namenode_host=`cat /etc/hadoop/conf/hdfs-site.xml | grep hn0.*: -o | head -n 1 | cut -d':' -f1`
namenode_ip=`nslookup $namenode_host | grep "Address: " | grep -oE "[0-9]+.[0-9]+.[0-9]+.[0-9]+"`
#namenode_ip=`cat /etc/hosts | grep headnode0 | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' -o`
local_ip=`ifconfig eth0 | grep inet | grep -E 'addr:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' -o | cut -c 6-`

sudo sed -i 's/fs.default.name=.*$/fs.default.name=wasb:\/\/'$tracker'/g' /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/mapred.job.tracker=.*$/mapred.job.tracker='$tracker'/g' /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/user=.*$/user=hdfs/g' /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/YARN=.*$/YARN=Y/g' /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/cluster.namenode.ip=.*$/cluster.namenode.ip='$namenode_ip'/g' /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/controller.url=.*$/controller.url=http\\\:\/\/'$local_ip'\\\:10181/g' /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/acl.source=.*$/acl.source=controller/g' /opt/Dataguise/DgSecure/Agents/HDFSAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties

echo "Updating HDFSAgentConfig.properties for MonitoringAgent with correct cluster values.."
sudo sed -i 's/fs.default.name.*=.*$/fs.default.name=wasb:\/\/'$tracker'/g' /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/mapred.job.tracker.*=.*$/mapred.job.tracker='$tracker'/g' /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/user.*=.*$/user=hdfs/g' /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/YARN.*=.*$/YARN=Y/g' /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties
sudo sed -i 's/distro.*=.*$/distro=hw/g' /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/classes/com/dataguise/hadoop/util/HDFSAgentConfig.properties

echo "Updating DgConnection.properties for MonitoringAgent with correct schma name.."
sudo sed -i 's/schemaName.*=.*dg35.*$/schemaName = controller/g' /opt/Dataguise/DgSecure/Agents/MonitoringAgent/expandedArchive/WEB-INF/classes/com/dataguise/monitor/agent/hibernate/DgConnection.properties

echo "Updating catalina.sh in DgSecure tomcat with proper Hadoop version"
HDP_VERSION=`ls /usr/hdp | sed -e "s/current//g"`
CATALINA_JAVA_OPT='JAVA_OPTS="$JAVA_OPTS -Dhdp.version=/'$HDP_VERSION'/"'
sudo echo $CATALINA_JAVA_OPT >> /opt/Dataguise/DgSecure/tomcat7/bin/catalina.sh

echo "Updating jetty.properties with proper hadoop version"
sudo sed -i 's/Dhdp.version=.*$/Dhdp.version='$HDP_VERSION'/g' /opt/Dataguise/DgSecure/Agents/HDFSAgent/jetty-embedded.properties
sudo sed -i 's/Dhdp.version=.*$/Dhdp.version='$HDP_VERSION'/g' /opt/Dataguise/DgSecure/Agents/MonitoringAgent/jetty-embedded.properties

echo "Installing license"
wget https://s3.amazonaws.com/dgsecure/azure/license/dgdump_build5.1.1.8.tar.gz -O /tmp/dgdump_build5.1.1.8.tar.gz
wget https://s3.amazonaws.com/dgsecure/azure/license/runrestore.sh -O /tmp/runrestore.sh
wget https://s3.amazonaws.com/dgsecure/azure/license/updatelic.sh -O /tmp/updatelic.sh
chmod +x /tmp/runrestore.sh
chmod +x /tmp/updatelic.sh
sudo sh /tmp/runrestore.sh
sudo sh /tmp/updatelic.sh

echo "Restarting tomcat"
sudo sh /opt/Dataguise/DgSecure/tomcat7/stop.sh
sleep 10
sudo sh /opt/Dataguise/DgSecure/tomcat7/start.sh

echo "Restarting Jetty for HDFSAgent"
sudo /etc/init.d/DgSecureHDFSAgent stop
sleep 10
sudo /etc/init.d/DgSecureHDFSAgent start

echo "Restarting Jetty for MonitoringAgent"
sudo /etc/init.d/DgSecureMonitoringAgent stop
sleep 10
sudo /etc/init.d/DgSecureMonitoringAgent start

echo "Downloading sample data and putting it in HDFS"
wget https://s3.amazonaws.com/dgsecure/azure/data/payroll.csv -O payroll.csv
wget https://s3.amazonaws.com/dgsecure/azure/data/charter_one.txt -O charter_one.txt

hadoop fs -mkdir /HR
hadoop fs -mkdir /Sales
hadoop fs -mkdir /Marketing
hadoop fs -mkdir /Support
hadoop fs -mkdir /Engineering
hadoop fs -mkdir /Finance
hadoop fs -mkdir /Consulting
hadoop fs -mkdir /ProductManagement
hadoop fs -put payroll.csv /Marketing
hadoop fs -put payroll.csv /Support
hadoop fs -put payroll.csv /Engineering
hadoop fs -put payroll.csv /Finance
hadoop fs -put payroll.csv /Consulting
hadoop fs -put payroll.csv /ProductManagement
hadoop fs -put charter_one.txt /HR
hadoop fs -put charter_one.txt /Sales

echo "Creating hdfs linux user.."
sudo adduser hdfs --gecos "" --disabled-password
echo "hdfs:hdfs" | sudo chpasswd
echo "All Done."