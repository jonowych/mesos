#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Please enter command as root $(tput setaf 1)sudo $0 $(tput sgr0)!!"
   echo && exit ; fi

if [ -e /etc/systemd/system/mesos-master.service ] ; then mesos=master
elif [ -e /etc/systemd/system/mesos-slave.service ] ; then mesos=slave
else	echo $(tput setaf 1)
	echo "Cannot find neither mesos-master.service nor mesos-slave.service"
	echo $(tput sgr0) && exit
fi

# Get system IP information
intf=$(ifconfig | grep -m1 ^e | awk '{print $1}')
syshost=$(hostname)
sysip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{print $2}' | awk -F: '{print $2}')
sysnode=$(echo $sysip | awk -F. '{print $4}')

### Update interface IP and mesos node IP configuration:

echo "Update interface IP and mesos node IP configuration."
if [ $# -eq 0 ] ; then
	read -p "Please enter new mesos node number: " new
	else new=$1 ; fi

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
echo $(tput sgr0)
echo "!! Warning - System will restart in 10 seconds ........"
echo -n $(tput setaf 1)
echo "Pres ctrl-C within 10 seconds if not want to proceed."
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

echo $(tput setaf 6)
echo "!! Update host name from $syshost to $newhost !!"
echo $(tput sgr0) && shutdown -r now
