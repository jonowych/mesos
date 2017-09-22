#!/bin/bash

if [[ $1 != "master" && $1 != "slave" ]]
   then echo "!! $(tput setaf 1)Specify master or slave !!"
        echo $(tput sgr0) && exit ; fi

# Add GPG key for the official mesosphere repository
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Add mesosphere repository to APT sources
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

# Add repository according linux distro
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update

# > sudo apt-get install libevent-dev
# > sudo apt-get install libssl-dev
# Above install command get below output in "libssl-dev" :
#
# libssl-dev : Depends: libssl1.0.0 (= 1.0.2g-1ubuntu4) 
#                         but 1.0.2g-1ubuntu4.8 is to be installed
#
# force downgrade of libssl1.0.0 and libevent-2.0-5

# sudo apt-get install libssl1.0.0=1.0.2g-1ubuntu4 libevent-2.0-5=2.0.21-stable-2

sudo apt-get install zookeeperd

# Install Mesosphere packages
echo
if [ $1 = "slave" ] ; then
   echo "$(tput setaf 3)!! Installing Mesosphere $1 package. !!"
   sudo apt-get -y install mesos	## include zookeeper
   echo $(tput sgr0) ; fi

if [ $1 = "master" ] ; then 
   echo "$(tput setaf 3)!! Installing Mesosphere $1 package. !!"
   sudo apt-get -y install mesos marathon chronos
   echo $(tput sgr0) ; fi 

echo "$(tput setaf 6)!! Mesosphere installation has finished. !!$(tput sgr0)"
