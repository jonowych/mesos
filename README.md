# Mesosphere cluster installation on Ubuntu 16.04.
Run scripts in following order
1) Clone ubuntu VM in Virtualbox (or other hypervisor)
2) git clone [uDocker]
3) ~/uDocker/docker-install.sh    # install Docker
4) ~/uDocker/host-update.sh       # update IP address & hostname
5) git clone [mesos]
6) sudo ~/mesos/mesos-install.sh  # install zookeeper, mesos, marathon & chronos
      Remark: IP address of this VM becomes first member of mesosphere cluster 
7) sudo ~/mesos/mesos-config.sh   # install mesos-slave packages in fresh VM  
8) Clone master or slave VM to more VMs
9) sudo ~/uDocker/host-update.sh  # update IP address & hostname
10) sudo ~/mesos/mesos-config.sh   # update mesos master or agent service information
      Remark: answer to cluster size will behave differently:
      - if answer [enter] in fresh VM, mesos-slave package will be installed
      - if answer [enter] in master VM, IP we be updated in mesos configuration
      - if answer [1-9] in master VM, cluster configuration will change
        & IP address of VM becomes first member of mesosphere cluster 
