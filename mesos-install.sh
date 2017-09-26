#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Please enter command as $(tput setaf 1)sudo $0 $(tput sgr0)!!"
   echo && exit ; fi

# Get existing IP information
echo && read -p "Enter first node number in cluster: " new

if ! [ $new -eq $new ] 2>/dev/null ; then
   echo "$(tput setaf 1)!! Exit -- Sorry, integer only !!$(tput sgr0)"
   exit ; fi
if [ -z $new ] || [ $new -lt 1 ] || [ $new -gt 254 ] ; then
   echo "$(tput setaf 1)!! Exit -- Please enter node number between 1 and 254 !!$(tput sgr0)"
   exit ; fi

read -p "How many nodes in Mesosphere cluster: " size

if ! [ $size -eq $size ] 2>/dev/null ; then
   echo "$(tput setaf 1)!! Exit -- Sorry, integer only !!$(tput sgr0)"
   exit ; fi
if [ -z $new ] || [ $size -lt 1 ] || [ $size -gt 10 ] ; then
   echo "$(tput setaf 1)!! Exit -- Please enter cluster size between 1 and 10 !!$(tput sgr0)"
   exit ; fi
   
exit   
   
new=$(echo $new | sed 's/^0*//')
intf=$(ifconfig | grep -m1 ^e | awk '{print $1 }')

oldhost=$(hostname)
oldip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{ print $2 }' | awk -F: '{ print $2 }')

# Begin with "#" are latest version 
# zookeeper_ver=3.4.8-1
# mesos_ver=1.3.1-2.0.1
# marathon_ver=1.4.8-1.0.660.ubuntu1604
# chronos_ver=2.5.0-0.1.20170816233446.ubuntu1604
# Set up mesos and marathon package version.
   marathon_ver=1.4.3-1.0.649.ubuntu1604
   mesos_ver=1.1.1-2.0.1

# Add GPG key for the official mesosphere repository
apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Add mesosphere repository to APT sources
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

# Add repository according linux distro
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
apt-get -y update

# Although mesos includes zookeeper, it requires downgraded versions of libevent-dev & libssl-dev.
# Those downgraded packages will break zookeeper daeman as "active (exited)".
# 
# Install zookeeperd before mesos to work around the problem.

# (1) Install zookeeper
   echo "$(tput setaf 3)!! Installing zookeeper !!$(tput sgr0)"
   apt-get -y install zookeeperd

# configure zookeeper ID and connection info in a temporary file
echo $new > /etc/zookeeper/conf/myid
for (( k=$new; k<`expr $new + $size`; k++))
do
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo "server.$k=zookeeper$k:2888:3888" >> zoo-temp
done

# import zookeeper connection info to system config files.
   k=`expr $(awk '/.2888.3888/{print NR;exit}' /etc/zookeeper/conf/zoo.cfg) - 1`
   sed -i -e '/.2888.3888/d' -e "$k r zoo-temp" /etc/zookeeper/conf/zoo.cfg
   rm zoo-temp

# Start zookeeper service after configuration set up
   systemctl start zookeeper
   systemctl enable zookeeper

# (2) Install mesos
   echo "$(tput setaf 3)!! Installing mesos=$mesos_ver !!$(tput sgr0)"
   apt-get -y install mesos="$mesos_ver"

# set up /etc/mesos/zk
echo -n "zk://"  > /etc/mesos/zk
for (( k=$new; k<`expr $new + $size - 1`; k++))
do
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo -n "$newip:2181," >> /etc/mesos/zk
done
   k=`expr $new + $size - 1`
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo "$newip:2181/mesos" >> /etc/mesos/zk

# set up quorum (>50% of master members in cluster)
   let "size = size/2 +size%2"
   echo $size > /etc/mesos-master/quorum

# set up mesos-master IP
   newip=$(echo $oldip | cut -d. -f4 --complement).$new
   echo $newip > /etc/mesos-master/ip
   echo $newip > /etc/mesos-master/hostname

# set up mesos-master.service
cat <<EOF_mesos > /etc/systemd/system/mesos-master.service
[Unit]
Description=Mesos Master Service
After=zookeeper.service
Requires=zookeeper.service

[Service]
ExecStart=/usr/sbin/mesos-master

[Install]
WantedBy=multi-user.target
EOF_mesos

# Start mesos-master service after configuration set up
   systemctl daemon-reload
   systemctl start mesos-master.service
   systemctl enable mesos-master

# (3) Install marathon
   echo "$(tput setaf 3)!! Installing marathon=$marathon_ver !!$(tput sgr0)"
   apt-get -y install marathon="$marathon_ver"

# set up marathon info data
   mkdir -p /etc/marathon/conf
   cp /etc/mesos-master/hostname /etc/marathon/conf/
   cp /etc/mesos/zk /etc/marathon/conf/master
   sed -i 's/mesos/marathon/' /etc/marathon/conf/master
   
# set up marathon startup service 
cat <<EOF_marathon > /etc/systemd/system/marathon.service
[Unit]
Description=Marathon Service
After=mesos-master.service
Requires=mesos-master.service

[Service]
ExecStart=/usr/bin/marathon

[Install]
WantedBy=multi-user.target
EOF_marathon

# Start marathod service after configuration set up
   systemctl daemon-reload
   systemctl start marathon.service
   systemctl enable marathon.service

# (4) Install chronos
   echo "$(tput setaf 3)!! Installing chronos !!$(tput sgr0)"
   apt-get -y install chronos
   
# set up chronos start up service
cat <<EOF_chronos > /etc/systemd/system/chronos.service
[Unit]
Description=Chronos Service
After=marathon.service
Requires=marathon.service

[Service]
ExecStart=/usr/bin/chronos

[Install]
WantedBy=multi-user.target
EOF_chronos

# Start chronos service after configuration set up
   systemctl daemon-reload
   systemctl start chronos.service
   systemctl enable chronos.service

# ------------
echo $(tput setaf 6)
echo "!! Mesosphere installation has finished. !!"
echo $(tput sgr0)
