#!/bin/bash -e
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
sshuser=`basename $ThisDir`
echo "sshuser=\"$sshuser\""

. $ThisDir/cfg_BestHPCC.sh

echo "slavesPerNode=\"$slavesPerNode\""
$roxienodes=`$ThisDir/outputInstanceInfo.pl |egrep "running"|egrep "^Roxie"|uniq -c|wc -l`;

#----------------------------------------------------------------------------------
# If there is an EIP, associate it with the master instance, i.e. 1st instance id in $instance_ids.
#----------------------------------------------------------------------------------
if [ "$ThisClusterComponent" == 'Master' ] && [ "$EIPAllocationId" != "" ];then
  MasterInstanceId=`head -1 $instance_ids`
  echo "aws ec2 associate-address --instance-id $MasterInstanceId --allocation-id $EIPAllocationId --region $region"
  rc=`aws ec2 associate-address --instance-id $MasterInstanceId --allocation-id $EIPAllocationId --region $region`
  echo "rc=\"$rc\""
fi
#----------------------------------------------------------------------------------
# END If there is an EIP, associate it with the master instance, i.e. 1st instance id in $instance_ids.
#----------------------------------------------------------------------------------

#----------------------------------------------------------------------------------
# If this isn't the Master and there is an instance that has gone down then modify IPs
#  of the Master instance envionment.xml file so that the IP for the downed instance is
#  replaced with the IP of this instance. THIS MEANS WE DON'T CREATE environment.xml with envgen.
#----------------------------------------------------------------------------------
environment_has_been_created=''; # blank means false, i.e. environment has NOT been created
if [ "$ThisClusterComponent" != 'Master' ] && [ "$terminated_ip" != "" ];then
   MasterIP=`head -1 $private_ips`
   echo "ssh -i $pem -t -t $sshuser@$MasterIP \"cat /etc/HPCCSystems/environment.xml\" outputto $created_environment_file"
   ssh -i $pem -t -t $sshuser@$MasterIP "cat /etc/HPCCSystems/environment.xml" > $created_environment_file
   echo "sed -i \"s/\\(\[^0-9\]\\)$terminated_ip\\(\[^0-9\]\\)/\\1$ThisInstancePrivateIP\\2/g\" $created_environment_file"
   sed -i "s/\([^0-9]\)$terminated_ip\([^0-9]\)/\1$ThisInstancePrivateIP\2/g" $created_environment_file
   environment_has_been_created=1
fi

# If we don't have a Master then we don't want to create an environment.xml file
if [ "$ThisClusterComponent" != 'Master' ] && [ "$terminated_ip" == "" ];then
  firstnodetype=`head -1 $nodetypes`;
  if [ "$firstnodetype" != "Master" ];then
     echo "In $0. Because Master was not yet created, we are exiting without making environment.xml. ThisClusterComponent=\"$ThisClusterComponent\""
     exit
  fi
fi

# if the above didn't create the environment file then create it with envgen.
if [ "$environment_has_been_created" == "" ];then
    all_overrides='-override esp,@method,htpasswd -override thor,@replicateAsync,true -override thor,@replicateOutputs,true';
    
    #----------------------------------------------------------------------------------
    # If $channelsPerSlave is defined then set environment variable, channelsPerSlave,
    #  to $channelsPerSlave.
    #----------------------------------------------------------------------------------
    if [ ! -z $channelsPerSlave ]
    then
      all_overrides="$all_overrides -override thor,@channelsPerSlave,$channelsPerSlave";
    fi
    
    #----------------------------------------------------------------------------------
    # If there are ROXIEs in the configuration then set roxieMulticastEnabled to false.
    #----------------------------------------------------------------------------------
    set2falseRoxieMulticastEnabled=''
    if [ $roxienodes -gt 0 ]
    then
      set2falseRoxieMulticastEnabled=' -override roxie,@roxieMulticastEnabled,false'
      all_overrides="$all_overrides $set2falseRoxieMulticastEnabled"
    
      echo "roxienodes is greater than 0. So:  execute perl $ThisDir/updateEnvGenConfigurationForHPCC.pl"
      perl $ThisDir/updateEnvGenConfigurationForHPCC.pl
    fi
    
    #--------------------------------------------------------------------------------------------------------------------------------
    # Override globalMemorySize and masterMemorySize if master and slave memory sizes are different and their sizes are large enough.
    #--------------------------------------------------------------------------------------------------------------------------------
    masterMemTotal=`bash $ThisDir/getPhysicalMemory.sh`
    echo " masterMemTotal=\"$masterMemTotal\""
    
    SlavePublicIP=$(head -2 $ThisDir/private_ips.txt|tail -1)
    slaveMemTotal0=$(ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser@$SlavePublicIP bash $ThisDir/getPhysicalMemory.sh)
    slaveMemTotal=`echo $slaveMemTotal0|sed "s/.$//"`
    echo " slaveMemTotal=\"$slaveMemTotal\""
    
    # So we change globalMemorySize and masterMemorySize when the master and slave's memory aren't the same and
    #  when slave's memory is at least 10 gb and master's memory size is at least 2 gb.
    OneMB=1048576
    HalfGB=536870912
    OneGB=1073741824
    TwoGB=2147483648
    
    # 10 GB = 10737418240
    MinLargeSlaveMemory=10737418240
    
    memory_override=''
    if [ $non_support_instances -gt 0 ] && [ $masterMemTotal -ne $slaveMemTotal ] && [ $slaveMemTotal -gt $MinLargeSlaveMemory ] && [ $masterMemTotal -ge $TwoGB ]
    then
       # masterMemorySize = ($masterMemTotal - $OneGB)/$OneMB
       masterMemorySize=$(echo $masterMemTotal $OneGB $OneMB| awk '{printf "%.0f\n",($1-$2)/$3}')
    
       # globalMemorySize = ((($slaveMemTotal - $OneGB)/$slavesPerNode)-$HalfGB)/$OneMB
       globalMemorySize=$(echo $slaveMemTotal $OneGB $slavesPerNode $HalfGB $OneMB| awk '{printf "%.0f\n",((($1 - $2)/$3)-$4)/$5}')
       echo "masterMemorySize=\"$masterMemorySize\", globalMemorySize=\"$globalMemorySize\""
       master_override="-override thor,@masterMemorySize,$masterMemorySize"
       slave_override="-override thor,@globalMemorySize,$globalMemorySize"
       heap_override="-override thor,@heapUseHugePages,true"
       memory_override=" $master_override $slave_override $heap_override"
       all_overrides="$all_overrides $master_override $slave_override $heap_override"
    fi
    
    #----------------------------------------------------------------------------------
    # Generate a new environment.xml file.
    #----------------------------------------------------------------------------------
    envgen=/opt/HPCCSystems/sbin/envgen;
    
    # Make new environment.xml file for newly configured HPCC System.
    echo "$envgen -env $created_environment_file $all_overrides -ipfile $private_ips -supportnodes $supportnodes -thornodes $non_support_instances -roxienodes $roxienodes -slavesPerNode $slavesPerNode -roxieondemand 1"
    $envgen  -env $created_environment_file $all_overrides -ipfile $private_ips -supportnodes $supportnodes -thornodes $non_support_instances -roxienodes $roxienodes  -slavesPerNode $slavesPerNode -roxieondemand 1
fi    
#---------------------------------------------------------------------------------
# Add comment saying that environment.xml was generated by HaaS final_configureHPCC.sh
#---------------------------------------------------------------------------------
sed -i "s/<\!-- Generated with envgen .* -->/<\!-- Generated by HaaS final_configureHPCC.sh -->/" $created_environment_file

#----------------------------------------------------------------------------------
# If username and password is needed for system then do the follow.
#----------------------------------------------------------------------------------
master_ip=`head -1 $ThisDir/private_ips.txt`

# IF username and password given THEN setup so system requires them
if  [ -n "$system_username" ] && [ -n "$system_password" ]
then
  #Install HTTPD passwd tool
  echo "yum install -y httpd-tools"
  yum install -y httpd-tools

  echo "htpasswd -cb /etc/HPCCSystems/.htpasswd $system_username $system_password"
  htpasswd -cb /etc/HPCCSystems/.htpasswd $system_username $system_password

  # turn on authentication method htpasswed
  echo "For $created_environment_file, sed to change method to htpasswd and passwordExpirationWarningDays to 100"
  sed "s/method=\"none\"/method=\"htpasswd\"/" $created_environment_file | sed "s/passwordExpirationWarningDays=\"[0-9]*\"/passwordExpirationWarningDays=\"100\"/" > ~/environment_with_htpasswd_enabled.xml 

  # copy changed environment file back into $created_environment_file
  echo "cp ~/environment_with_htpasswd_enabled.xml $created_environment_file"
  cp ~/environment_with_htpasswd_enabled.xml $created_environment_file
fi

#----------------------------------------------------------------------------------
# Make sure hpcc platform is installed on all instance BEFORE doing hpcc-push.
#----------------------------------------------------------------------------------
# Before using hpcc-push.sh to copy new environment.xml file, $created_environment_file, to all instances, make
#  sure the hpcc platform is installed on all instances
perl $ThisDir/loopUntilHPCCPlatformInstalledOnAllInstances.pl

# Change new environment.xml file's ownership to hpcc:hpcc
echo "chown hpcc:hpcc $created_environment_file"
chown hpcc:hpcc $created_environment_file

#----------------------------------------------------------------------------------
# Use hpcc-push to push new environment.xml file to all instances.
#----------------------------------------------------------------------------------
# THIS CODE IS MY VERSION OF hpcc-push
out_environment_file=/etc/HPCCSystems/environment.xml
echo "cp -v $created_environment_file $out_environment_file"
cp -v $created_environment_file $out_environment_file
#echo "perl $ThisDir/tlh_hpcc-push.pl $created_environment_file $out_environment_file"
#perl $ThisDir/tlh_hpcc-push.pl $created_environment_file $out_environment_file
echo "/opt/HPCCSystems/sbin/hpcc-push.sh -s $created_environment_file -t $out_environment_file"
/opt/HPCCSystems/sbin/hpcc-push.sh -s $created_environment_file -t $out_environment_file

if [ $slavesPerNode -ne 1 ]
then
   echo "slavesPerNode is greater than 1. So:  execute perl $ThisDir/updateSystemFilesOnAllInstances.pl"
   perl $ThisDir/updateSystemFilesOnAllInstances.pl
else
   echo "slavesPerNode($slavesPerNode) is equal to 1. So did not execute updateSystemFilesOnAllInstances.pl."
fi
