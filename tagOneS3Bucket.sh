#!/bin/bash
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

: <<'ENDUSAGE'
tagOneS3Buckets.sh $stackname "Key=project,Value=hpcc-cluster Key=market,Value=hpccsystems Key=product,Value=hpccsystems Key=application,Value=hpccsystems Key=service,Value=s3bucket Key=lifecycle,Value=dev Key=owner_email,Value='timothy.humphrey@lexisnexisrisk.com' Key=support_email,Value='timothy.humphrey@lexisnexisrisk.com'"
NOTE: The name of the s3 bucket is $stackname
ENDUSAGE

S3BucketName=$1
TagsKeyAndValue=$2

tagset=`$ThisDir/mkTagSet.pl "$TagsKeyAndValue"`
echo "aws s3api put-bucket-tagging --bucket $S3BucketName --tagging \"TagSet=[$tagset]\""
aws s3api put-bucket-tagging --bucket $S3BucketName --tagging "TagSet=[$tagset]"
