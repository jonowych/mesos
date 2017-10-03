# Mesosphere cluster installation on Ubuntu 16.04.
Run scripts in following order
1) Clone ubuntu VM in Virtualbox (or other hypervisor)
2) git clone [uDocker]
3) ~/uDocker/docker-install.sh    # install Docker
4) ~/uDocker/host-update.sh       # update IP address & hostname
5) git clone [mesos]
6) sudo ~/mesos/mesos-install.sh 
	- Remark: enter none to install mesos-slave package only; 
	- enter [1-9] to install mesos-master package, which 
	- includes zookeeper, mesos, marathon and chronos.
7) Clone master or slave VM to more VMs
8) sudo ~/meosos/mesos-config.sh
	- Remark: enter none to update mesos configuration in individual node; 
	- enter [1-9] to update cluster configuration (master and slave);
	- IP address of master node becomes first node in cluster.
