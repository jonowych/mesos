# Mesosphere cluster installation on Ubuntu 16.04.
Run scripts in following order
1) Clone ubuntu VM in Virtualbox (or other hypervisor)
2) git clone [uDocker] & git clone [mesos]
3) ~/uDocker/docker-install.sh - install Docker
4) ./mesos-install.sh slave - Install mesos (slave & master)
5) Clone slave VM in Virtualbox (or other hypervisor) 
6) ./mesos-install.sh master - Install marathon and chronos (master).
7) Clone master VM in Virtualbox (or other hypervisor)
8) mesos-config.sh master - Update IP, hostname, zookeeper ID and mesos config in master.
9) mesos-config.sh slave - Update IP, hostname and mesos config in slave. 
10) cluster-config.sh - configure mesos and Zookeeper for cluster
