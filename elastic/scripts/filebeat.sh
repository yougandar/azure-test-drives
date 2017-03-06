#!/bin/bash

# Install Filebeat Package

echo "deb https://packages.elastic.co/beats/apt stable main" |  sudo tee -a /etc/apt/sources.list.d/beats.list

wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

sudo apt-get update

sudo apt-get -y install filebeat

sudo service filebeat restart