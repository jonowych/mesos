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
ID=$(echo $oldip | awk -F. '{print $4}')

systemctl stop chronos.service
systemctl stop marathon.service
systemctl stop mesos-slave.service
systemctl stop mesos-master.service
systemctl stop zookeeper.service

first=$(cat /etc/mesos/cluster | awk -F, '{print $1}')
size=$(cat /etc/mesos/cluster | awk -F, '{print $2}')

if [ $ID -lt $first ] || [ $ID -ge `expr $first + $size` ] ; then
   echo "!! Updating Mesosphere $(tput setaf 6)slave configuration$(tput sgr0) !!"
   systemctl disable chronos.service
   systemctl disable marathon.service
   systemctl disable mesos-master.service
   systemctl disable zookeeper.service

   apt-get purge -y chronos marathon mesos-master zookeeper
   rm /etc/systemd/system/chronos.service
   rm /etc/systemd/system/marathon.service
   rm /etc/systemd/system/mesos-master.service
   rm /etc/systemd/system/zookeeper.service
   
# set up mesos-slave.service
cat <<EOF_mesos > /etc/systemd/system/mesos-slave.service
[Unit]
   Description=Mesos Slave Service
[Service]
   ExecStart=/usr/sbin/mesos-slave --master=file:///etc/mesos/zk --work_dir=/var/lib/mesos
[Install]
   WantedBy=multi-user.target
EOF_mesos

# Start mesos-slave service after configuration set up
   systemctl daemon-reload
   systemctl start mesos-slave.service
   systemctl enable mesos-slave
   
else
   echo "!! Updating Mesosphere $(tput setaf 6)master configuration$(tput sgr0) !!"
   # Update zookeeper ID
     echo $new > /etc/zookeeper/conf/myid

# update mesos-master.service
   mesos_ip=$(cat /etc/systemd/system/mesos-master.service | grep ExecStart | awk -F= '{print $3}' | awk '{print $1}')
   sed -i "s/$mesos_ip/$oldip/" /etc/systemd/system/mesos-master.service

# Start mesos-master service after configuration set up
   systemctl daemon-reload
   systemctl start mesos-master.service
   systemctl enable mesos-master
   
fi

echo Restarting ........
shutdown -r now
