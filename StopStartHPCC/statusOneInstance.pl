#!/usr/bin/perl
=pod
=cut

$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# NOTE: This scripts REQUIRES the aws cli be setup.

die "USAGE ERROR: $0 REQUIRES an instance id on command line.\n" if scalar(@ARGV) == 0;

$instance_id = shift @ARGV;
$region = shift @ARGV;

$status=InstanceStatus($instance_id);
print "region=\"$region\", instance_id=\"$instance_id\". Status=\"$status\"\n";
#========================================================================================
sub InstanceStatus{
my ( $instance_id )=@_;
  print "aws ec2 describe-instance-status --instance-id $instance_id --region $region\n";
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
