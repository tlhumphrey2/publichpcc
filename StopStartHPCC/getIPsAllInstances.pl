#!/usr/bin/perl

$ThisDir=($0 =~ /^(.+)[\\\/]/)? $1 : "." ;
require "$ThisDir/ClusterInitVariables.pl";

# NOTE: This scripts REQUIRES the aws cli be setup.

#----------------------------------
# Status all instances
#----------------------------------
@asgname=();
@all_instance_id=();
if ( open(IN,$asgfile) ){
 while (<IN>){
   chomp;
   my ($asgname,$csv_instance_list)=split(/:/,$_);
#  next if $asgname !~ /SlaveASG/; # DEBUG DEBUG DEBUG
   push @asgname, $_;
   my @asg_instance_id=split(/,/,$csv_instance_list);
   push @all_instance_id, @asg_instance_id;
 }
 close(IN);
}
else{
 print "WARNING: Can't open for input, \"$asgfile\"\n";
}

# Add any instances in @additional_instances.
foreach my $instance_id (@additional_instances){
   push @all_instance_id, $instance_id;
}

print "There are ",scalar(@all_instance_id)," instances in this system.\n";
foreach my $instance_id (@all_instance_id){
  my $ip = InstanceIP($instance_id);
  print "$instance_id	$ip\n";
}
#========================================================================================
sub InstanceIP{
my ( $instance_id )=@_;
  local $_ = `aws ec2 describe-instances --instance-id $instance_id --region $region`;
#  print "DEBUG: In InstanceIP. \"$_\"\n";
  if ( /"PrivateIpAddress": "(\d+(?:\.\d+){3})"/ ){
     $InstanceIP=$1;
  }
  else{
  }
#  print "DEBUG: Leavning InstanceIP. InstanceIP=\"$InstanceIP\".\n";
  return $InstanceIP;
}
