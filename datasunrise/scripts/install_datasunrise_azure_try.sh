#!/bin/bash

datasunrise_pass=$1
pg_pass=$2

#configure firewall
echo '<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>datasunrise</short>
  <description>DataSunrise Web Interface.</description>
  <port protocol="tcp" port="11000"/>
  <port protocol="tcp" port="5432"/>
  <port protocol="tcp" port="54321"/>
</service>' >> /usr/lib/firewalld/services/datasunrise.xml
sed 's/ssh"\/>/ssh"\/>\n  <service name="datasunrise"\/>/' /usr/lib/firewalld/zones/public.xml -i
sed 's/ssh"\/>/ssh"\/>\n  <service name="datasunrise"\/>/' /etc/firewalld/zones/public.xml -i
firewall-cmd --reload

#update and install soft
#yum update -y
yum install unixODBC mysql-connector-odbc.x86_64 postgresql-odbc.x86_64 java postgresql-server -y
wget https://update.datasunrise.com/get-last-datasunrise?cloud=azure -O /tmp/datasunrise.run
chmod +x /tmp/datasunrise.run
/tmp/datasunrise.run install -f
rm -f /tmp/datasunrise.run


#configure postgres
mkdir /usr/local/pgsql
chown postgres:postgres /usr/local/pgsql
su postgres -c "initdb -D /usr/local/pgsql/data -U postgres"
awk 'BEGIN {OFS="\t"} {if ($1 != "#" && NF > 0 && NF > 4) {$5 = "md5"; print} else {print}}' /usr/local/pgsql/data/pg_hba.conf > /tmp/pg_hba.conf
echo 'port = 54321' >> /usr/local/pgsql/data/postgresql.conf
mv /tmp/pg_hba.conf  /usr/local/pgsql/data/pg_hba.conf
su postgres -c "pg_ctl start -D /usr/local/pgsql/data/"

#set license
curl http://95.211.162.209:9000/generateKey?customer=AzureTestDrive\;os=OS_LINUX  > /opt/datasunrise/appfirewall.reg

#set datasunrise password
cd /opt/datasunrise
/opt/datasunrise/AppBackendService SET_ADMIN_PASSWORD=$datasunrise_pass
service datasunrise restart

#configure datasunrise for postgres
AF_STATE_DIR=/tmp
cd /opt/datasunrise/cmdline
chmod +x executecommand.sh
./executecommand.sh connect -host 127.0.0.1 -password "$datasunrise_pass" -login admin
psql -p 54321 postgres postgres -c "ALTER USER postgres WITH PASSWORD '$pg_pass';"
./executecommand.sh addInstancePlus -name PostgresTestDb -dbType postgresql -dbHost 127.0.0.1 -dbPort 54321 -database postgres  -login postgres -password "$pg_pass" -proxyHost 0.0.0.0 -proxyPort 5432
./executecommand.sh addRule -action audit -name AuditRuleAdmin -logData true -filterType ddl -ddlSelectAll true
./executecommand.sh addRule -action audit -name AuditRuleDML -logData true

exit 0
