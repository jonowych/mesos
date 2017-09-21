# Mesosphere cluster installation on Ubuntu 16.04
# Also apply to other Ubuntu distro because script reads the distro code name
1) mesos-install.sh - Install mesos (include zookeeper). Do not answer 'y' for the slave
2) cluster-config.sh - set up Zookeeper connection information
3) master-update.sh - change system hostname and IP address. It also update mesos-master and zookeeper ID
