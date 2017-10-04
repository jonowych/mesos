#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Please enter command as root $(tput setaf 1)sudo $0 $(tput sgr0)!!"
   echo && exit ; fi

if [ -e /etc/systemd/system/mesos-master.service ] ; then node=master
elif [ -e /etc/systemd/system/mesos-slave.service ] ; then node=slave
elif [ ! -e /etc/apt/sources.list.d/mesosphere.list ] ; then node=new
else	echo $(tput setaf 1)
	echo "!! Error -- mesosphere.list exits but cannot find"
	echo "neither mesos-master.service nor mesos-slave.service"
	echo $(tput sgr0) && exit
fi

echo $(tput setaf 3)
echo "How many master nodes in mesosphere cluster?"
echo "Enter [0] to install slave; or [1-9] to install master;"
read -p "Enter none to update IP in mesos-master start-up only: " size
echo $(tput sgr0)

if ! [ $size -eq $size ] 2>/dev/null ; then
        echo $(tput setaf 1)
        echo "!! Exit -- Sorry, integer only !!"
        echo $(tput sgr0) && exit
elif [ -z $size ] ; then
	if [ $node = "master" ] ; then size=empty
	else	echo $(tput setaf 1)
		echo "!! No update because this node is $mesos !!"
		echo $(tput sgr0) && exit ; fi
elif [ $size -eq 0 ] ; then
        if [ $node = "new" ] || [ $node = "slave" ] ; then mesos=slave
        else    echo $(tput setaf 1)
                echo "!! No update because this is mesos-master node !!"
                echo $(tput sgr0) && exit ; fi
elif [ $size -ge 1 ] && [ $size -le 9 ] ; then
        if [ $node = "new" ] || [ $node = "master" ] ; then mesos=master
	else    echo $(tput setaf 1)
                echo "!! No update because this is mesos-slave node !!"
                echo $(tput sgr0) && exit ; fi
else	echo $(tput setaf 1)
        echo "!! Exit -- Please enter cluster size between 0 and 9 !!"
        echo $(tput sgr0) && exit
fi

# Get system IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
syshost=$(hostname)
sysip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
sysnode=$(echo $sysip | awk -F. '{print $4}')

echo "Mesos package will be installed in this node $sysip"
echo "If already installed, mesos configuration will be updated."
echo "Install mesos-$mesos with size=$size, press Ctl-C if not proceed."
echo && sleep 10

if [ $size = "empty" ] ; then
	echo $(tput setaf 6)
	echo "!! Update mesos-master.service with system IP."
	echo $(tput sgr0)

	#get zookeeper IP information 
	zoonode=$(cat /etc/zookeeper/conf/myid)
	zooip=$(echo $sysip | cut -d. -f4 --complement).$zoonode
	echo $sysnode > /etc/zookeeper/conf/myid
	# Update mesos-master.service
	sed -i "s/=$zooip/=$sysip/g" /etc/systemd/system/mesos-master.service

	echo && echo "!! Warning - System will restart in 10 seconds ........"
	sleep 10
	shutdown -r now
fi

if [ $mesos = "slave" ] ; then
	# Get mesosphere cluster configuration from master node

	echo "$(tput setaf 6)!! This node will be installed as mesos-slave !!"
	echo "Contact Master node to retrieve cluster configuration;$(tput sgr0)"
	read -p "Enter mesosphere master node number (single number): " k

	masterip=$(echo $sysip | cut -d. -f4 --complement).$k

	ping -q -c3 $masterip > /dev/null
		if [ $? -eq 0 ] ; then
			scp sydadmin@$masterip:/etc/mesos/zk /tmp/
		else
			echo -n $(tput setaf 1)
			echo "!! Master node $masterip is not available !!"
			echo $(tput sgr0) && exit
		fi
fi

if [ ! -e /etc/apt/sources.list.d/mesosphere.list ] ; then
	# Add GPG key for the official mesosphere repository and update
	apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
	# Add mesosphere repository to APT sources
	DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
	# Add repository according linux distro
	CODENAME=$(lsb_release -cs)
	echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" \
		| sudo tee /etc/apt/sources.list.d/mesosphere.list
	apt-get -y update
fi

if [ $mesos = "master" ] ; then
	echo "$(tput setaf 3)!! Installing zookeeper package !!$(tput sgr0)"
	apt-get -y install zookeeperd
	echo $sysnode > /etc/zookeeper/conf/myid

	# prepare zookeeper.txt and import it to /etc/zookeeper/conf/zoo.cfg.
	rm -f /tmp/zoo.txt
	for (( k=$sysnode; k<`expr $sysnode + $size`; k++))
	do
		echo "server.$k=zookeeper$k:2888:3888" >> /tmp/zoo.txt
	done

	k=`expr $(awk '/.2888.3888/{print NR;exit}' /etc/zookeeper/conf/zoo.cfg) - 1`
	sed -i -e '/.2888.3888/d' -e "$k r /tmp/zoo.txt" /etc/zookeeper/conf/zoo.cfg

	# Start zookeeper service after configuration
	systemctl start zookeeper
	systemctl enable zookeeper
fi

# Install mesos (for both master and slave)
echo && echo "$(tput setaf 3)!! Installing mesos package !!$(tput sgr0)"
apt-get -y install mesos

case $mesos in

slave)
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
;;

master)
# Configure /etc/mesos/zk
	echo -n "zk://"  > /etc/mesos/zk
	for (( k=$sysnode; k<`expr $sysnode + $size`; k++))
	do
   		newip=$(echo $sysip | cut -d. -f4 --complement).$k
   		echo -n "$newip:2181," >> /etc/mesos/zk
	done
	sed -i 's|,$|/mesos|' /etc/mesos/zk

# set up quorum (>50% of master members in cluster)
	let "k = size/2 +size%2"

# set up mesos-master.service
cat <<EOF_mesos > /etc/systemd/system/mesos-master.service
[Unit]
   Description=Mesos Master Service
   After=zookeeper.service
   Requires=zookeeper.service

[Service]
   ExecStart=/usr/sbin/mesos-master --ip=$sysip --hostname=$sysip --zk=$(cat /etc/mesos/zk) --quorum=$k --work_dir=/var/lib/mesos

[Install]
   WantedBy=multi-user.target
EOF_mesos

	# Start mesos-master service after configuration set up
	systemctl daemon-reload
	systemctl start mesos-master.service
	systemctl enable mesos-master

	# Install marathon in master node
   	echo "$(tput setaf 3)!! Installing marathon package !!$(tput sgr0)"
   	apt-get -y install marathon

	# set up marathon info data
   	mkdir -p /etc/marathon/conf
   	echo $sysip > /etc/marathon/conf/hostname

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

	# Install chronos package
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
;;
esac

# ------------
echo $(tput setaf 6)
echo "!! Mesosphere installation has finished. !!"
echo $(tput sgr0)

echo && echo "!! Warning - System will restart in 10 seconds ........"
sleep 10
shutdown -r now

# Below are latest versions on 20170927
# zookeeper_ver=3.4.8-1
# mesos_ver=1.3.1-2.0.1
# marathon_ver=1.4.8-1.0.660.ubuntu1604
# chronos_ver=2.5.0-0.1.20170816233446.ubuntu1604
# Set up mesos and marathon package version.
#   marathon_ver=1.4.3-1.0.649.ubuntu1604
#   mesos_ver=1.1.1-2.0.1
