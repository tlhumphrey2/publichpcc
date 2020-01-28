#!/usr/bin/perl
=pod
This script does:
1. Reads asg name a a list of instance ids from asgnames.txt
2. Starts all instances
3. Attaches all instances to their asg.
=cut

$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "$ThisDir/ClusterInitVariables.pl";
require "$ThisDir/formatDateTimeString.pl";

# NOTE: This scripts REQUIRES the aws cli be setup.

die "USAGE ERROR: $0 REQUIRES an instance id on command line.\n" if scalar(@ARGV) == 0;
$instance_id = shift @ARGV;

#----------------------------------
# Start instance
#----------------------------------
if ( InstanceStatus($instance_id) eq 'running' ){
  my $dt=formatDateTimeString(); print("$dt DO NOT NEED TO START BECAUSE $instance_id IS ALREADY STARTED.\n");
}
else{
  my $dt=formatDateTimeString(); print("$dt aws ec2 start-instances --instance-ids $instance_id --region $region\n");
  my $rc=`aws ec2 start-instances --instance-ids $instance_id --region $region`;

  if ( $rc !~ /StartingInstances/s ){
    my $dt=formatDateTimeString(); die "$dt FATAL ERROR. While attempting to start instance, \"$asg_instance\". Contact Tim Humphrey. EXITING. \n";
  }
}

#----------------------------------
# Attach instances to their ASG
#----------------------------------

while ( InstanceStatus($instance_id) ne 'running' ){
  print "WAIT FOR ${instance_id}'s status to be 'running'\n";
  sleep(2);
}

$asgname=`cat asgnames.txt|egrep $instance_id`;chomp $asgname;
if ( $asgname =~ /^\s*$/s ){
  print "instance_id=\"$instance_id\" is NOT IN ASG. So we do not need to attach it\n";
}
else{
  $asgname =~ s/:.+$//;
  my $dt=formatDateTimeString(); print("$dt aws autoscaling attach-instances --instance-ids $instance_id --auto-scaling-group-name $asgname --region $region\n");
  my $rc=`aws autoscaling attach-instances --instance-ids $instance_id --auto-scaling-group-name $asgname --region $region`;
  print "$dt $rc";
}
#========================================================================================
sub waitUntilAlive{
my ( $ip )=@_;
 my $rc=0;
  local $_=`ping -c 1 $ip`;
  while ( ! /transmitted/ ){
    my $dt=formatDateTimeString(); print("$dt ping FAILED for ip=\"$ip\". Waiting until it works.\n");
    $_=`ping -c 1 $ip`;
  }
}
#========================================================================================
sub InstanceStatus{
my ( $instance_id )=@_;
  local $_ = `aws ec2 describe-instance-status --instance-id $instance_id --region $region`;
  my $InstanceState='';
  if ( /"InstanceState": \{(.+?)\}/s ){
     local $_ = $1;
     if ( /"Name" *: *"([^"]+)"/s ){
        $InstanceState=$1;
     }
  }
#print "DEBUG: Leaving InstanceStatus. InstanceState=\"$InstanceState\"\n";exit;
  return $InstanceState;
}
