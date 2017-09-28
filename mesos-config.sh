#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
	echo "!! Please enter command as $(tput setaf 1)sudo $0 $(tput sgr0)!!"
	echo && exit
fi

# Add GPG key for the official mesosphere repository
apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# Add mesosphere repository to APT sources
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')

# Add repository according linux distro
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
apt-get -y update

read -p "How many master nodes in cluster? (Press [enter] for no change): " size
if ! [ $size -eq $size ] 2>/dev/null ; then
	echo "$(tput setaf 1)!! Exit -- Sorry, integer only !!$(tput sgr0)" && exit
fi

if [ $size -lt 1 ] || [ $size -gt 10 ] ; then
	echo "$(tput setaf 1)!! Exit -- Please enter cluster size between 1 and 10 !!$(tput sgr0)" && exit
fi

# Get system IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
syshost=$(hostname)
sysip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
sysnode=$(echo $sysip | awk -F. '{print $4}')

cd /etc/systemd/system/
if [ -e mesos-master.service ] ; then

	echo "!! Updating Mesosphere $(tput setaf 6)master configuration $(tput sgr0)!!"
	#get zookeeper IP information 
	zoonode=$/etc/zookeeper/conf/myid
	zooip=$(echo $sysip | cut -d. -f4 --complement).$zoonode
	echo $sysnode > /etc/zookeeper/conf/myid

	if [ -z $size ] ; then
		# --- size is entered zero (no change), update mesos-master or mesos-slave service file --- 
		sed -i "s/$zooip/$sysip/g" mesos-master.service
	else
		# (1) Update /etc/mesos/zk
		echo -n "zk://"  > /etc/mesos/zk
		rm -f /tmp/zookeeper.txt

		for (( k=$sysnode; k<`expr $sysnode + $size`; k++))	
		do
   			newip=$(echo $sysip | cut -d. -f4 --complement).$k
   			echo -n "$newip:2181," >> /etc/mesos/zk
			echo "server.$k=zookeeper$k:2888:3888" >> /tmp/zookeeper.txt
		done

		# append /etc/mesos/zk with /mesos
		sed -i 's|,$|/mesos|'   /etc/mesos/zk 		

		# (2) import zookeeper connection info to /etc/zookeeper/conf/zoo.cfg.
		k=`expr $(awk '/.2888.3888/{print NR;exit}' /etc/zookeeper/conf/zoo.cfg) - 1`
		sed -i -e '/.2888.3888/d' -e "$k r /tmp/zookeeper.txt" /etc/zookeeper/conf/zoo.cfg

		# (3) Update mesos-master.service
		newip=$(echo $oldip | cut -d. -f4 --complement).$ID
		echo -n "ExecStart=/usr/sbin/mesos-master " > /tmp/mesos.txt
		echo -n "--ip=$newip --hostname=$newip --zk=$(cat /etc/mesos/zk) " >> /tmp/mesos.txt
		echo -n "--quorum=`expr $size/2 + $size%2` --work_dir=/var/lib/mesos" >> /tmp/mesos.txt

		k=`expr $(awk '/ExecStart/{print NR;exit}' mesos-master.service) - 1`
 		sed -i -e '/ExecStart/d' -e "$k r /tmp/mesos.txt" mesos-master.service

		# (4) Update marathon.service
		echo -n "ExecStart=/usr/sbin/marathon --master $(cat /etc/mesos/zk) " > /tmp/marathon.txt
		echo -n "--zk $(cat /etc/mesos/zk | sed 's/mesos/marathon/')" >> /tmp/marathon.txt

		k=`expr $(awk '/ExecStart/{print NR;exit}' marathon.service) - 1`
		sed -i -e '/ExecStart/d' -e "$k r /tmp/marathon.txt" marathon.service
	fi
	# Start mesos-master service after configuration set up
	systemctl daemon-reload
 	systemctl start mesos-master.service
 	systemctl enable mesos-master
 	echo "!!$(tput setaf 6)Mesosphere master configuration has been updated $(tput sgr0)!!"
else
	if [ ! -e mesos-slave.service ] ; then
		# Download /etc/mesos/zk from master node
		echo && read -p "Please enter master node number: " master
		masterip=$(echo $sysip | cut -d. -f4 --complement).$master
		ping -q -c3 $masterip > /dev/null
		if [ $? -ne 0 ] ; then 
			echo "$(tput setaf 1)!! No response from node $masterip !!$(tput sgr0)" && exit
		else 
			scp sydadmin@$masterip:/etc/mesos/zk /tmp/
		fi

		echo "$(tput setaf 3)!! Installing mesos on slave machine !!$(tput sgr0)"
		apt-get -y install mesos

		# set up mesos-slave.service
		cat << EOF_mesos > /etc/systemd/system/mesos-slave.service
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
	fi
fi

echo && echo Master node will restart in 10 seconds ........
sleep 10
shutdown -r now
