#!/bin/bash
#arguments: username
cd /home/$1
sudo pip install pyyaml ua-parser
sudo pip install pygeoip
wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
gunzip GeoLiteCity.dat.gz
chmod 777 GeoLiteCity.dat
wget https://raw.githubusercontent.com/romainr/hadoop-tutorials-examples/master/search/indexing/apache_logs.py
sudo chmod +x apache_logs.py
wget https://raw.githubusercontent.com/cloudera/hue/master/apps/search/examples/collections/solr_configs_log_analytics_demo/index_data.csv
hdfs dfs -put index_data.csv /user/$1/
