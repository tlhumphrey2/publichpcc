#!/usr/bin/perl
=pod
This script does:
1. Reads asg name a a list of instance ids from asgnames.txt
2. Starts all instances
3. Attaches all instances to their asg.
=cut

$ThisDir=($0 =~ /^(.+)[\\\/]/)? $1 : "." ;
require "$ThisDir/ClusterInitVariables.pl";
require "$ThisDir/formatDateTimeString.pl";

# NOTE: This scripts REQUIRES the aws cli be setup.

#----------------------------------
# Start all instances
#----------------------------------
my $dt=formatDateTimeString(); print("$dt START ALL Instances of $stackname.\n");
open(IN,"asgnames.txt") || die "$dt Can't open for input, \"asgnames.txt\"\n";
while (<IN>){
   chomp;
   my ($asgname,$csv_instance_list)=split(/:/,$_);
   push @asgname, $_;
}
close(IN);

#----------------------------------
# Attach all HPCC instances to their ASG
#----------------------------------
foreach (@asgname){
   my ($asgname,$csv_instance_list)=split(/:/,$_);
   my @asg_instance_id=split(/,/,$csv_instance_list);
   foreach my $instance_id (@asg_instance_id){
     while ( InstanceStatus($instance_id) ne 'running' ){
	 print "WAIT FOR ${instance_id}'s status to be 'running'\n";
         sleep(2);
     }
     my $dt=formatDateTimeString(); print("$dt aws autoscaling attach-instances --instance-ids $instance_id --auto-scaling-group-name $asgname --region $region\n");
     my $rc=`aws autoscaling attach-instances --instance-ids $instance_id --auto-scaling-group-name $asgname --region $region`;
   }
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
