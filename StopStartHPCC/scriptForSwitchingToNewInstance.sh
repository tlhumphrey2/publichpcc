#!/bin/bash
#-------------------------------------------------------------
# Replacing one hpcc instance (Z) with another (2ND PROCEDURE) 
#-------------------------------------------------------------
# 1. Stop the hpcc cluster (on 10.60.0.123, i.e. sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init stop & 
#    sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a dafilesrv stop
# 2. umount and detach ebs volume (!1062) from instance to be replaced (Z=10.60.0.97) (volume_id=vol-0c1223a8).
# 3. Stop all instances and detach them from their ASGs. (./stopAllInstances.pl on bastion)
# 4. Start instance 10.60.0.46; attach volume (volume_id=vol-0c1223a8)(!1049); mount volume to /var/lib/HPCCSystems (!4,!5,!6)(!50,!51,!52)).
# 5. cp asgnames.txt-with-replacement-slave asgnames.txt (on bastion) (cp asgnames.-txt-original-slave asgnames.txt)
# 6. cp public_ips.txt-with-replacement-slave public_ips.txt (on bastion) ( cp public_ips.txt-original-slave public_ips.txt )
# 7. Run ./startAllInstances.pl without starting hpcc (this should start all instances and attach them to their ASGs)
# 8. On bastion, run ./mountVolumes.pl to mount all volumes on mount points. 
# 9. Push to all hpcc instances ( ./scpPutRX.pl environment.xml /etc/HPCCSystems/environment.xml ).
#    (scpGetRX.pl all environment.xml and do a diff to make sure they are all the same and have the correct IP (NOT 97).
# A. Start hpcc, i.e. on 10.60.0.123 do: sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start

# Note. To switch back to the original instance then switch old and new variables.

# Notes: If the hpcc doesn't start properly and there is an error in the mythor log file that says 
# run updtdalienv, then do the following:
# 1. Shutdown all components of the hpcc system (INCLUDING dafilesrv)
# 2. Start dali: sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init -c dali start
# 3. On dali instance run ($master_ip): sudo /opt/HPCCSystems/bin/updtdalienv  /etc/HPCCSystems/environment.xml -f
# 4. Restart the hpcc system. If it comes up ok then we have accomplished the switch ELSE switch back to the original instance

#------------------------------------------------
# Done on bastion
#------------------------------------------------
region=us-east-1
volume_id=vol-0c1223a8
device=/dev/sdz
master_ip=10.60.0.123
mpoint=/var/lib/HPCCSystems

. init-variables2replace-slave2.sh

# 1.STOP THE HPCC CLUSTER.
echo "ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$master_ip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init stop;sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a dafilesrv stop\""
ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$master_ip "sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init stop;sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a dafilesrv stop"

# Make sure everything has stopped by running the following for loop:
echo "for x in `cat public_ips.txt`;do ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$x \"hostname;sudo ps -u hpcc\";done"
for x in `cat public_ips.txt`;do ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$x "hostname;sudo ps -u hpcc";done

# 2.UMOUNT EBS VLOUME ON $old_instance_ip; DETACK EBS VOLUME FROM $old_instance_ip.
echo "ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$old_instance_ip \"sudo umount /var/lib/HPCCSystems\""
ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$old_instance_ip "sudo umount /var/lib/HPCCSystems"
echo "aws ec2 detach-volume --volume-id $volume_id --instance-id $old_instance_id --region $region"
aws ec2 detach-volume --volume-id $volume_id --instance-id $old_instance_id --region $region

#3. STOP ALL INSTANCES AND DETACH THEM FROM THEIR ASGs.
echo :cd StopStartHPCC; ./stopAllInstances.pl"
cd StopStartHPCC; ./stopAllInstances.pl

# 4. START INSTANCE $new_instance_ip, ATTACH VOLUME (volume_id=vol-0c1223a8); MOUNT VOLUME TO /var/lib/HPCCSystems
echo "cd StopStartHPCC; ./startOneInstance.pl $new_instance_id"
cd StopStartHPCC; ./startOneInstance.pl $new_instance_id # Start $new_instance_ip
aws ec2 attach-volume --volume-id $volume_id --instance-id $new_instance_id --device $device --region $region # attach volume to it
echo "cd;ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$new_instance_ip \"sudo mount $device $mpoint\""
cd;ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$new_instance_ip "sudo mount $device $mpoint" # mount volume

# 5. cp $new_instance_asgnames asgnames.txt
echo "cd StopStartHPCC;cp $new_instance_asgnames asgnames.txt"
cd StopStartHPCC;cp $new_instance_asgnames asgnames.txt

# 6.cp $new_public_ips public_ips.txt
echo "cd;cp $new_public_ips public_ips.txt"
cd;cp $new_public_ips public_ips.txt

# 7.Run ./startAllInstancesWithoutHPCCStart.pl 
echo "cd StopStartHPCC;./startAllInstancesWithoutHPCCStart.pl"
cd StopStartHPCC;./startAllInstancesWithoutHPCCStart.pl

# 8. Run ./mountVolumes.pl to mount all volumes on mount points.
echo :cd;./mountVolumes.pl"
cd;./mountVolumes.pl

# Check if everything is mounted
for x in `cat public_ips.txt`;do ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$x "hostname;lsblk";done

# 9. PUSH ENVIRONMENT.XML TO ALL HPCC INSTANCES
echo "./scpPutRX.pl $new_environment_xml /etc/HPCCSystems/environment.xml"
./scpPutRX.pl $new_environment_xml /etc/HPCCSystems/environment.xml

# A. START HPCC ON $master_ip
echo "ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$master_ip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start\""
ssh -i ReedExpoSSHKeyPair.pem -t ec2-user@$master_ip "sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start"
#------------------------------------------------
# END Done on bastion
#------------------------------------------------
