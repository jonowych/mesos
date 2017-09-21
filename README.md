# Mesosphere cluster installation on Ubuntu 16.04.
Run scripts in following order
1) mesos-install.sh <master||slave> - Install mesos (include zookeeper). Master includes marathon and chronos
2) master-update.sh <master||slave> - change system hostname and IP address. It also update mesos-master and zookeeper ID
3) cluster-config.sh - set up mesos and Zookeeper connection information for cluser

