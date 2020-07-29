#!/bin/bash
volume_id=$1
region=$2

ebsvolumelist=(
$volume_id
)

#echo "Array ebsvolumelist=(${ebsvolumelist[*]})"

regionList=(
$region
)

count=0
UnencryptedEBSVolume=()

ACCOUNT=633162230041

for REGION in "${regionList[@]}"; do
  for EBSV in "${ebsvolumelist[@]}"; do

    # Create array with [0] = Volume ID, [1] = Instance ID, [2] = AZ, [3] = Device attached as, [4] = encryption status
    #echo "For $EBSV in $REGION: get VolumeId, AZ, Device attached to, encryption status"
    volume_details=()
    for ITEM in $(MY_AWS_PROFILE=$ACCOUNT \
      aws ec2 describe-volumes \
        --region $REGION \
        --volume-ids $EBSV \
        --query 'Volumes[*].[VolumeId, Attachments[0].InstanceId, AvailabilityZone, Attachments[0].Device, Encrypted, Size, State]' \
        --output text) ; do
      volume_details+=($ITEM)
    done
    #echo "For $EBSV in $REGION: Volume details: ${volume_details[*]}"   
    echo "${volume_details[*]}"   
  done
done
