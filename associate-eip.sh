#!/bin/bash -e
# NOTE: This routine, associate-eip.sh, is ONLY executed by Master instances
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Entering $0";

. $ThisDir/cfg_BestHPCC.sh

#----------------------------------------------------------------------------------
# If there is an EIP, associate it with the master instance, i.e. 1st instance id in $instance_ids.
#----------------------------------------------------------------------------------
if [ "$ThisClusterComponent" == 'Master' ];then
  if [ "$EIPAllocationId" != "" ];then
    MasterInstanceId=`head -1 $instance_ids`
    echo "aws ec2 associate-address --instance-id $MasterInstanceId --allocation-id $EIPAllocationId --region $region"
    rc=`aws ec2 associate-address --instance-id $MasterInstanceId --allocation-id $EIPAllocationId --region $region`
    echo "rc=\"$rc\""
  fi
else
  echo "WARNING: In $0, which should only be executed by Master instances. But it was executed by \"$ThisClusterComponent\" instance.";
fi

# Let everyone know that Master has been setup by creating 'master-created' in s3 bucket $stackname
touch $ThisDir/master-created
echo "aws s3 cp $ThisDir/master-created s3://$stackname/master-created"
aws s3 cp $ThisDir/master-created s3://$stackname/master-created
