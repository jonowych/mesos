#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo -e "!! Enter $(tput setaf 1)sudo $0$(tput sgr0) to update !!"
   echo && exit 0 ; fi
   
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

newhost=$(echo $oldhost | cut -d- -f1)-$new
newip=$(echo $oldip | cut -d. -f4 --complement).$new

read -p "Change hostname? [enter] for no change: " new
if [ ! -z $new ] ; then  newhost=$new-$(echo $newhost | cut -d- -f2) ; fi

echo
echo "$(tput setaf 6)!! Update node name from $oldhost to $newhost !!"
echo "!! Update node IP from $oldip to $newip !! $(tput sgr0)"
echo && echo System will restart in 10 seconds
sleep 10

sed -i "s/$oldhost/$newhost/" /etc/hostname
sed -i "s/$oldhost/$newhost/" /etc/hosts
sed -i "s/$oldip/$newip/" /etc/network/interfaces

echo $new > /etc/zookeeper/conf/myid
echo $newip > /etc/mesos-master/ip
echo $newip > /etc/mesos-master/hostname

echo Restarting ........
shutdown -r now
