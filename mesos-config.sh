#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Please enter command as $(tput setaf 1)sudo $0 $(tput sgr0)!!"
   echo && exit ; fi

if [ -z $(which mesos) ] ; then
   echo "!!$(tput setaf 1) mesos is not installed $(tput sgr0)!!"
   echo && exit ; fi

# Get existing IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
oldhost=$(hostname)
oldip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
new=$(echo $oldip | awk -F. '{print $4}')
sed -i "s/127.0.1.1/$oldip/" /etc/hosts

echo
echo "$(tput setaf 6)!! Update $1 node name from $oldhost to $newhost !!"
echo "!! Update node IP from $oldip to $newip !! $(tput sgr0)"
echo && echo System will restart in 10 seconds
sleep 10

systemctl stop chronos.service
systemctl stop marathon.service
systemctl stop mesos-slave.service
systemctl stop mesos-master.service
systemctl stop zookeeper.service

first=$(cat /etc/mesos/cluster | awk -F, '{print $1}')
size=$(cat /etc/mesos/cluster | awk -F, '{print $2}')

if [ $new -lt $first ] || [ $new -ge `expr $first + $size` ] ; then
   echo "!! Updating Mesosphere $(tput setaf 6)slave configuration$(tput sgr0) !!"
   systemctl disable chronos.service
   systemctl disable marathon.service
   systemctl disable mesos-master.service
   systemctl disable zookeeper.service

   apt-get purge -y chronos marathon mesos-master zookeeper


[Unit]
Description=Mesos Slave Service

[Service]
ExecStart=/usr/local/sbin/mesos-slave --master=zk://192.168.1.30:2181,192.168.1.31:2181,192.168.1.32:2181/mesos --work_dir=/var/lib/mesos

[Install]
WantedBy=multi-user.target






else
   echo "!! Updating Mesosphere $(tput setaf 6)master configuration$(tput sgr0) !!"
   # Update zookeeper ID
     echo $new > /etc/zookeeper/conf/myid
   # Update mesos-master.service
     sed -i "s/$oldip/$newip/g" /etc/systemd/system/mesos-master.service
fi

echo Restarting ........
shutdown -r now
