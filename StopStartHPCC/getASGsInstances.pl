#!/usr/bin/perl
=pod

=cut
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "$ThisDir/ClusterInitVariables.pl";
require "$ThisDir/formatDateTimeString.pl";

#$debug=1;

#===================================================================
# NOTE: This scripts REQUIRES the aws cli be install and configured.
#===================================================================

# Get json summary descriptions of all ASGs
$asgs_descriptions=`aws autoscaling describe-auto-scaling-instances --region $region 2> aws_errors.txt`;
my $err=`cat aws_errors.txt`;
if ( $err =~ /is now earlier than/ ){
  my $dt=formatDateTimeString(); die "$dt FATAL ERROR. Your computer's time is behind aws' time. Need to run \"sudo ntpdate -s time.nist.gov\" then try again. Contact Tim Humphrey. EXITING. \n";
}

@asgnames=ArrayOfValuesForKey('AutoScalingGroupName',$asgs_descriptions);
@asgnames=grep(/\b$stackname\b/,@asgnames);

@asg_description=splitASGs($asgs_descriptions);
@asg_description=grep(/\b$stackname/,@asg_description);
print "DEBUG: BEGIN ASGDs\n",join("\n#.........................................................\n",@asg_description),"\nEND ASGDs\n" if $debug;

my @asgname_and_instances=();
foreach my $asgname (@asgnames){

  # Get asg description for $asgname
  my @asg=grep(/$asgname/s,@asg_description);
  my @asg_instance_id=ArrayOfValuesForKey('InstanceId',@asg);
  print "DEBUG: ",join("\n",@asg_instance_id),"\n" if $debug;

  # push onto @asgname_and_instances the name of each asg and instances ids for all its instances
  my $asg_instance_ids=join(",",@asg_instance_id);
  my $dt=formatDateTimeString(); print("$dt Output to asgnames.txt this:$asgname:$asg_instance_ids\n"); 
  push  @asgname_and_instances, "$asgname:$asg_instance_ids";
}

#OUTPUT names of all ASG to $asgfile
my $dt=formatDateTimeString(); print("$dt SAVE hpcc auto-scaling group ids and instances in \"$asgfile\"\n");
open(OUT,">$asgfile") || die "$dt Can't open for output \"$asgfile\". Contact Tim Humphrey. EXITING.\n";
print OUT join("\n",@asgname_and_instances),"\n"; 
close(OUT);
#===========================================================
sub ArrayOfValuesForKey{
my ($key,@asg_descriptions)=@_;
my @d0=split("\n",join("\n",@asg_descriptions));
my @d1=grep(s/^ +\"$key\"\s*:\s*\"([^\"]+)\".*$/$1/,@d0);

# Remove duplicate names
my @asg_values=();
my %KeyValueExists=();
foreach (@d1){
  if ( ! exists($KeyValueExists{$_}) ){
     push @asg_values, $_;
     $KeyValueExists{$_}=1;
  }
}
return @asg_values;
}
#===========================================================
sub splitASGs{
my ( $x )=@_;
$x =~ s/^.+\"AutoScalingInstances\"\s*: *\[\s*\n//s;
$x =~ s/\n +\]\s*\n\}\s*$//s;
#print $x,"\n";

my @y=split(/\n( +)\},\s*\n/s,$x);
@y=grep(!/^\s*$/,@y);

return @y;
}
#===========================================================
