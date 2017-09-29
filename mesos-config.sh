#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
	echo "!! Please enter command as $(tput setaf 1)sudo $0 $(tput sgr0)!!"
	echo && exit ; fi

read -p "How many master nodes in cluster, [enter] for no change: " size

cd /etc/systemd/system/
if ! [ $size -eq $size ] 2>/dev/null ; then
	echo -n $(tput setaf 1)
	echo "!! Exit -- Sorry, integer only !!"
	echo $(tput sgr0) && exit 

elif [ -z $size ] ; then
	if [ -e mesos-master.service ] ; then mesos=0m
	elif [ -e mesos-slave.service ] ; then mesos=0s
	else mesos=0new	; fi

elif [ $size -lt 1 ] || [ $size -gt 9 ] ; then
	echo -n $(tput setaf 1)
	echo "!! Exit -- Please enter cluster size between 1 and 9 !!"
	echo $(tput sgr0) && exit

else
	if [ -e mesos-master.service ] ; then mesos=1m
	elif [ -e mesos-slave.service ] ; then mesos=1s
	else mesos=1new	; fi
fi

# Get system IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
syshost=$(hostname)
sysip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
sysnode=$(echo $sysip | awk -F. '{print $4}')

case $mesos in

0m) 
echo "$(tput setaf 6)!! This is mesos master node !!$(tput sgr0)"
echo "Update mesos-master.service with system IP."

#get zookeeper IP information 
	zoonode=$(cat /etc/zookeeper/conf/myid)
	zooip=$(echo $sysip | cut -d. -f4 --complement).$zoonode
	echo $sysnode > /etc/zookeeper/conf/myid
# Update mesos-master.service
	sed -i "s/=$zooip/=$sysip/g" mesos-master.service
;;

0s)
echo "$(tput setaf 6)!! This is mesos slave node !!$(tput sgr0)"
echo "No need to change mesos-slave.service and cluster configuration." 
;;

0new)
echo "$(tput setaf 6)!! This is new node !!$(tput sgr0)"

# Add GPG key for the official mesosphere repository
	apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Add mesosphere repository to APT sources
	DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

# Add repository according linux distro
	CODENAME=$(lsb_release -cs)
	echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list

# Download /etc/mesos/zk from master node
	echo && read -p "Please enter master node number: " master
	masterip=$(echo $sysip | cut -d. -f4 --complement).$master

	ping -q -c3 $masterip > /dev/null
	if [ $? -ne 0 ] ; then 
		echo "$(tput setaf 1)!! No response from node $masterip !!$(tput sgr0)" && exit
	else 
		scp sydadmin@$masterip:/etc/mesos/zk /tmp/
	fi
# Install mesos package
	echo "Installing mesos-slave package in node."
	apt-get -y update
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
	echo "$(tput setaf 3)!! Mesos-slave has been installed in node !!$(tput sgr0)"
;;

1m)
echo "$(tput setaf 6)!! This is mesos master node !!$(tput sgr0)"
echo "Update mesos-master.service and cluster configuration."

# get zookeeper IP information 
	zoonode=$/etc/zookeeper/conf/myid
	zooip=$(echo $sysip | cut -d. -f4 --complement).$zoonode
	echo $sysnode > /etc/zookeeper/conf/myid

# update /etc/mesos/zk and prepare zookeeper.txt
	rm -f /tmp/zookeeper.txt
	echo -n "zk://"  > /etc/mesos/zk
	for (( k=$sysnode; k<`expr $sysnode + $size`; k++))	
	do
   		newip=$(echo $sysip | cut -d. -f4 --complement).$k
   		echo -n "$newip:2181," >> /etc/mesos/zk
		echo "server.$k=zookeeper$k:2888:3888" >> /tmp/zookeeper.txt
	done

# append /etc/mesos/zk with "/mesos"
	sed -i 's|,$|/mesos|' /etc/mesos/zk 		

# import zookeeper.txt to /etc/zookeeper/conf/zoo.cfg.
	k=`expr $(awk '/.2888.3888/{print NR;exit}' /etc/zookeeper/conf/zoo.cfg) - 1`
	sed -i -e '/.2888.3888/d' -e "$k r /tmp/zookeeper.txt" /etc/zookeeper/conf/zoo.cfg

# update mesos-master.service
	let "k = size/2 + size%2"
	echo -n "   ExecStart=/usr/sbin/mesos-master " > /tmp/mesos.txt
	echo -n "--ip=$sysip --hostname=$sysip --zk=$(cat /etc/mesos/zk) " >> /tmp/mesos.txt
	echo "--quorum=$k --work_dir=/var/lib/mesos" >> /tmp/mesos.txt

	k=`expr $(awk '/ExecStart/{print NR;exit}' mesos-master.service) - 1`
	sed -i -e '/ExecStart/d' -e "$k r /tmp/mesos.txt" mesos-master.service

# Update marathon.service
	echo -n "   ExecStart=/usr/sbin/marathon --master $(cat /etc/mesos/zk) " > /tmp/marathon.txt
	echo "--zk $(cat /etc/mesos/zk | sed 's/mesos/marathon/')" >> /tmp/marathon.txt

	k=`expr $(awk '/ExecStart/{print NR;exit}' marathon.service) - 1`
	sed -i -e '/ExecStart/d' -e "$k r /tmp/marathon.txt" marathon.service
;;

1s)
echo "$(tput setaf 6)!! This is mesos slave node !!$(tput sgr0)"
echo "No need to change mesos-slave.service and cluster configuration." 
echo && exit
;;

1new)
echo "$(tput setaf 6)!! This is new node !!$(tput sgr0)"
echo "Please [enter] in cluster size to install mesos-slave package."
echo && exit  
;;

esac

echo && echo "$(tput setaf 3)!! Warning - Master node will restart in 10 seconds ........"
echo $(tput sgr0)
cd ~
sleep 10
shutdown -r now
