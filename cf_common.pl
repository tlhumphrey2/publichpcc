#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
#=====================================================================
# Note: The qElement hash tells what information this routine can give about cluster instances.
# Also the order is the same as the order of elements in @DesiredInfo
sub getClusterInstanceInfo{
my ($region, $stackname, @DesiredInfo)=@_;
#print "DEBUG: Entering getClusterInstanceInfo. region=\"$region\", stackname=\"$stackname\". Size of \@DesiredInfo is ",scalar(@DesiredInfo),".\n";
  my %qElement = ();
  $qElement{'InstanceId'} = 'InstanceId';
  $qElement{'State'} = 'State.Name';
  $qElement{'StateReason'} = 'StateReason.Message';
  $qElement{'LaunchTime'} = 'LaunchTime';
  $qElement{'StateChangeReason'} = 'StateTransitionReason';
  $qElement{'VolumeIds'} = 'BlockDeviceMappings[*].[Ebs.VolumeId, DeviceName]';
  $qElement{'PublicIp'} = 'PublicIpAddress';
  $qElement{'PublicIpAddress'} = 'PublicIpAddress';
  $qElement{'PrivateIp'} = 'PrivateIpAddress';
  $qElement{'PrivateIpAddress'} = 'PrivateIpAddress';
  $qElement{'InstanceType'} = 'InstanceType';
  $qElement{'InstanceName'} = "[Tags[?Key=='Name'].Value][0][0]";
  $qElement{'Name'} = "[Tags[?Key=='Name'].Value][0][0]";
  $qElement{'pem'} = "[Tags[?Key=='pem'].Value][0][0]";
  $qElement{'slavesPerNode'} = "[Tags[?Key=='slavesPerNode'].Value][0][0]";
  $qElement{'roxienodes'} = "[Tags[?Key=='roxienodes'].Value][0][0]";
  $qElement{'HPCCPlatform'} = "[Tags[?Key=='HPCCPlatform'].Value][0][0]";

  my @qElement = ();
  push @qElement, $qElement{'InstanceId'};
  push @qElement, $qElement{'State'};
  push @qElement, $qElement{'LaunchTime'};
  push @qElement, $qElement{'StateChangeReason'};
  push @qElement, $qElement{'VolumeIds'};
  push @qElement, $qElement{'PublicIp'};
  push @qElement, $qElement{'PublicIpAddress'};
  push @qElement, $qElement{'PrivateIp'};
  push @qElement, $qElement{'PrivateIpAddress'};
  push @qElement, $qElement{'InstanceType'};
  push @qElement, $qElement{'InstanceName'};
  push @qElement, $qElement{'Name'};
  push @qElement, $qElement{'pem'};
  push @qElement, $qElement{'slavesPerNode'};
  push @qElement, $qElement{'roxienodes'};
  push @qElement, $qElement{'HPCCPlatform'};

  my $filters = ($stackname !~ /^\s*$/)? "--filters Name=tag:StackName,Values=$stackname" : '';

  # If @DesiredInfo is empty then get all the information about cluster instances
  if ( scalar(@DesiredInfo) > 0 ){
    @qElement = ();
    foreach (@DesiredInfo){
      push @qElement, $qElement{$_};
    }
  }
  #print "DEBUG: Size of \@qElement is ",scalar(@qElement),".\n";

  my $qElements = join(", ",@qElement);
  $_ = `aws ec2 describe-instances --region $region $filters --query "Reservations[*].Instances[*].[$qElements]" --output text`;
  s/[\/]dev[\/]//sg;
  my @InstanceInfo = split(/\n/,$_);
  my @OutInfo=();
  foreach (@InstanceInfo){
     if ( /\bvol\-/ ){
       s/([^\s])\s+([^\s])/$1:$2/;
       $OutInfo[$#OutInfo] .= " $_";
     }
     else{
       s/\s+/ /g;
       push @OutInfo, $_;
     }
  }
  return @OutInfo;
}
#=====================================================================
# $stackname_prefix is all of the prefix except the last dash and the
#  digits that follow (just to the right of) it.
# This routine finds all the StackNames with the prefix of $stackname_prefix
#  that were gotten by "aws cloudformation list-stacks". Sorts then
#  and returns 1 more than the one with the largest digits.

sub NextStackNumber{
my ($stackname_prefix,$region)=@_;
$x=`aws cloudformation list-stacks --region $region`;
@x=split(/\n/,$x);
@y=grep(/"StackName": "$stackname_prefix/,@x);
@z = sort { RMN($a) <=> RMN($b)} @y; # Do numeric sort on just the right most number
$hnum_sname = ( $z[$#z] =~ /$stackname_prefix-(\d+)/ )? $1+1 : 1 ;
return $hnum_sname;
}
#====================================
# Gets the number at the end of a string(i.e. right most end).
sub RMN{
my ( $s )=@_;
# e.g. input '            "StackName": "XPertHR-ML-2016-02-19-2", '
local $_=($s=~/\"StackName": \"([^\"]+)\"/)? $1 : '';
#print "DEBUG: Entering RMN. s=\"$_\"\n";
my $n=(/^.*?(\d+)$/)? $1 : '' ;
#print "DEBUG: Leaving RMN. n=\"$n\"\n";
return $n;
}
#=====================================================================
sub getHPCCInstanceIds{
my ( $region, $stackname )=@_;
# Get just instances with tag:Name Value of "$stackname--*"
my $t=`aws ec2 describe-instances --region $region --filter "Name=tag:Name,Values=$stackname--*"`;
my @t=split("\n",$t);
#print "DEBUG: length of instance with stackname = \"$stackname\" is ",`wc -c t`,"\n";

my $HPCCNodeTypes_re='(?:Master|Slave|Roxie|Support)';
my $m_re="$stackname--($HPCCNodeTypes_re)|InstanceId.:";
my @x=grep(/$m_re/,@t);
# reverse list if first entry isn't a HPCC node type. We want the list to be node type following by instance_id, ... 
@x=reverse @x if $x[0] !~ /$HPCCNodeTypes_re/;
for( my $i=0; $i < scalar(@x); $i++){
  local $_=$x[$i];
  if ( /$stackname--Master/ ){
     push @master, $x[$i+1]; # push master instance_id
  }
  elsif ( /$stackname--Slave/ ){
     push @slave, $x[$i+1]; # push master instance_id
  }
  elsif ( /$stackname--Roxie/ ){
     push @roxie, $x[$i+1]; # push master instance_id
  }
  elsif ( /$stackname--Support/ ){
     push @support, $x[$i+1]; # push support instance_id
  }
}
@x=(@master,@slave,@roxie,@support);

# Remove everything but instance id.
@x=grep(s/^.+InstanceId\":\s\"([^\"]+)\".*$/$1/,@x);
#print "DEBUG: instance ids=(",join(",",@x),")\n";
return @x;
}
#==========================================================================================================
sub getCfgVariablesFromInstanceDescriptions{
my ($InstanceDescriptions,@CfgVariable)=@_;

   # Split descriptions into lines
   my @InstanceDescriptionsLine=split(/\n/,$InstanceDescriptions);

   # Look for the variable name and get its value. Store in %ValueOfCfgVariable.
   my $re='\b'.join("|",@CfgVariable).'\b';
   my $VariablesFound=0;
   for( my $i=0; $i < scalar(@InstanceDescriptionsLine); $i++){
       local $_=$InstanceDescriptionsLine[$i];
       if ( /"Key": "($re)"/ ){
          my $v=$1;
          $_=$InstanceDescriptionsLine[$i-1]; # Get value on previous line
          s/^.*"Value"\s*:\s+"([^\"]*)".*$/$1/; # Remove everything but the value
          $ValueOfCfgVariable{$v}=($v eq 'pem')? "$ThisDir/$_.pem" : $_; # If $v is 'pem' add '.pem' to end
          $VariablesFound=1;
print "DEBUG: In getCfgVariablesOfInstanceDescriptions. \$ValueOfCfgVariable{$v}=\"$ValueOfCfgVariable{$v}\"\n";
       }
   }
print "DEBUG: In getCfgVariablesOfInstanceDescriptions. NO VARIABLES FOUND in instance descriptions.\n" if $VariablesFound==0;
}
#==========================================================================================================
1;
