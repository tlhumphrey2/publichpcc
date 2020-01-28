#!/usr/bin/perl

$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/common.pl";

my $sshuser=shift @ARGV;
my $stackname=shift @ARGV;
my $region=shift @ARGV;

my $pem = "$ThisDir/$stackname.pem";
print "chmod 400 $pem\n";
$_=`chmod 400 $pem`;
print "rc of chmod 400 $pem is \"$_\"\n";
$_=`chown $sshuser:$sshuser $pem`;
print "rc of chown $sshuser:$sshuser $pem is \"$_\"\n";
my $pemfilename;
($pemfilename=$pem) =~ s/^.*\///;

local $instance_ids="$ThisDir/instance_ids.txt";
local $private_ips="$ThisDir/private_ips.txt";
local $public_ips="$ThisDir/public_ips.txt";
local $nodetypes="$ThisDir/nodetypes.txt";

my @sorted_InstanceInfo=getRunningNoneBastionInstances($region,$stackname);
my %FirstInstanceVariables=(scalar(@sorted_InstanceInfo)==0)? () : %{$sorted_InstanceInfo[0]};

# Wait until all hpcc instances are running. When the Master instance is the 1st instance then all hpcc instances are available.
my $c=0;
print "scalar(\@sorted_InstanceInfo)=",scalar(@sorted_InstanceInfo),", FirstInstanceVariables{'Name'}=\"$FirstInstanceVariables{'Name'}\"\n";
while( (scalar(@sorted_InstanceInfo)==0) || ($FirstInstanceVariables{'Name'} ne 'Master') ){

  $c++;
  print "$c. Waiting for all hpcc instances to be running and for the master to be one of them.\n";
  sleep 5;
  @sorted_InstanceInfo=getRunningNoneBastionInstances($region,$stackname);
  %FirstInstanceVariables=(scalar(@sorted_InstanceInfo)==0)? () : %{$sorted_InstanceInfo[0]};
  print "scalar(\@sorted_InstanceInfo)=",scalar(@sorted_InstanceInfo),", FirstInstanceVariables{'Name'}=\"$FirstInstanceVariables{'Name'}\"\n";
}

getMasterAuthorizedKeysAndPutInMine($sshuser,$pem,$FirstInstanceVariables{'PrivateIpAddress'});
#---------------------------------------------------
sub getMasterAuthorizedKeysAndPutInMine{
my ($sshuser,$pem, $ip)=@_;
my $c=0;
LOOP:
  print "scp -o stricthostkeychecking=no -i $pem $sshuser\@$ip:/home/$sshuser/.ssh/authorized_keys /home/$sshuser 2>&1\n";
  my $rc=`scp -o stricthostkeychecking=no -i $pem $sshuser\@$ip:/home/$sshuser/.ssh/authorized_keys /home/$sshuser 2>&1`;
  $c++; print "$c. rc of scp is \"$rc\"\n";
  if ( $rc =~ /Connection refused/ ){
    print "$c. Connection refused. Try again.\n";
    sleep 5;
    goto "LOOP";
  }
  print "In getMasterAuthorizedKeysAndPutInMine: COMPLETED COPY OF MASTER'S authorized_keys TO HERE, i.e. THE BASTION.\n";

  print "In getMasterAuthorizedKeysAndPutInMine: tail -1 $ThisDir/authorized_keys >> $ThisDir/.ssh/authorized_keys\n";
  my $rc=`tail -1 $ThisDir/authorized_keys >> $ThisDir/.ssh/authorized_keys 2>&1`;
  print "In getMasterAuthorizedKeysAndPutInMine. tail rc=\"$rc\"\n";
}
