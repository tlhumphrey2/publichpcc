#!/bin/bash
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $ThisDir/cfg_BestHPCC.sh

: <<'ENDUSAGE'
tagASGs.sh eu-west-1 RIS-AWS-SQS-Notification-autoscaling-groups-eu-west-1-20200323.txt "Key=market,Value=hpccsystems Key=product,Value=hpccsystems Key=application,Value=hpccsystems Key=service,Value=auto-scaling-group Key=lifecycle,Value=dev Key=owner_email,Value='timothy.humphrey@lexisnexisrisk.com' Key=support_email,Value='timothy.humphrey@lexisnexisrisk.com'" &> RIS-AWS-SQS-Notification-autoscaling-groups-eu-west-1-20200323.log
tagASGs.sh us-east-2 RIS-AWS-SQS-Notification-autoscaling-groups-us-west-1-20200302.txt "Key=market,Value=hpccsystems Key=product,Value=hpccsystems Key=application,Value=hpccsystems Key=service,Value=auto-scaling-group Key=lifecycle,Value=dev Key=owner_email,Value='timothy.humphrey@lexisnexisrisk.com' Key=support_email,Value='timothy.humphrey@lexisnexisrisk.com'" &> RIS-AWS-SQS-Notification-autoscaling-groups-us-west-1-20200302.log
tagASGs.sh us-east-2 RIS-AWS-SQS-Notification-autoscaling-groups-us-east-1-20200302.txt "Key=market,Value=hpccsystems Key=product,Value=hpccsystems Key=application,Value=hpccsystems Key=service,Value=auto-scaling-group Key=lifecycle,Value=dev Key=owner_email,Value='timothy.humphrey@lexisnexisrisk.com' Key=support_email,Value='timothy.humphrey@lexisnexisrisk.com'" &> RIS-AWS-SQS-Notification-autoscaling-groups-us-east-1-20200302.log
tagASGs.sh us-east-2 RIS-AWS-SQS-Notification-autoscaling-groups-us-east-2-20200302.txt "Key=market,Value=hpccsystems Key=product,Value=hpccsystems Key=application,Value=hpccsystems Key=service,Value=auto-scaling-group Key=lifecycle,Value=dev Key=owner_email,Value='timothy.humphrey@lexisnexisrisk.com' Key=support_email,Value='timothy.humphrey@lexisnexisrisk.com'" &> RIS-AWS-SQS-Notification-autoscaling-groups-us-east-2-20200302.log
tagASGs.sh us-east-2 yuting-oxford-university-hpcc-cluster-5-ASGs.txt "Key=market,Value=hpccsystems Key=product,Value=hpccsystems Key=application,Value=hpccsystems Key=service,Value=auto-scaling-group Key=lifecycle,Value=dev Key=owner_email,Value='timothy.humphrey@lexisnexisrisk.com' Key=support_email,Value='timothy.humphrey@lexisnexisrisk.com'" &> tagging-yuting-oxford-university-hpcc-cluster-5-ASGs.log
tagASGs.sh us-east-2 add-tags-2-asgs-20191216.txt "Key=market,Value=hpccsystems Key=product,Value=hpccsystems Key=application,Value=hpccsystems Key=service,Value=s3bucket Key=lifecycle,Value=dev Key=owner_email,Value='timothy.humphrey@lexisnexisrisk.com' Key=support_email,Value='timothy.humphrey@lexisnexisrisk.com'" &> tagging-add-tags-2-asgs-20191216.log
ENDUSAGE

region=$1
ASGFile=$2
TagsKeyAndValue=$3

while read asg;do
 for KeyAndValue in $TagsKeyAndValue; do
  echo aws autoscaling create-or-update-tags --region $region --tags ResourceId=$asg,ResourceType=auto-scaling-group,PropagateAtLaunch=true,$KeyAndValue 
  aws autoscaling create-or-update-tags --region $region --tags ResourceId=$asg,ResourceType=auto-scaling-group,PropagateAtLaunch=true,$KeyAndValue 
 done
done < $ASGFile
