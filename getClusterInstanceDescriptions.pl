#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/cf_common.pl";
=pod
getClusterInstanceDescriptions.pl us-west-1 test-add-drop-instances-A StateReason &> test-add-drop-instances-9-instance-descriptions.log
=cut

$DesiredInfo[0]='InstanceId';
$DesiredInfo[1]='State';
$DesiredInfo[2]='PrivateIp';
$DesiredInfo[3]='InstanceName';

$region = shift @ARGV;
$stackname = shift @ARGV;
# If there are addition commandline arguments assume they are addition desired instance info
$OutputAllInfo = 0;
foreach (@ARGV){
  my $arg = shift @ARGV;
  $OutputAllInfo = 1 if $arg == 'output_all_info';
  next if $arg eq 'output_all_info';
  push @DesiredInfo, $arg;
}

@InstanceInfo = getClusterInstanceInfo ($region, $stackname, @DesiredInfo);
@InstanceInfo = grep(/\brunning\b/, @InstanceInfo) if ! $OutputAllInfo;
@InstanceInfo = grep(s/^(.+) .+\-\-([A-Z].+)$/$1 $2/, @InstanceInfo);
print join("\n",@InstanceInfo),"\n";
