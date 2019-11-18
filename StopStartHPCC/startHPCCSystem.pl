#!/usr/bin/perl
=pod
This script does:
1. Reads asg name a a list of instance ids from asgnames.txt
2. Starts all instances
3. Attaches all instances to their asg.
=cut

$ThisDir=($0 =~ /^(.+)[\\\/]/)? $1 : "." ;
require "$ThisDir/ClusterInitVariables.pl";

# NOTE: This scripts REQUIRES the aws cli be setup.

# Don't ssh into bastion until it is alive
print "waitUntilAlive($bastion_ip)\n";
waitUntilAlive($bastion_ip);

print("ssh -o stricthostkeychecking=no -i $pem -t -t $sshuser\@$bastion_ip \"/home/$sshuser/startHPCCOnAllInstances.pl\"\n");
my $rc=`ssh -o stricthostkeychecking=no -i $pem -t -t $sshuser@$bastion_ip "/home/$sshuser/startHPCCOnAllInstances.pl"`;
print("ssh -o stricthostkeychecking=no -i $pem -t -t $sshuser\@$bastion_ip \"sudo service httpd start\"\n");
my $rc=`ssh -o stricthostkeychecking=no -i $pem -t -t $sshuser@$bastion_ip "sudo service httpd start"`;

print $rc;
if ( $rc =~ /Still NOT alive/si ){
  die "FATAL ERROR: While ssh'ing to bastion to start all hpcc instances. Contact Tim Humphrey. EXITING.\n";
}
#========================================================================================
sub waitUntilAlive{
my ( $ip )=@_;
 my $rc=0;
  local $_=`ping -c 1 $ip`;
  while ( ! /transmitted/ ){
    print "ping FAILED for ip=\"$ip\". Waiting until it works.\n";
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
