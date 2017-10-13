#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Please enter command as root $(tput setaf 1)sudo $0 $(tput sgr0)!!"
   echo && exit ; fi

if [ -e /etc/systemd/system/mesos-master.service ] ; then mesos=master
elif [ -e /etc/systemd/system/mesos-slave.service ] ; then mesos=slave
elif [ ! -e /etc/apt/sources.list.d/mesosphere.list ] ; then mesos=new
	# Set up mesosphere repository for new node
	# Add GPG key for the official mesosphere repository and update
	apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
	# Add mesosphere repository to APT sources
	DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
	# Add repository according linux distro
	CODENAME=$(lsb_release -cs)
	echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" \
		| sudo tee /etc/apt/sources.list.d/mesosphere.list

else	echo $(tput setaf 1)
	echo "!! Error -- mesosphere.list exits but cannot find"
	echo "neither mesos-master.service nor mesos-slave.service"
	echo $(tput sgr0) && exit
fi

echo $(tput setaf 6)
if [ $mesos = "new" ] ; then
	echo "!! This is a new node, which does not have mesos installed !!"
	echo "Enter [0] to install mesos-slave; or [1-9] to install mesos-master;"
else 	echo "!! This node already has mesos-$mesos installed !!"
	echo "Enter [1-9] to update cluster configuration;"
	echo "or enter [0] to only update mesos-$mesos IP."
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
fi

if [ $mesos = "master" ] && [ $size -eq 0 ] ; then mesos=master_IP
elif [ $mesos = "slave" ] && [ $size -eq 0 ] ; then mesos=slave_IP
elif [ $mesos = "new" ] && [ $size -eq 0 ] ; then mesos=slave_install
elif [ $mesos = "new" ] && [ $size -ge 1 ] && [ $size -le 9 ] ; then mesos=master_install
elif [ $mesos = "slave" ] && [ $size -ge 1 ] && [ $size -le 9 ] ; then mesos=slave_update
elif [ $mesos = "master" ] && [ $size -ge 1 ] && [ $size -le 9 ] ; then mesos=master_update
fi

# Get system IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
syshost=$(hostname)
sysip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
sysnode=$(echo $sysip | awk -F. '{print $4}')

### Update interface IP and mesos node IP configuration:
if [ $mesos = "master_IP" ] || [ $mesos = "slave_IP" ] ; then

	echo "Update interface IP and mesos node IP configuration."
	read -p "Please enter new mesos node number: " new
	if ! [ $new -eq $new ] 2>/dev/null ; then
        	echo $(tput setaf 1)
		echo "!! Exit -- Sorry, integer only !!"
	       	echo $(tput sgr0) && exit ; fi

	if [ -z $new ] || [ $new -lt 1 ] || [ $new -gt 254 ] ; then
        	echo $(tput setaf 1)
		echo "!! Exit -- node number out of range !!"
		echo $(tput sgr0) && exit ; fi

	new=$(echo $new | sed 's/^0*//')
	newip=$(echo $sysip | cut -d. -f4 --complement).$new

	read -p "Change hostname prefix? [enter] for no change: " newhost
	if [ -z $newhost ] ; then 
		newhost=$(echo $syshost | cut -d- -f1)-$new
	else 	newhost=$newhost-$new ; fi

	echo $(tput setaf 6)
	echo "!! Update host name from $syshost to $newhost !!"
	echo "!! Update interface IP from $sysip to $newip !!"
	echo $(tput sgr0)"Pres ctrl-C within 10 seconds if not want to proceed."
	sleep 10

	echo $newhost > /etc/hostname
	sed -i "s/$sysip/$newip/" /etc/network/interfaces
	sed -i -e "/$syshost/i $newip\t$newhost" -e "/$syshost/d" /etc/hosts

	if [ $mesos = "slave_IP" ] ; then
		echo $newip > /etc/mesos-slave/ip
		sed -i "s/=$sysip/=$newip/g" /etc/systemd/system/mesos-slave.service
	elif [ $mesos = "master_IP" ] ; then
		echo $newip > /etc/mesos-master/ip
		echo $new > /etc/zookeeper/conf/myid
		sed -i "s/=$sysip/=$newip/g" /etc/systemd/system/mesos-master.service
	fi
fi

### Mesos-slave package installation - mesos
if [ $mesos = "slave_install" ] || [ $mesos = "slave_update" ] ; then

echo $(tput setaf 6)
if [ -e /etc/apt/sources.list.d/mesosphere.list ] ; then
	echo "Mesos-slave package has been installed in this node $sysip." 
	echo "Update cluster configuration from mesos-master node........"
else
	echo "Mesos-slave package will be installed in this node $sysip"
fi
echo $(tput sgr0)

# create mesos-slave.service template
cat <<EOF > /tmp/template
[Unit]

   Description=Mesos Slave Service

[Service]
   _InsertCmdHere_

[Install]
   WantedBy=multi-user.target
EOF

	# Get mesosphere cluster configuration from master node
	read -p "Enter mesos-master node number (single number): " k
	masterip=$(echo $sysip | cut -d. -f4 --complement).$k

	ping -q -c3 $masterip > /dev/null
		if [ $? -eq 0 ] ; then
			scp sydadmin@$masterip:/etc/mesos/zk /tmp/
		else
			echo -n $(tput setaf 1)
			echo "!! Master node $masterip is not available !!"
			echo $(tput sgr0) && exit
		fi

	echo $(tput setaf 3)
	echo "!! Installing mesos package !!$(tput sgr0)"
	apt-get -y update	
	apt-get -y install mesos

	# remove zookeeper because slave does not need it
	systemctl stop zookeeper
	systemctl disable zookeeper
	apt-get -y remove --purge zookeeper

	# mesos-slave configuration
	echo $sysip > /etc/mesos-slave/ip
	mv /tmp/zk /etc/mesos/zk
	
	# Prepare mesos-slave startup command
	cmd=$(echo -n "ExecStart=/usr/sbin/mesos-slave")
	cmd=$(echo -n "$cmd --ip=$sysip")
	cmd=$(echo -n "$cmd --hostname=$sysip")
	cmd=$(echo -n "$cmd --master=$(cat /etc/mesos/zk)")
	cmd=$(echo -n "$cmd --containerizers=docker,mesos")
	cmd=$(echo -n "$cmd --executor_registration_timeout=10mins")
	cmd=$(echo -n "$cmd --work_dir=/var/lib/mesos")
	cmd=$(echo -n "$cmd --log_dir=/var/log/mesos")

	# configure mesos-slave service and restart
 	sed "s|_InsertCmdHere_|$cmd|" /tmp/template > etc/systemd/system/mesos-slave.service
	systemctl daemon-reload
	systemctl start mesos-slave.service
	systemctl enable mesos-slave
fi

### Mesos-master package installation - zookeeper, mesos, marathon, chronos
if [ $mesos = "master_install" ] || [ $mesos = "master_update" ]; then
apt-get -y update

### zookeeper installation
	echo $(tput setaf 3)
	echo "!! Installing zookeeper package !!"$(tput sgr0)
	apt-get -y install zookeeperd

	# zookeeper configuration
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

### mesos installation
# create mesos-master.service template
cat <<EOF > /tmp/template
[Unit]
   Description=Mesos Master Service
   After=zookeeper.service
   Requires=zookeeper.service

[Service]
   _InsertCmdHere_

[Install]
   WantedBy=multi-user.target
EOF

	echo $(tput setaf 3)
	echo "!! Installing mesos package !!$(tput sgr0)"
	apt-get -y install mesos

	# mesos-master configuration
	echo $sysip > /etc/mesos-master/ip
	
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

	cmd=$(echo -n "ExecStart=/usr/sbin/mesos-master")
	cmd=$(echo -n "$cmd --ip=$sysip")
	cmd=$(echo -n "$cmd --hostname=$sysip")
	cmd=$(echo -n "$cmd --zk=$(cat /etc/mesos/zk)")
	cmd=$(echo -n "$cmd --cluster=cluster01")
	cmd=$(echo -n "$cmd --quorum=$k")
	cmd=$(echo -n "$cmd --work_dir=/var/lib/mesos")
	cmd=$(echo -n "$cmd --log_dir=/var/log/mesos")

	# configure mesos-master.service system startup
 	sed "s|_InsertCmdHere_|$cmd|" /tmp/template > etc/systemd/system/mesos-master.service
	systemctl daemon-reload
	systemctl start mesos-master.service
	systemctl enable mesos-master

### marathon installation
# create marathon.service template
cat <<EOF > /tmp/template
[Unit]
   Description=Marathon Service
   After=mesos-master.service
   Requires=mesos-master.service

[Service]
   _InsertCmdHere_   

[Install]
   WantedBy=multi-user.target
EOF

	echo $(tput setaf 3)
	echo "!! Installing marathon package !!$(tput sgr0)"
   	apt-get -y install marathon

	# marathon configuration in master node
	# set up marathon info data
   	mkdir -p /etc/marathon/conf
	echo $sysip > /etc/marathon/conf/hostname
	cp /etc/mesos/zk /etc/marathon/conf/master
	sed 's/mesos/marathon/' /etc/mesos/zk > /etc/marathon/conf/zk

	cmd=$(echo -n "ExecStart=/usr/bin/marathon")
	cmd=$(echo -n "$cmd --hostname=$sysip")
	cmd=$(echo -n "$cmd --master $(cat /etc/mesos/zk)")
	cmd=$(echo -n "$cmd --zk $(cat /etc/mesos/zk | sed 's/mesos/marathon/')")
	cmd=$(echo -n "$cmd --work_dir=/var/lib/mesos")
	cmd=$(echo -n "$cmd --log_dir=/var/log/mesos")

	# configure marathon.service system startup
	sed "s|_InsertCmdHere_|$cmd|" /tmp/template > /etc/systemd/system/marathon.service
   	systemctl daemon-reload
   	systemctl start marathon.service
   	systemctl enable marathon.service

### chronos installation
# create marathon.service template
cat <<EOF > /tmp/template
[Unit]
   Description=Chronos Service
   After=marathon.service
   Requires=marathon.service

[Service]
   ExecStart=/usr/bin/chronos

[Install]
   WantedBy=multi-user.target
EOF

	echo $(tput setaf 3)
	echo "!! Installing chronos !!$(tput sgr0)"
	apt-get -y install chronos

	# configure chronos.service system startup
	mv /tmp/chronos.service /etc/systemd/system/
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
