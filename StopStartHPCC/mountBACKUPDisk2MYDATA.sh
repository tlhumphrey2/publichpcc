#!/bin/bash
# Everytime I ssh into g2.2xlarge instance do:
echo "sudo mount /dev/xvdg cat-dog-data"
sudo mount /dev/xvdf cat-dog-data
echo "sudo chown -R ubuntu:ubuntu $MYDATA"
sudo chown -R ubuntu:ubuntu $MYDATA
echo "sudo chown -R hpcc:hpcc $MYDATA/HPCCSystems"
sudo chown -R hpcc:hpcc $MYDATA/HPCCSystems
echo "sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a dafilesrv start"
sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a dafilesrv start
echo "sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init -c dali start"
sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init -c dali start
echo "sudo /opt/HPCCSystems/bin/updtdalienv /etc/HPCCSystems/environment.xml -f"
sudo /opt/HPCCSystems/bin/updtdalienv /etc/HPCCSystems/environment.xml -f
echo "sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start"
sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start

