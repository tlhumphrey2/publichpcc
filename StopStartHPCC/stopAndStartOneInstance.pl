#!/usr/bin/perl
=pod
=cut

$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# NOTE: This scripts REQUIRES the aws cli be setup.

die "USAGE ERROR: $0 REQUIRES an instance id on command line.\n" if scalar(@ARGV) == 0;

$instance_id = shift @ARGV;
$region = shift @ARGV;
$action = (scalar(@ARGV)>0)? shift @ARGV : 'stop' ;

goto "START" if $action eq 'start';

#----------------------------------
# Stop instance
#----------------------------------
STOP:
if ( InstanceStatus($instance_id) eq '' ){
  print("DO NOT NEED TO STOP BECAUSE $instance_id IS ALREADY STOPPED.\n");
}
else{
  print("aws ec2 stop-instances --instance-ids $instance_id --region $region\n");
  my $rc=`aws ec2 stop-instances --instance-ids $instance_id --region $region`;
  print "$rc";
}

goto "END" if $action eq 'start';

START:
#----------------------------------
# Wait for instance to be fully stopped
#----------------------------------
while ( InstanceStatus($instance_id) eq 'running' ){
  print "WAIT FOR ${instance_id}'s status to be 'stopped'\n";
  sleep(2);
}

#----------------------------------
# Start instance
#----------------------------------
START2:
if ( InstanceStatus($instance_id) eq 'running' ){
  print("DO NOT NEED TO START BECAUSE $instance_id IS ALREADY STARTED.\n");
}
else{
  print(" aws ec2 start-instances --instance-ids $instance_id --region $region\n");
  my $rc=`aws ec2 start-instances --instance-ids $instance_id --region $region`;
  print "DEBUG: After attempting to start. rc=\"$rc\"\n";

  my $InBadSate=0;
  while ( $rc =~ /is not in a state from which it can be started/s ){
    $InBadState=1;
    print "WAIT FOR ${instance_id}'s to be in a state where we can start it.\n";
    sleep(5);
  }

  goto "START2" if $InBadState;

  if ( $rc !~ /StartingInstances/s ){
    die "FATAL ERROR. While attempting to start instance, \"$instance_id\".\n$rc\nContact Tim Humphrey. EXITING. \n";
  }
}

if ( $action eq 'start' ){
  #----------------------------------
  # Wait for instance to be fully stopped
  #----------------------------------
  while ( InstanceStatus($instance_id) ne 'running' ){
    print "WAIT FOR ${instance_id}'s status to be NOT 'running'.\n";
    sleep(2);
  }
  goto "STOP";
}

END:
exit;
#========================================================================================
sub waitUntilAlive{
my ( $ip )=@_;
 my $rc=0;
  local $_=`ping -c 1 $ip`;
  while ( ! /transmitted/ ){
    print(" ping FAILED for ip=\"$ip\". Waiting until it works.\n");
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
