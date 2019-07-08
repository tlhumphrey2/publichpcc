#!/bin/bash
terminated_ip=$1
new_ip=$2
nodetype=$3
echo "terminated_ip=\"$terminated_ip\", new_ip=\"$new_ip\" nodetype=\"$nodetype\""
if [ "$nodetype" == 'Slave' ];then
 echo "sed -i \"s/^$terminated_ip$/$new_ip/\" /var/lib/HPCCSystems/mythor/uslaves"
 sed -i "s/^$terminated_ip$/$new_ip/" /var/lib/HPCCSystems/mythor/uslaves 
 /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init -c thor stop
 /opt/HPCCSystems/bin/updtdalienv /etc/HPCCSystems/environment.xml -f
 /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init -c thor start
elif [ "$nodetype" == 'Roxie' ];then
 /opt/HPCCSystems/bin/updtdalienv /etc/HPCCSystems/environment.xml -f
 /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart
fi
