#!/bin/bash
# Comment added by company account to see if I can write to s3://publichpcc
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
yum -y clean all
yum-config-manager --enable epel
yum -y update --security
yum -y update aws-cfn-bootstrap
yum -y install aws-cli
user=<SSHUserName>
echo TLH: user=\"$user\"
aws s3 cp s3://<ScriptsS3BucketFolder> /home/$user --recursive
chown $user:$user /home/$user/*
chmod 755 /home/$user/*.sh
chmod 755 /home/$user/*.pl
chmod 400 /home/$user/*.pem
                                                                
echo SCRIPT: starting setupCfgFileVariables.pl
/home/$user/setupCfgFileVariables.pl -stackname <StackName> -region <Region> -pem <KeyPair> -channels <NumberOfChannelsPerSlave>
echo SCRIPT: completed setupCfgFileVariables.pl

echo SCRIPT: starting setup_zz_zNxlarge_disks.pl
/home/$user/setup_zz_zNxlarge_disks.pl <EBSVolumesMaster> Master
echo SCRIPT: completed setup_zz_zNxlarge_disks.pl
                                                        
echo SCRIPT: starting install_hpcc.sh
/home/$user/install_hpcc.sh <InstallCassandra>
echo SCRIPT: completed install_hpcc.sh

echo SCRIPT: starting final_configureHPCC.sh
/home/$user/final_configureHPCC.sh
echo SCRIPT: completed final_configureHPCC.sh

echo SCRIPT: starting startHPCCOnAllInstances.pl
/home/$user/startHPCCOnAllInstances.pl
echo SCRIPT: completed startHPCCOnAllInstances.pl

echo SCRIPT: starting cassandra if installed
/home/$user/startCassandraOnAllInstances.pl <InstallCassandra>
echo SCRIPT: completed cassandra if installed

echo SCRIPT: 'Signal stack that setup of HPCC System is complete.'
/opt/aws/bin/cfn-signal -e 0 --stack <StackName> --resource MasterASG --region <Region>
echo SCRIPT: 'Done signaling stack that setup of HPCC System has completed.'
                                
