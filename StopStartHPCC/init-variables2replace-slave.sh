#!/bin/bash 
region=us-east-1
volume_id=vol-0c1223a8
device=/dev/sdz
master_ip=10.60.0.123
mpoint=/var/lib/HPCCSystems

old_instance_ip=10.60.0.97
old_instance_id=i-cd376857
old_instance_asgnames=asgnames.-txt-original-slave
old_public_ips=public_ips.txt-original-slave
old_environment_xml=environment.xml-for-working-reed-expo-hpcc

new_instance_ip=10.60.0.46
new_instance_id=i-428aa6d2
new_instance_asgnames=asgnames.txt-with-replacement-slave
new_public_ips=public_ips.txt-with-replacement-slave
new_environment_xml=environment.xml-with-replacement-slave
