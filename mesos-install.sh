#!/bin/bash

# Add GPG key for the official mesosphere repository
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Add mesosphere repository to APT sources
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

# Add repository according linux distro
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update

# Install packages on slave
sudo apt-get -y install mesos 		## include zookeeper

# Install packages on master
echo
if [ $# -eq 1 ] 
   then if [ $1 = "master" ] 
        then echo "$(tput setaf 3)!! Installing Mesosphere master package. !!$(tput sgr0)"
             sudo apt-get -y install marathon chronos
        else echo -e "!! Enter $(tput setaf 1)$0 master$(tput sgr0) for master installation!!"
        fi
   echo
   fi

echo "$(tput setaf 6)!! Mesosphere installation has finished. !!$(tput sgr0)"
