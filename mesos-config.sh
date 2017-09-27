#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Enter command as $(tput setaf 1)sudo $0 <arg> !!"
   echo $(tput sgr0) && exit ; fi

if [ -z $(which mesos) ] ; then
   echo "!!$(tput setaf 1) mesos is not installed !!"
   echo $(tput sgr0) && exit ; fi

echo && read -p "Please enter new host node number: " new

if ! [ $new -eq $new ] 2>/dev/null ; then
        echo -e "$(tput setaf 1)!! Exit -- Sorry, integer only !!$(tput sgr0)"
        exit 1; fi
if [ -z $new ] || [ $new -lt 1 ] || [ $new -gt 254 ] ; then
        echo "$(tput setaf 1)!! Exit -- node number out of range !!$(tput sgr0)"
        exit 1; fi

# Get exisitng IP address and host name
intf=$(ifconfig | grep -m1 ^e | awk '{print $1 }')
oldhost=$(hostname)
oldip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{ print $2 }' | awk -F: '{ print $2 }')

new=$(echo $new | sed 's/^0*//')
newhost=$(echo $oldhost | cut -d- -f1)-$new
newip=$(echo $oldip | cut -d. -f4 --complement).$new

first=$(cat /etc/mesos/cluster | awk -F, '{print $1}')
size=$(cat /etc/mesos/cluster | awk -F, '{print $2}')

echo
echo "$(tput setaf 6)!! Update $1 node name from $oldhost to $newhost !!"
echo "!! Update node IP from $oldip to $newip !! $(tput sgr0)"
echo && echo System will restart in 10 seconds
sleep 10

sed -i "s/$oldhost/$newhost/" /etc/hostname
sed -i -e "s/$oldhost/$newhost/" -e "s/$oldip/$newip/" /etc/hosts
sed -i "s/$oldip/$newip/" /etc/network/interfaces

systemctl stop chronos.service
systemctl stop marathon.service
systemctl stop mesos-slave.service
systemctl stop mesos-master.service
systemctl stop zookeeper.service

if [ $new -lt $first ] || [ $new -ge `expr $first + $size` ] ; then
   echo "!! Updating Mesosphere $(tput setaf 6)slave configuration$(tput sgr0) !!"
   systemctl disable chronos.service
   systemctl disable marathon.service
   systemctl disable mesos-master.service
   systemctl disable zookeeper.service

else
   echo "!! Updating Mesosphere $(tput setaf 6)master configuration$(tput sgr0) !!"
   # Update zookeeper ID
     echo $new > /etc/zookeeper/conf/myid
   # Update mesos-master.service
     sed -i "s/$oldip/$newip/g" /etc/systemd/system/mesos-master.service
fi

echo Restarting ........
shutdown -r now
