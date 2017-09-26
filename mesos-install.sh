#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Enter command as $(tput setaf 1)sudo $0 <arg> !!"
   echo $(tput sgr0) && exit ; fi

# zookeeper_ver=3.4.8-1
# mesos_ver=1.3.1-2.0.1
mesos_ver=1.1.1-2.0.1
# marathon_ver=1.4.8-1.0.660.ubuntu1604
marathon_ver=1.4.3-1.0.649.ubuntu1604
# chronos_ver=2.5.0-0.1.20170816233446.ubuntu1604

# Add GPG key for the official mesosphere repository
apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Add mesosphere repository to APT sources
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

# Add repository according linux distro
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
apt-get -y update

# Get existing IP information
echo
read -p "How many nodes in Mesosphere cluster: " size
read -p "Enter first node number in cluster: " new

if ! [ $new -eq $new ] 2>/dev/null ; then
        echo "$(tput setaf 1)!! Exit -- Sorry, integer only !!$(tput sgr0)"
        exit ; fi
if [ -z $new ] || [ $new -lt 1 ] || [ $new -gt 254 ] ; then
        echo "$(tput setaf 1)!! Exit -- node number out of range !!$(tput sgr0)"
        exit ; fi

new=$(echo $new | sed 's/^0*//')
intf=$(ifconfig | grep -m1 ^e | awk '{print $1 }')

oldhost=$(hostname)
oldip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{ print $2 }' | awk -F: '{ print $2 }')

# Although mesos includes zookeeper, it requires downgraded versions of libevent-dev & libssl-dev.
# Those downgraded packages will break zookeeper daeman as "active (exited)".
# 
# Install zookeeperd before mesos to work around the problem.

# ------------
echo "$(tput setaf 3)!! Installing zookeeper !!$(tput sgr0)"
apt-get -y install zookeeperd

# set up zookeeper connection info in a temporary file
for (( k=$new; k<`expr $new + $size`; k++))
do
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo "server.$k=zookeeper$k:2888:3888" >> zoo-temp
done

# import zookeeper connection info to system config files.
k=`expr $(awk '/.2888.3888/{print NR;exit}' /etc/zookeeper/conf/zoo.cfg) - 1`
sed -i -e '/.2888.3888/d' -e "$k r zoo-temp" /etc/zookeeper/conf/zoo.cfg
rm zoo-temp

systemctl start zookeeper
systemctl enable zookeeper

# ------------
echo "$(tput setaf 3)!! Installing mesos=$mesos_ver !!$(tput sgr0)"
apt-get -y install mesos="$mesos_ver"

cat <<EOF_mesos > /etc/systemd/system/mesos-master.service
[Unit]
Description=Mesos Master Service
After=zookeeper.service
Requires=zookeeper.service

[Service]
ExecStart=/usr/local/sbin/mesos-master

[Install]
WantedBy=multi-user.target
EOF_mesos

systemctl daemon-reload
systemctl start mesos-master.service
systemctl enable mesos-master

# ------------
echo "$(tput setaf 3)!! Installing marathon=$marathon_ver !!$(tput sgr0)"
apt-get -y install marathon="$marathon_ver"

cat <<EOF_marathon > /etc/systemd/system/marathon.service
[Unit]
Description=Marathon Service
After=mesos-master.service
Requires=mesos-master.service

[Service]
ExecStart=/usr/local/bin/marathon

[Install]
WantedBy=multi-user.target
EOF_marathon

systemctl daemon-reload
systemctl start marathon.service
systemctl enable marathon.service

# ------------
echo "$(tput setaf 3)!! Installing chronos !!$(tput sgr0)"
apt-get -y install chronos
   
cat <<EOF_chronos > /etc/systemd/system/chronos.service
[Unit]
Description=Chronos Service
After=marathon.service
Requires=marathon.service

[Service]
ExecStart=/usr/local/bin/chronos

[Install]
WantedBy=multi-user.target
EOF_chronos

systemctl daemon-reload
systemctl start chronos.service
systemctl enable chronos.service

# ------------
echo "$(tput setaf 6)!! Mesosphere installation has finished. !!$"
echo $(tput sgr0)
