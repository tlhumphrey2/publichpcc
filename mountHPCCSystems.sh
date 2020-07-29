#!/bin/bash
pem=$1
for x in `cat /home/ec2-user/private_ips.txt`;do
  echo ssh -o stricthostkeychecking=no -i $pem -t -t ec2-user@$x "sudo mount /dev/xvdb /var/lib/HPCCSystems"
  ssh -o stricthostkeychecking=no -i $pem -t -t ec2-user@$x "sudo mount /dev/xvdb /var/lib/HPCCSystems"
done

