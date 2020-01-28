#!/usr/bin/perl

my $action=(scalar(@ARGV)>0)? shift @ARGV : 'start';

$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "$ThisDir/ClusterInitVariables.pl";

$PingTries=3;
$SleepBetweenTries=5;
$ProxyIp="10.60.4.11";

$mountDisks=1;

# Get all private_ips
open(IN,$private_ips) || die "Can't open for input: \"$private_ips\"\n";
while(<IN>){
   next if /^\s*$/;
   chomp;
   $esp_ip = $_ if $. == 1;
   $slave_ip = $_ if $. == 2;
   push @private_ips, $_;
}
close(IN);

print("chmod 400 $pem\n");
system("chmod 400 $pem");

for( my $i=$#private_ips; $i >= 0; $i--){ 
  my $ip=$private_ips[$i];

  print "waitUntilAlive($ip,$PingTries)\n";
  waitUntilAlive($ip,$PingTries,$SleepBetweenTries);

  if ( $mountDisks  && ($action eq 'start') && ! $EBSVolumesMountedByFstab ){
    if ( $ephemeral ){
     if ( exists($ebs{$ip}) ){
      print "ip=\"$ip\" has EBS VOLUME. NOTHING NEEDS TO BE DONE BECAUSE mount is in /etc/fstab\n";
     }
     else{
      print("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo ./raid_format_mount.pl $mountpoint\"\n");
      my $rc=`ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip "sudo ./raid_format_mount.pl $mountpoint"`;
      print("$dt $rc\n");
     }
    }
    else{
     my $dev2mount=getDev2Mount($ip);
print "After calling getDev2Mount. dev2mount=\"$dev2mount\"\n";
     print("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo mount /dev/$dev2mount /var/lib/HPCCSystems\"\n");
     system("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo mount /dev/$dev2mount /var/lib/HPCCSystems\"");
    }
  }
}

#Start HPCC on all instances.
my $ip=$private_ips[0];
print("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init $action\"\n");
my $rc=`ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip "sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init $action"`;
print("$dt $rc\n");
#------------------------------------------
sub getDev2Mount{
my ($ip)=@_;
 my $lsblk=`ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip "lsblk"`;
print "DEBUG: In getDev2Mount. lsblk=\"$lsblk\"\n";
 my @line=split(/\n/,$lsblk);
 my $dev2mount=$1 if $line[$#line] =~ /^\s*(\S+)/;
 $dev2mount=~s/[^[:ascii:]]//g;
#print "DEBUG: In getDev2Mount. AFTER extracting. dev2mount=\"$dev2mount\"\n";
return $dev2mount;
}
#------------------------------------------
sub waitUntilAlive{
my ( $ip, $tries, $SleepBetweenTries )=@_;
 my $saved_tries=$tries;
 my $rc=0;
  print "ping -c 1 $ip\n";
  local $_=`ping -c 1 $ip`;
  print $_;
  sleep($SleepBetweenTries);
  while ( ! /[1-9] received/s && ($tries>0) ){
    print "ping FAILED for ip=\"$ip\". Waiting until it works.\n";
    print "ping -c 1 $ip\n";
    sleep($SleepBetweenTries);
    $_=`ping -c 1 $ip`;
    print $_;
    $tries--;
  }

  if ( $tries <= 0 ){
     die "$saved_tries tries at pinging $ip. Still NOT alive.\n";
  }
}
