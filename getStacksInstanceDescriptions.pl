#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/cf_common.pl";
require "$ThisDir/common.pl";

$region = shift @ARGV;
$stackname = shift @ARGV;
@Ips2Remove = ();
while(scalar(@ARGV) > 0){
    push @Ips2Remove, shift @ARGV;
}
print STDERR "DEBUG: In getStacksInstanceDescriptions.pl. region=\"$region\", stackname=\"$stackname\", Size of \@Ips2Remove is ",scalar(@Ips2Remove),"\n";

my @DesiredInfo = ();
$DesiredInfo[0]='InstanceName';
$DesiredInfo[1]='PublicIp';
$DesiredInfo[2]='PrivateIp';
$DesiredInfo[3]='InstanceId';
$DesiredInfo[4]='LaunchTime';

my $trys = 5;


GETINSTANCEINFO:
my @InstanceInfo0 = getClusterInstanceInfo ($region, $stackname, @DesiredInfo);
print STDERR "DEBUG: In getStacksInstanceDescriptions.pl. \@InstanceInfo0=(",join("|",@InstanceInfo0),")\n";

@InstanceInfo0 = grep(s/$stackname--//,@InstanceInfo0);
@InstanceInfo = grep(!/\bNone\b/,@InstanceInfo0);

# if there are IPs to remove from the list then do so
$InstancesRemoved = 0;
if ( scalar(@Ips2Remove) > 0 ){
  my $re = '\b(?:'.join('|',@Ips2Remove).')\b';
  @InstanceInfo = grep(!/$re/, @InstanceInfo);
  $InstancesRemoved = 1 if scalar(@InstanceInfo) < scalar(@InstanceInfo0);
}
print STDERR "DEBUG: In getStacksInstanceDescriptions.pl. \@InstanceInfo=(",join("|",@InstanceInfo),")\n";

if ( ($trys > 0) && (scalar(@Ips2Remove) > 0) && ! $InstancesRemoved ){
   sleep(20);
   $trys--;
   goto "GETINSTANCEINFO";
}

if ( $trys > 0 ){
  @InstanceInfo = sort {(split(/\s+/,$a))[0] cmp (split(/\s+/,$b))[0] || (split(/\s+/,$a))[4] cmp (split(/\s+/,$b))[4]} @InstanceInfo;
  @InstanceInfo = grep(s/ /,/g, @InstanceInfo);
  print join("\n",@InstanceInfo),"\n";
}
else{
  print "ERROR: ",scalar(@Ips2Remove)," INSTANCES WERE NOT REMOVED.\n";
}
