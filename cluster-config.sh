#!/bin/bash

echo
read -p "How many nodes in Mesosphere cluster: " size
read -p "Enter first node number in cluster: " new

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

# set up zookeeper connection info
echo -n "zk://"  > zk-temp

for (( k=$new; k<`expr $new + $size - 1`; k++))
do
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo -n "$newip:2181," >> zk-temp
   echo "server.$k=zookeeper$k:2888:3888" >> zoo-temp
done
   k=`expr $new + $size - 1`
   newip=$(echo $oldip | cut -d. -f4 --complement).$k
   echo "$newip:2181/mesos" >> zk-temp
   echo "server.$k=zookeeper$k:2888:3888" >> zoo-temp

# import zookeeper connection info to system config files.
# "sudo cat" does not work. Need tp shell (-s) sudo and quote command. 
`cat zk-temp > /etc/mesos/zk` | sudo -s

k=`expr $(awk '/.2888.3888/{print NR;exit}' /etc/zookeeper/conf/zoo.cfg) - 1`
sudo sed -i '/.2888.3888/d' /etc/zookeeper/conf/zoo.cfg
sudo sed -i "$k r zoo-temp" /etc/zookeeper/conf/zoo.cfg

rm zk-temp zoo-temp

# set up quorum for over 50 percent of the master members in cluster
let "size = size/2 +size%2"
`echo $size > /etc/mesos-master/quorum` | sudo -s
cat /etc/mesos-master/quorum
