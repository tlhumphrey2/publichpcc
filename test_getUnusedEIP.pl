#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/common.pl";

local $_=`aws ec2 describe-addresses --region us-east-1|$ThisDir/json2yaml.sh`;
($EIPAllocationId, $EIP) = getUnusedEIP($_);
