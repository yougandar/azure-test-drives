#!/bin/bash
set -e
echo $(date) " - Starting Script"

DBNAME=$1
DBUSER=$2
DBPASSWORD=$3
DBENDPOINT=$4
DBPORT=4006
sleep 10
clear
cd /
apt-get update
apt-get install -y gcc make automake apache2 php5 php5-mysql php5-gd libssh2-php libapache2-mod-php5 php5-mcrypt unzip
service apache2 restart
apt-get install -y software-properties-common
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
add-apt-repository 'deb http://ftp.kaist.ac.kr/mariadb/repo/5.5/ubuntu precise main'
apt-get update
apt-get install -y mariadb-client
#------------------------------------------------------------------------------------------
clear
#Chanage dir to doucument root
cd /var/www/
#download wordpress
curl -O https://wordpress.org/latest.tar.gz
#unzip wordpress
tar -zxvf latest.tar.gz
#change dir to wordpress
cd wordpress
#create wp config
cp wp-config-sample.php wp-config.php
#set database details with perl find and replace
perl -pi -e "s/database_name_here/$1/g" wp-config.php
perl -pi -e "s/username_here/$2/g" wp-config.php
perl -pi -e "s/password_here/$3/g" wp-config.php
perl -pi -e "s/localhost/$4:$DBPORT/g" wp-config.php
#set WP salts
perl -i -pe'
  BEGIN {
    @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
    push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
    sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
 }
  s/put your unique phrase here/salt()/ge
' wp-config.php

#create uploads folder and set permissions
#mkdir wp-content/uploads
#chmod -R 775 /var/www/wordpress
#chown -R root:root /var/www/wordpress
echo "Cleaning..."
#remove zip file
rm /var/www/latest.tar.gz
chmod -R 775 /var/www/
#remove bash script
#rm wp.sh
/etc/init.d/apache2 restart
echo "========================="
echo "Installation is complete."
echo "========================="