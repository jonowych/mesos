# Mesosphere cluster installation on Ubuntu 16.04.
Run scripts in following order
1) mesos-install.sh <master||slave> - Install mesos (slave & master), marathon and chronos (master).
2) mesos-config.sh <master||slave> - Update IP, hostname and zookeeper config in node.
3) cluster-config.sh - set up mesos and Zookeeper connection information for cluser

