#!/bin/bash
echo "sudo chmod 777 /opt/HPCCSystems/sbin/hpcc_setenv"
sudo chmod 777 /opt/HPCCSystems/sbin/hpcc_setenv
echo "egrep -v \"libpython3\.7\" /opt/HPCCSystems/sbin/hpcc_setenv > /home/ec2-user/tt"
egrep -v "libpython3\.7" /opt/HPCCSystems/sbin/hpcc_setenv > /home/ec2-user/tt
echo "sudo mv -v /home/ec2-user/tt /opt/HPCCSystems/sbin/hpcc_setenv"
sudo mv -v /home/ec2-user/tt /opt/HPCCSystems/sbin/hpcc_setenv
echo "sudo chmod 755 /opt/HPCCSystems/sbin/hpcc_setenv"
sudo chmod 755 /opt/HPCCSystems/sbin/hpcc_setenv
