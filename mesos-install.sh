#!/bin/bash

if [[ $1 != "master" && $1 != "slave" ]]
   then echo "!! $(tput setaf 1)Specify master or slave !!"
        echo $(tput sgr0) && exit ; fi

# zookeeper_ver=3.4.8-1
# mesos_ver=1.3.1-2.0.1
mesos_ver=1.1.1-2.0.1
# marathon_ver=1.4.8-1.0.660.ubuntu1604
marathon_ver=1.4.3-1.0.649.ubuntu1604
# chronos_ver=2.5.0-0.1.20170816233446.ubuntu1604

# Add GPG key for the official mesosphere repository
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Add mesosphere repository to APT sources
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

# Add repository according linux distro
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update

# Although mesos includes zookeeper, it requires downgraded versions of libevent-dev & libssl-dev.
# Those downgraded packages will break zookeeper daeman as "active (exited)".
# 
# Install zookeeperd before mesos to work around the problem.
sudo apt-get -y install zookeeperd

# Install Mesosphere packages
echo
if [ $1 = "slave" ] ; then

# disable zookeeper
   sudo systemctl stop zookeeper
   sudo systemctl disable zookeeper

# install meso
   echo "$(tput setaf 3)!! Installing Mesosphere $1 package. !!"
   sudo apt-get -y install mesos="$mesos_ver"	## include zookeeper
   echo $(tput sgr0) ; fi

if [ $1 = "master" ] ; then

# enable zookeeper
   sudo systemctl restart zookeeper
   sudo systemctl enable zookeeper

echo "$(tput setaf 3)!! Installing mesos=$mesos_ver !!$(tput sgr0)"
   sudo apt-get -y install mesos="$mesos_ver"
   # write config.yml

cat <<EOF_mesos > mesos-master.service
[Unit]
Description=Mesos Master Service
After=zookeeper.service
Requires=zookeeper.service

[Service]
ExecStart=/usr/local/sbin/mesos-master

[Install]
WantedBy=multi-user.target
EOF_mesos

   sudo mv mesos-master.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl start mesos-master.service
   sudo systemctl enable mesos-master

echo "$(tput setaf 3)!! Installing marathon=$marathon_ver !!$(tput sgr0)"
   sudo apt-get -y install marathon="$marathon_ver"

cat <<EOF_marathon > marathon.service
[Unit]
Description=Marathon Service
After=mesos-master.service
Requires=mesos-master.service

[Service]
ExecStart=/usr/local/bin/marathon

[Install]
WantedBy=multi-user.target
EOF_marathon

   sudo mv mesos-master.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl start marathon.service
   sudo systemctl enable marathon.service

echo "$(tput setaf 3)!! Installing chronos !!$(tput sgr0)"
   sudo apt-get -y install chronos

fi 

echo "$(tput setaf 6)!! Mesosphere installation has finished. !!$(tput sgr0)"
