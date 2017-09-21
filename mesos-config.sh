#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Enter command as $(tput setaf 1)sudo $0 <arg> !!"
   echo $(tput sgr0) && exit ; fi

if [[ $1 != "master" && $1 != "slave" ]] ; then
   echo "!!$(tput setaf 1) Specify master or slave !!"
   echo $(tput sgr0) && exit ; fi

if [ -z $(which mesos) ] ; then
   echo "!!$(tput setaf 1) mesos is not installed !!"
   echo $(tput sgr0) && exit ; fi

if [[ -z $(which marathon) && $1 = "master" ]] ; then
   echo "!!$(tput setaf 1) marathon is not installed !!"
   echo $(tput sgr0) && exit ; fi

echo && read -p "Please enter host node number: " new

if ! [ $new -eq $new ] 2>/dev/null ; then
        echo -e "$(tput setaf 1)!! Exit -- Sorry, integer only !!$(tput sgr0)"
        exit 1; fi
if [ -z $new ] || [ $new -lt 1 ] || [ $new -gt 254 ] ; then
        echo -e "$(tput setaf 1)!! Exit -- node number out of range !!$(tput sgr0)"
        exit 1; fi

new=$(echo $new | sed 's/^0*//')
intf=$(ifconfig | grep -m1 ^e | awk '{print $1 }')

oldhost=$(hostname)
oldip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{ print $2 }' | awk -F: '{ print $2 }')

read -p "Change hostname? [enter] for no change: " newhost
if [ -z $newhost ]
   then newhost=$(echo $oldhost | cut -d- -f1)-$new
   else newhost=$newhost-$new ; fi

newip=$(echo $oldip | cut -d. -f4 --complement).$new

echo
echo "$(tput setaf 6)!! Update $1 node name from $oldhost to $newhost !!"
echo "!! Update node IP from $oldip to $newip !! $(tput sgr0)"
echo && echo System will restart in 10 seconds
sleep 10

sed -i "s/$oldhost/$newhost/" /etc/hostname
sed -i "s/$oldhost/$newhost/" /etc/hosts
sed -i "s/$oldip/$newip/" /etc/network/interfaces

if [ $1 = "slave" ] ; then
   # update mesos and zookeeper data
   service zookeeper stop	# slave does not run zookeeper
   echo manual > /etc/init/zookeeper.override
   service mesos-master stop
   echo manual > /etc/init/mesos-master.override

   service mesos-master stop
   echo $newip > /etc/mesos-slave/ip
   echo $newip > /etc/mesos-slave/hostname
fi

if [ $1 = "master" ] ; then
   # update mesos and zookeeper data
   service mesos-slave stop
   echo manual > /etc/init/mesos-slave.override

   echo $new > /etc/zookeeper/conf/myid
   echo $newip > /etc/mesos-master/ip
   echo $newip > /etc/mesos-master/hostname

   # update marathon info data
   mkdir -p /etc/marathon/conf
   cp /etc/mesos-master/hostname /etc/marathon/conf
   cp /etc/mesos/zk /etc/marathon/conf/master
   sed -i 's/mesos/marathon/' /etc/marathon/conf/master
fi

echo Restarting ........
shutdown -r now
