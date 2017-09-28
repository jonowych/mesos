#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Please enter command as $(tput setaf 1)sudo $0 $(tput sgr0)!!"
   echo && exit ; fi

read -p "How many nodes in Mesosphere cluster: " size
if ! [ $size -eq $size ] 2>/dev/null ; then
   echo "$(tput setaf 1)!! Exit -- Sorry, integer only !!$(tput sgr0)"
   exit ; fi
if [ -z $size ] || [ $size -lt 1 ] || [ $size -gt 10 ] ; then
   echo "$(tput setaf 1)!! Exit -- Please enter cluster size between 1 and 10 !!$(tput sgr0)"
   exit ; fi

# Get existing IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
oldhost=$(hostname)
oldip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
ID=$(echo $oldip | awk -F. '{print $4}')

# Below are latest versions on 20170927 
# zookeeper_ver=3.4.8-1
# mesos_ver=1.3.1-2.0.1
# marathon_ver=1.4.8-1.0.660.ubuntu1604
# chronos_ver=2.5.0-0.1.20170816233446.ubuntu1604
# Set up mesos and marathon package version.
#   marathon_ver=1.4.3-1.0.649.ubuntu1604
#   mesos_ver=1.1.1-2.0.1

# Add GPG key for the official mesosphere repository
apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Add mesosphere repository to APT sources
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

# Add repository according linux distro
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
apt-get -y update

# (1) Install zookeeper
   echo "$(tput setaf 3)!! Installing zookeeper !!$(tput sgr0)"
   apt-get -y install zookeeperd

# configure zookeeper ID and connection info in a temporary file
echo $ID > /etc/zookeeper/conf/myid
for (( k=$ID; k<`expr $ID + $size`; k++))
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
   echo "$(tput setaf 3)!! Installing mesos $mesos_ver !!$(tput sgr0)"
   apt-get -y install mesos
   
# set up /etc/mesos/zk
echo -n "zk://"  > /etc/mesos/zk
for (( k=$ID; k<`expr $ID + $size - 1`; k++))
do
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo -n "$newip:2181," >> /etc/mesos/zk
done
   k=`expr $ID + $size - 1`
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo "$newip:2181/mesos" >> /etc/mesos/zk

# set up quorum (>50% of master members in cluster)
   let "k = size/2 +size%2"

# set up mesos-master IP
   newip=$(echo $oldip | cut -d. -f4 --complement).$ID

# set up mesos-master.service
cat <<EOF_mesos > /etc/systemd/system/mesos-master.service
[Unit]
   Description=Mesos Master Service
   After=zookeeper.service
   Requires=zookeeper.service

[Service]
   ExecStart=/usr/sbin/mesos-master --ip=$newip --hostname=$newip --zk=$(cat /etc/mesos/zk) --quorum=$k --work_dir=/var/lib/mesos

[Install]
   WantedBy=multi-user.target
EOF_mesos

# Start mesos-master service after configuration set up
   systemctl daemon-reload
   systemctl start mesos-master.service
   systemctl enable mesos-master

# (3) Install marathon
   echo "$(tput setaf 3)!! Installing marathon $marathon_ver !!$(tput sgr0)"
   apt-get -y install marathon

# set up marathon info data
   mkdir -p /etc/marathon/conf
   echo $newip > /etc/marathon/conf/hostname
   
# set up marathon startup service 
cat <<EOF_marathon > /etc/systemd/system/marathon.service
[Unit]
   Description=Marathon Service
   After=mesos-master.service
   Requires=mesos-master.service

[Service]
   ExecStart=/usr/bin/marathon --master $(cat /etc/mesos/zk) --zk $(cat /etc/mesos/zk | sed 's/mesos/marathon/')

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

echo Master node will restart in 10 seconds ........
sleep 10
shutdown -r now
