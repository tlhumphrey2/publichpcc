#!/usr/bin/perl

$ThisDir=($0=~/^(.*)\//)? $1 : ".";

require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/common.pl";

my $sshuser=shift @ARGV;
my $stackname=shift @ARGV;
my $region=shift @ARGV;

my $pem = "$ThisDir/$stackname.pem";
print "chmod 400 $pem\n";
$_=`chmod 400 $pem`;
print "rc of chmod 400 $pem is \"$_\"\n";
my $pemfilename;
($pemfilename=$pem) =~ s/^.*\///;

local $instance_ids="$ThisDir/instance_ids.txt";
local $private_ips="$ThisDir/private_ips.txt";
local $public_ips="$ThisDir/public_ips.txt";
local $nodetypes="$ThisDir/nodetypes.txt";

my @sorted_InstanceInfo=getRunningNoneBastionInstances($region,$stackname);
my %InstanceVariables=(scalar(@sorted_InstanceInfo)==0)? () : %{$sorted_InstanceInfo[0]};

# Wait until all hpcc instances are running. When the Master instance is the 1st instance then all hpcc instances are available.
my $c=0;
print "scalar(\@sorted_InstanceInfo)=",scalar(@sorted_InstanceInfo),", InstanceVariables{'Name'}=\"$InstanceVariables{'Name'}\"\n";
while( (scalar(@sorted_InstanceInfo)==0) || ($InstanceVariables{'Name'} ne 'Master') ){

  $c++;
  print "$c. Waiting for all hpcc instances to be running and for the master to be one of them.\n";
  sleep 5;
  @sorted_InstanceInfo=getRunningNoneBastionInstances($region,$stackname);
  %InstanceVariables=(scalar(@sorted_InstanceInfo)==0)? () : %{$sorted_InstanceInfo[0]};
  print "scalar(\@sorted_InstanceInfo)=",scalar(@sorted_InstanceInfo),", InstanceVariables{'Name'}=\"$InstanceVariables{'Name'}\"\n";
}

putHPCCInstanceInfoInFiles(\@sorted_InstanceInfo);
my @private_ips=split(/\n/,`cat $private_ips`); @private_ips=grep(!/^\s*$/,@private_ips); 
print "Number of private_ips is ",scalar(@private_ips),"\n";
foreach my $ip (@private_ips){
  next if $HasPemFile{$ip};

  print "copy2HPCCInstance($sshuser, $pem, $pemfilename, $ip)\n";
  copy2HPCCInstance($sshuser, $pem, $pemfilename, $ip);
  $HasPemFile{$ip}=1;
}

=pod
# 2/14/2019. THIS HAS BEEN TEMPORARILY COMMENTED OUT.
# Associate EIP with Master instance
if ( "$EIPAllocationId" ne "" ){
  # Get master's instance id
  my $MasterInstanceId=`head -1 $instance_ids`; chomp $MasterInstanceId;
  print "In $0: aws ec2 associate-address --instance-id $MasterInstanceId --allocation-id $EIPAllocationId --region $region\n";
  my $rc=`aws ec2 associate-address --instance-id $MasterInstanceId --allocation-id $EIPAllocationId --region $region`;
  print "In $0. rc of 'associate-address' is \"$rc\"\n";
}
else{
  print "WARNING. In $0. Master's/ECL Watch EIP was NOT in the configuration file.\n";
}
=cut
#---------------------------------------------------
sub copy2HPCCInstance{
my ($sshuser,$pem, $pemfilename, $ip)=@_;
my $c=0;
LOOP:
  print "scp -o stricthostkeychecking=no -i $pem $pem $sshuser\@$ip:/home/$sshuser/$pemfilename 2>&1\n";
  my $rc=`scp -o stricthostkeychecking=no -i $pem $pem $sshuser\@$ip:/home/$sshuser/$pemfilename 2>&1`;
  $c++; print "$c. rc of scp is \"$rc\"\n";
  if ( $rc =~ /Connection refused/ ){
    print "$c. Connection refused. Try again.\n";
    sleep 5;
    goto "LOOP";
  }
 # print "ssh -o stricthostkeychecking=no -i $pem $sshuser\@$ip \"chmod 400 /home/ec2-use/$pemfilename\"\n";
 # my $rc=`ssh -o stricthostkeychecking=no -i $pem $sshuser\@$ip "chmod 400 /home/ec2-use/$pemfilename"`;
 # print "rc of ssh is \"$rc\"\n";
}
