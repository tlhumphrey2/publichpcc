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

if ( InstanceStatus($public_lz_instance_id) eq 'running' ){
    my $dt=formatDateTimeString(); print("$dt DO NOT NEED TO START BECAUSE public_lz, $instance_id, IS ALREADY STARTED.\n");
}
else{
   my $dt=formatDateTimeString(); print("$dt aws ec2 start-instances --instance-ids $public_lz_instance_id --region $region\n");
   my $rc=`aws ec2 start-instances --instance-ids $public_lz_instance_id --region $region`;
   print("$dt $rc\n");
}


#----------------------------------
# Start all instances
#----------------------------------
my $dt=formatDateTimeString(); print("$dt START ALL Instances of $stackname.\n");
open(IN,"asgnames.txt") || die "$dt Can't open for input, \"asgnames.txt\"\n";
while (<IN>){
   chomp;
   my ($asgname,$csv_instance_list)=split(/:/,$_);
   push @asgname, $_;
   my @asg_instance_id=split(/,/,$csv_instance_list);
   foreach my $instance_id (@asg_instance_id){
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
     sleep(5); # sleep 5 seconds with the hope that more time between starts will eliminate errors.
   }
}
close(IN);
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
