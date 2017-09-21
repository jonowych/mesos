#!/bin/bash

if [ ! "${USER}" = "root" ] ; then
   echo "!! Enter $(tput setaf 1)sudo $0$(tput sgr0) to update !!"
   echo && exit ; fi

echo
read -p "How many nodes in Mesosphere cluster: " size
read -p "Enter first node number in cluster: " new

if ! [ $new -eq $new ] 2>/dev/null ; then
        echo "$(tput setaf 1)!! Exit -- Sorry, integer only !!$(tput sgr0)"
        exit ; fi
if [ -z $new ] || [ $new -lt 1 ] || [ $new -gt 254 ] ; then
        echo "$(tput setaf 1)!! Exit -- node number out of range !!$(tput sgr0)"
        exit ; fi

new=$(echo $new | sed 's/^0*//')
intf=$(ifconfig | grep -m1 ^e | awk '{print $1 }')

oldhost=$(hostname)
oldip=$(ifconfig | grep $intf -A 1 | grep inet | awk '{ print $2 }' | awk -F: '{ print $2 }')

# set up mesos connection info for all nodes
if [ -z $(which mesos) ] ; then
   echo "!!$(tput setaf 1) /etc/mesos/zk is not updated !!"
   echo "!! because mesos is not installed in node !!"
   echo $(tput sgr0) && exit ; fi

echo -n "zk://"  > /etc/mesos/zk
for (( k=$new; k<`expr $new + $size - 1`; k++))
do
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo -n "$newip:2181," >> /etc/mesos/zk
done
   k=`expr $new + $size - 1`
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo "$newip:2181/mesos" >> /etc/mesos/zk
   echo "$(tput setaf 6)!! /etc/mesos/zk has been updated. !!$(tput sgr0)"
   echo

# set up zookeeper connection info for master nodes
if [ -z $(which marathon) ] ; then
   echo "!!$(tput setaf 1) /etc/zookeeper/conf/zoo.cfg is not updated !!"
   echo "because marathon is not installed in node !!"
   echo $(tput sgr0) && exit ; fi

for (( k=$new; k<`expr $new + $size - 1`; k++))
do
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo "server.$k=zookeeper$k:2888:3888" >> zoo-temp
done
   k=`expr $new + $size - 1`
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo "server.$k=zookeeper$k:2888:3888" >> zoo-temp

# import zookeeper connection info to system config files.

k=`expr $(awk '/.2888.3888/{print NR;exit}' /etc/zookeeper/conf/zoo.cfg) - 1`
sed -i -e '/.2888.3888/d' -e "$k r zoo-temp" /etc/zookeeper/conf/zoo.cfg
rm zoo-temp

# set up quorum for over 50 percent of the master members in cluster
let "size = size/2 +size%2"
echo $size > /etc/mesos-master/quorum
echo "$(tput setaf 6)!! /etc/zookeeper/conf/zoo.cfg has been updated !!"
echo "!! Cluster configuration has finished. !!$(tput sgr0)"
echo
