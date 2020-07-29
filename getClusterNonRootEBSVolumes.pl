#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/cf_common.pl";
=pod
getClusterNonRootEBSVolumes.pl us-east-2 yuting-oxford-university-hpcc-cluster-5
getClusterNonRootEBSVolumes.pl $region $stackname

HERE IS WHAT IS OUTPUT:
=cut

$region = shift @ARGV;
$stackname = shift @ARGV;
#print "DEBUG: Entering getClusterNonRootEBSVolumes.pl region=\"$region\", stackname=\"$stackname\"\n";

$DesiredInfo[0]='InstanceId';
$DesiredInfo[1]='VolumeIds';

@InstanceInfo = getClusterInstanceInfo ($region, $stackname, @DesiredInfo);
#print "DEBUG: In getClusterNonRootEBSVolumes.pl. ",join("\nDEBUG: In getClusterNonRootEBSVolumes.pl. ",@InstanceInfo),"\n";

@ebs_volumes = grep(s/^.+:xvda (vol-.+):xvdb\s*$/$1/, @InstanceInfo);
print join("\n",@ebs_volumes),"\n";

