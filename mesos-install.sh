#!/bin/bash

if [[ $1 = "master" || $1 = "slave" ]]
   then echo "$(tput setaf 6)Configuring Mesosphere $1 ....$(tput sgr0)"
   else echo "!! $(tput setaf 1)Specify master or slave !!"
        echo $(tput sgr0) && exit ; fi

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
if [ $1 = "slave" ] ; then
   echo "$(tput setaf 3)!! Installing Mesosphere $1 package. !!"
   sudo apt-get -y install mesos
   echo $(tput sgr0) ; fi

if [ $1 = "master" ] ; then 
   echo "$(tput setaf 3)!! Installing Mesosphere $1 package. !!"
   sudo apt-get -y install mesos marathon chronos
   echo $(tput sgr0) ; fi 

echo "$(tput setaf 6)!! Mesosphere installation has finished. !!$(tput sgr0)"
