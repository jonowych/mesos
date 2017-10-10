#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Please enter command as root $(tput setaf 1)sudo $0 $(tput sgr0)!!"
   echo && exit ; fi

if [ ! -e /etc/apt/sources.list.d/mesosphere.list ] ; then mesos=new
elif [ -e /etc/systemd/system/mesos-slave.service ] ; then mesos=slave
elif [ -e /etc/systemd/system/mesos-master.service ] ; then mesos=master
	zoonode=$(cat /etc/zookeeper/conf/myid)
else	echo $(tput setaf 1)
	echo "!! Error -- mesosphere.list exits but cannot find"
	echo "neither mesos-master.service nor mesos-slave.service"
	echo $(tput sgr0) && exit
fi

echo $(tput setaf 3)
if [ $mesos = "new" ] ; then
	echo $(tput setaf 2)"!! This is a new node !! "$(tput sgr0)
	echo "Enter [0] to install slave; or [1-9] to install master;"
else 	echo $(tput setaf 3)"!! This node has been installed as mesos-$mesos !! "
	echo "Enter [0] to update IP only; or [1-9] to update cluster configuration;"
fi
echo $(tput sgr0)
read -p "How many master nodes in mesosphere cluster? " size

if ! [ $size -eq $size ] 2>/dev/null ; then
        echo $(tput setaf 1)
        echo "!! Exit -- Sorry, integer only !!"
        echo $(tput sgr0) && exit
elif [ -z $size ] || [ $size -lt 0 ] || [ $size -gt 9 ] ; then
	echo $(tput setaf 1)
        echo "!! Exit -- Please enter cluster size between 0 and 9 !!"
        echo $(tput sgr0) && exit
elif [ $mesos = "master" ] && [ $size -eq 0 ] ; then mesos=master_IP_update
elif [ $mesos = "slave" ] && [ $size -eq 0 ] ; then
	echo "This node is not updated because it has mesos-slave installed" && echo && exit
elif [ $mesos = "new" ] && [ $size -eq 0 ] ; then mesos=slave_install
elif [ $mesos = "master" ] && [ $size -ge 1 ] && [ $size -le 9 ] ; then mesos=master_cluster_update
elif [ $mesos = "slave" ] && [ $size -ge 1 ] && [ $size -le 9 ] ; then mesos=slave_cluster_update
elif [ $mesos = "new" ] && [ $size -ge 1 ] && [ $size -le 9 ] ; then mesos=master_install
fi

# Get system IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
syshost=$(hostname)
sysip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
sysnode=$(echo $sysip | awk -F. '{print $4}')
sed -i -e "/$syshost/i $sysip\t$syshost" -e "/$syshost/d" /etc/hosts

echo "Mesos package will be installed in this node $sysip"
echo "If already installed, mesos configuration will be updated."
echo "$(tput setaf 3)Action=$mesos$(tput sgr0), press Ctl-C within 10 seconds to exit script."
echo && sleep 10

# Prepare zk cluster configuration for slave
if [ $mesos = "slave_install" ] || [ $mesos = "slave_cluster_update" ] ; then
	# Get mesosphere cluster configuration from master node

	echo "$(tput setaf 6)!! This node is installed as mesos-slave !!"
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

# Set up mesosphere repository for new node
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

# Start packages installation - zookeeper, mesos, marathon, chronos
### zookeeper installation
if [ $mesos = "master_install" ] ; then
echo "$(tput setaf 3)!! Installing zookeeper package !!$(tput sgr0)"
	apt-get -y install zookeeperd
fi

# zookeeper configuration
if [ $mesos = "master_cluster_update" ] || [ $mesos = "master_install" ] ; then
	echo $sysnode > /etc/zookeeper/conf/myid

	# prepare zookeeper.txt and import it to /etc/zookeeper/conf/zoo.cfg.
	rm -f /tmp/zoo.txt
	for (( k=$sysnode; k<`expr $sysnode + $size`; k++))
	do
		newip=$(echo $sysip | cut -d. -f4 --complement).$k
		echo "server.$k=$newip:2888:3888" >> /tmp/zoo.txt
	done

	k=`expr $(awk '/.2888.3888/{print NR;exit}' /etc/zookeeper/conf/zoo.cfg) - 1`
	sed -i -e '/.2888.3888/d' -e "$k r /tmp/zoo.txt" /etc/zookeeper/conf/zoo.cfg

	# Start zookeeper service after configuration
	service zookeeper restart
	sleep 3
fi

### mesos installation
if [ $mesos = "slave_install" ] || [ $mesos = "master_install" ] ; then
echo && echo "$(tput setaf 3)!! Installing mesos package !!$(tput sgr0)"
	apt-get -y install mesos

	if [ $mesos = "slave_install" ] ; then
		# remove zookeeper because slave does not need it
		systemctl stop zookeeper
		systemctl disable zookeeper
		apt-get -y remove --purge zookeeper
	fi
fi

# mesos-slave configuration
if [ $mesos = "slave_install" ] || [ $mesos = "slave_cluster_update" ] ; then
	echo $sysip > /etc/mesos-slave/ip
	echo $sysip > /etc/mesos-slave/hostname
	mv /tmp/zk /etc/mesos/zk

# set up mesos-slave.service
cat <<EOF_mesos > /etc/systemd/system/mesos-slave.service
[Unit]
   Description=Mesos Slave Service
[Service]
   ExecStart=/usr/sbin/mesos-slave --master=$(cat /etc/mesos/zk) --work_dir=/var/lib/mesos
[Install]
   WantedBy=multi-user.target
EOF_mesos

	# Start mesos-slave service after configuration set up
	systemctl daemon-reload
	systemctl start mesos-slave.service
	systemctl enable mesos-slave

# mesos-master configuration
elif [ $mesos = "master_IP_update" ] ; then
	echo $sysip > /etc/mesos-master/ip
	echo $sysip > /etc/mesos-master/hostname
	echo $sysnode > /etc/zookeeper/conf/myid
	
	# Update mesos-master.service
	zooip=$(echo $sysip | cut -d. -f4 --complement).$zoonode
	sed -i "s/=$zooip/=$sysip/g" /etc/systemd/system/mesos-master.service

elif [ $mesos = "master_install" ] || [ $mesos = "master_cluster_update" ] ; then
	echo cluster01 > /etc/mesos-master/cluster
	echo $sysip > /etc/mesos-master/ip
	echo $sysip > /etc/mesos-master/hostname
	
	# Configure /etc/mesos/zk
	echo -n "zk://"  > /etc/mesos/zk
	for (( k=$sysnode; k<`expr $sysnode + $size`; k++))
	do
   		newip=$(echo $sysip | cut -d. -f4 --complement).$k
   		echo -n "$newip:2181," >> /etc/mesos/zk
	done
	sed -i 's|,$|/mesos|' /etc/mesos/zk

	# set up quorum (>50% of master members in cluster)
	let "k = size/2 + 1"
	echo $k > /etc/mesos-master/quorum

# set up mesos-master.service
cat <<EOF_mesos > /etc/systemd/system/mesos-master.service
[Unit]
   Description=Mesos Master Service
   After=zookeeper.service
   Requires=zookeeper.service
[Service]
   ExecStart=/usr/sbin/mesos-master --zk=$(cat /etc/mesos/zk) \
   	--ip=$sysip --hostname=$sysip --cluster=cluster01 \	
	--quorum=$k --work_dir=/var/lib/mesos
[Install]
   WantedBy=multi-user.target
EOF_mesos

	# Start mesos-master service after configuration set up
	systemctl daemon-reload
	systemctl start mesos-master.service
	systemctl enable mesos-master
fi

### marathon installation in master node
if [ $mesos = "master_install" ] ; then
	echo "$(tput setaf 3)!! Installing marathon package !!$(tput sgr0)"
   	apt-get -y install marathon
fi

# marathon configuration in master node
if [ $mesos = "master_cluster_update" ] || [ $mesos = "master_install" ] ; then
	# set up marathon info data
   	mkdir -p /etc/marathon/conf
	cp /etc/mesos-master/hostname /etc/marathon/conf/hostname
	cp /etc/mesos/zk /etc/marathon/conf/master
	sed 's/mesos/marathon/' /etc/mesos/zk > /etc/marathon/conf/zk

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
fi

### chronos installation in master node
if [ $mesos = "master_install" ] ; then
echo "$(tput setaf 3)!! Installing chronos !!$(tput sgr0)"
	apt-get -y install chronos
fi

# chronos configuration in master node
if [ $mesos = "master_install" ] ; then
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
fi

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
