# Mesosphere cluster installation on Ubuntu 16.04.
Run scripts in following order
1) Clone ubuntu VM in Virtualbox (or other hypervisor)
2) git clone [uDocker]
3) ~/uDocker/docker-install.sh    # install Docker
4) ~/uDocker/host-update.sh       # update IP address & hostname
5) git clone [mesos]
6) sudo ~/mesos/mesos-install.sh  # install zookeeper, mesos, marathon & chronos
      remark: IP address of this VM becomes first member of mesosphere cluster 
7) Clone master VM to more VMs
8) sudo ~/uDocker/host-update.sh  # update IP address & hostname
9) sudo ~/mesos/mesos-config.sh   # update mesos master or agent service information 
      remark: IP address of the clone VM determines VM as master or agent
