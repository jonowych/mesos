#!/bin/bash

echo && read -p "Please enter first node number in cluster: " new

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

size=3
echo -n "zk://"  > zk-temp
echo -e "\n#Below configuration is inserted by script." > zoo-temp
for (( i=$new; i<`expr $new + $size - 1`; i++))
do
   newip=$(echo $oldip | cut -d. -f4 --complement).$i
   echo -n "$newip:2181," >> zk-temp
   echo "server.$i=zookeeper$i:2888:3888" >> zoo-temp
done
   new=`expr $new + $size - 1`
   newip=$(echo $oldip | cut -d. -f4 --complement).$new
   echo "$newip:2181/mesos" >> zk-temp
   echo "server.$new=zookeeper$new:2888:3888" >> zoo-temp

cat zk-temp > /dev/null | sudo tee /etc/mesos/zk
sudo sed -i '/#server.3=/r zoo-temp' /etc/zookeeper/conf/zoo.cfg
rm zk-temp zoo-temp
