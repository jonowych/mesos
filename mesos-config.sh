#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Please enter command as $(tput setaf 1)sudo $0 $(tput sgr0)!!"
   echo && exit ; fi

# Get existing IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
oldhost=$(hostname)
oldip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
ID=$(echo $oldip | awk -F. '{print $4}')

# Update mesos service file
cd /etc/systemd/system/
if [ -e mesos-master.service ] ; then
   echo "!! Updating Mesosphere $(tput setaf 6)master configuration$(tput sgr0) !!"
   # Update zookeeper ID
     echo $ID > /etc/zookeeper/conf/myid

   # update mesos-master.service
     mesosip=$(cat mesos-master.service | grep ExecStart | awk -F= '{print $3}' | awk '{print $1}')
     sed "s/$mesosip/$oldip/" mesos-master.service

   # Start mesos-master service after configuration set up
     systemctl daemon-reload
     systemctl start mesos-master.service
     systemctl enable mesos-master

else
   if [ ! -e mesos-slave.service ] ; then
 
   # Download /etc/mesos/zk from master node
     echo && read -p "Please enter master node number: " master
     masterip=$(echo $oldip | cut -d. -f4 --complement).$master
     ping -q -c3 $masterip > /dev/null
     if [ $? -ne 0 ] ; then echo "No response from node $masterip" && exit
     else scp sydadmin@$masterip:/etc/mesos/zk /tmp/ ; fi

     echo "$(tput setaf 3)!! Installing mesos on slave machine !!$(tput sgr0)"
     apt-get -y install mesos

# set up mesos-slave.service
cat <<EOF_mesos > /etc/systemd/system/mesos-slave.service
[Unit]
   Description=Mesos Slave Service

[Service]
   ExecStart=/usr/sbin/mesos-slave --master=$(cat /tmp/zk) --work_dir=/var/lib/mesos

[Install]
   WantedBy=multi-user.target
EOF_mesos

   # Start mesos-slave service after configuration set up
     systemctl daemon-reload
     systemctl start mesos-slave.service
     systemctl enable mesos-slave
   fi
fi

echo VM will restart in 10 seconds ........
sleep 10
exit
shutdown -r now
