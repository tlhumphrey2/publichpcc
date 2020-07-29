#!/usr/bin/perl

my $action=(scalar(@ARGV)>0)? shift @ARGV : 'start';

$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "$ThisDir/ClusterInitVariables.pl";

$PingTries=10;
$SleepBetweenTries=5;

$mountDisks=1;

$mip = `paste $ThisDir/private_ips.txt $ThisDir/nodetypes.txt|egrep Master|cut -f 1`; chomp $mip;

print "waitUntilAlive($mip,$PingTries)\n";
waitUntilAlive($mip,$PingTries,$SleepBetweenTries);

print("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$mip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init $action\"\n");
my $rc=`ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$mip "sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init $action"`;
print("$dt $rc\n");
#------------------------------------------
sub getDev2Mount{
my ($mip)=@_;
 my $lsblk=`ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$mip "lsblk"`;
print "DEBUG: In getDev2Mount. lsblk=\"$lsblk\"\n";
 my @line=split(/\n/,$lsblk);
 my $dev2mount=$1 if $line[$#line] =~ /^\s*(\S+)/;
 $dev2mount=~s/[^[:ascii:]]//g;
#print "DEBUG: In getDev2Mount. AFTER extracting. dev2mount=\"$dev2mount\"\n";
return $dev2mount;
}
#------------------------------------------
sub waitUntilAlive{
my ( $mip, $tries, $SleepBetweenTries )=@_;
 my $saved_tries=$tries;
 my $rc=0;
  print "ping -c 1 $mip\n";
  local $_=`ping -c 1 $mip`;
  print $_;
  sleep($SleepBetweenTries);
  while ( ! /[1-9] received/s && ($tries>0) ){
    print "ping FAILED for ip=\"$mip\". Waiting until it works.\n";
    print "ping -c 1 $mip\n";
    sleep($SleepBetweenTries);
    $_=`ping -c 1 $mip`;
    print $_;
    $tries--;
  }

  if ( $tries <= 0 ){
     die "$saved_tries tries at pinging $mip. Still NOT alive.\n";
  }
}
