#####################################################################################################################
#                                                                                               
#       script to install docker on Ubuntu 16.10                                                
#       usage:  sh docker-install.sh                                                                                
#####################################################################################################################

#!/bin/bash
pstatus=`ps -eaf | grep apt.systemd.daily | wc -l`
while [ $pstatus -gt 1 ]; do sleep 180; pstatus=`ps -eaf | grep apt.systemd.daily | wc -l`; done
#Update apt and install required certificates
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates

#Add the GPG key to apt
sudo apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

#Add the docker repo to the apt list
sudo sh -c 'echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" > /etc/apt/sources.list.d/docker.list'

#Update apt
sudo apt-get update

#Install the docker engine
sudo apt-get install -y docker-engine

#Start the docker daemon
sudo service docker start

sudo systemctl enable docker

sudo docker pull webgoat/webgoat-7.1
sleep 90
sudo docker run -p 8080:8080 webgoat/webgoat-7.1 > /dev/null &

exit 0
