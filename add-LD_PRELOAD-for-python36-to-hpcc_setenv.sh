#!/bin/bash
echo "sudo chmod 777 /opt/HPCCSystems/sbin/hpcc_setenv"
sudo chmod 777 /opt/HPCCSystems/sbin/hpcc_setenv
echo "sed to put /usr/lib64/libpython3.6m.so.1.0 in /home/ec2-user/tt"
sed "s/\/bin\/bash *$/\/bin\/bash\\nexport LD_PRELOAD=\/usr\/lib64\/libpython3.6m.so.1.0\\n/" /opt/HPCCSystems/sbin/hpcc_setenv > /home/ec2-user/tt
echo "sudo mv -v /home/ec2-user/tt /opt/HPCCSystems/sbin/hpcc_setenv"
sudo mv -v /home/ec2-user/tt /opt/HPCCSystems/sbin/hpcc_setenv
echo "sudo chmod 755 /opt/HPCCSystems/sbin/hpcc_setenv"
sudo chmod 755 /opt/HPCCSystems/sbin/hpcc_setenv
