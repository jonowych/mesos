
#!/bin/bash

echo
if [ "${USER}" = "root" ] ; then
   echo -e "$(tput setaf 1)!! Do not use sudo for installation$(tput sgr0)"
   exit 0 ; fi
duser="${USER}" 


echo && read -p "Install Mesosphere master node package (y)es?  " answer

CODENAME=$(lsb_release -cs)

# Add Mesosphere repository
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update

# Install packages on slave
sudo apt-get -y install mesos 		## include zookeeper

# Install packages on master
if [ answer = "y" ] ; then sudo apt-get -y install marathon, and chronos ; fi

echo && echo "$(tput setaf 6)!! Mesosphere installation has finished. !!$(tput sgr0)"
