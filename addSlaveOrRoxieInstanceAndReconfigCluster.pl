#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/cf_common.pl";
require "$ThisDir/common.pl";
=pod
USAGE EXAMPLE:
  sudo $ThisDir/addSlaveOrRoxieInstanceAndReconfigCluster.pl Slave 5 Roxie 5 &> $ThisDir/addSlaveOrRoxieInstanceAndReconfigCluster.log

  # Initiating run of addSlaveOrRoxieInstanceAndReconfigCluster.pl from someplace outside of Master
  ssh -o stricthostkeychecking=no -i $pem -t -t ec2-user@$mip "export ThisDir=/home/ec2-user;. cfg_BestHPCC.sh;sudo $ThisDir/addSlaveOrRoxieInstanceAndReconfigCluster.pl Slave 3 Roxie 3 &> $ThisDir/addSlaveOrRoxieInstanceAndReconfigCluster.log"

  1. Start monitoring from $mip. Send it the new number of thor slaves and roxies.
     A. Get instance descriptions which will tell the number instances that are currently running.
     B. Change ASG DesiredCapacity
     aws autoscaling set-desired-capacity --auto-scaling-group-name $asg --desired-capacity 5 --region $region
     C. Loop until the number of instances is equal to the new number of instances.
        while true;do
           getClusterInstanceDescriptions.pl us-west-1 test-add-drop-instances-9;
           echo "======================================";
           sleep 10;
        done
     D. Run setupCfgFileVariables.pl, with correct commandline args, to setup cfg_BestHPCC.sh and
        all *.txt files
     E. Loop again until all instances have /dev/xvdb mounted on /var/lib/HPCCSystems. 
        while true;do
           for x in `cat private_ips.txt`;do ssh -i $pem ec2-user@$x "lsblk";done
           sleep 10;
        done
     F. Run final_configureHPCC.sh to make environment.xml using envgen and push it to all instances.
     G. Run startHPCCOnAllInstances.pl to start cluster
=cut
$rc = putAddingSlavesOrRoxies($stackname, $region, 'true');
print "Entering addSlaveOrRoxieInstanceAndReconfigCluster.pl: rc of putAddingSlavesOrRoxies is \"$rc\"\n";

$ClusterInstanceType1 = shift @ARGV;
$NewNumber{$ClusterInstanceType1} = shift @ARGV;
$ClusterInstanceType2 = shift @ARGV;
$NewNumber{$ClusterInstanceType2} = shift @ARGV;

( $asgname{$ClusterInstanceType1} ) =getASGNames($region, $stackname, $ClusterInstanceType1);
( $asgname{$ClusterInstanceType2} ) =getASGNames($region, $stackname, $ClusterInstanceType2);
print "asgname{$ClusterInstanceType1}=\"$asgname{$ClusterInstanceType1}\", asgname{$ClusterInstanceType2}=\"$asgname{$ClusterInstanceType2}\"\n";

# For both Slave and Roxie Clusters 1) increase DesiredCapacity for their ASG and wait for all newly launched instances to be running.
foreach my $ClusterInstanceType (keys %asgname){
  $CurrentNumber{$ClusterInstanceType} = `$ThisDir/getClusterInstanceDescriptions.pl $region $stackname|egrep $ClusterInstanceType|wc -l`; chomp $CurrentNumber{$ClusterInstanceType};
  # Set ASG's DesiredCapacity to $NewNumber{$ClusterInstanceType}
  $_ =  `aws autoscaling set-desired-capacity --auto-scaling-group-name $asgname{$ClusterInstanceType} --desired-capacity $NewNumber{$ClusterInstanceType} --region $region`;
  print "Return from \"aws autoscaling set-desired-capacity\" is \"$_\"\n";

  # Waiting for all instances of $ClusterInstanceType to be running
  while ( $CurrentNumber{$ClusterInstanceType} < $NewNumber{$ClusterInstanceType} ){
   $CurrentNumber{$ClusterInstanceType} = `$ThisDir/getClusterInstanceDescriptions.pl $region $stackname|egrep $ClusterInstanceType|wc -l`; chomp $CurrentNumber{$ClusterInstanceType};
   sleep(10);
  }  
  print "CurrentNumber{$ClusterInstanceType}=\"$CurrentNumber{$ClusterInstanceType}\"\n";
}

# Run setupCfgFileVariables.pl to place cluster descriptive variables in $ThisDir/cfg_BestHPCC.sh and fill private_ips.txt and instance_ids.txt
$_ = `$ThisDir/setupCfgFileVariables.pl -clustercomponent Master -stackname $stackname -region $region -pem $pem 2>&1`;
print "Return from setupCfgFileVariables.pl is \"$_\"\n";

# Make sure all disks are mounted. Wait until this is true.
my $AllDisksMounted = 0;
local @private_ip = ();
open(IN, "$private_ips") || die "Can't open for input: \"$private_ips\"\n";
while(<IN>){
  chomp;
  next if /^\s*$/ || /^#/;
  push @private_ip, $_;
}
close(IN);
print "Just before checking if all disks mounted: \@private_ip=(",join(",",@private_ip),")\n";
do{
   sleep(10);
   $AllDisksMounted = checkAllDisksMounted();
} while ( ! $AllDisksMounted );

# Run final_configureHPCC.sh to make environment.xml using envgen and push it to all instances.
$_ = `$ThisDir/final_configureHPCC.sh 2>&1`;
print "Return from final_configureHPCC.sh is \"$_\"\n";

# Run startHPCCOnAllInstances.pl to start cluster
$_ = `$ThisDir/startHPCCOnAllInstances.pl 2>&1`;
print "Return from startHPCCOnAllInstances.pl is \"$_\"\n";

$rc = putAddingSlavesOrRoxies($stackname, $region, 'false');
print "Leaving addSlaveOrRoxieInstanceAndReconfigCluster.pl: rc of putAddingSlavesOrRoxies is \"$rc\"\n";
#==========================================================================
sub checkAllDisksMounted{
  my $AllDisksMounted = 1;
  $hpccDir = '.var.lib.HPCCSystems';
  print "In checkAllDisksMounted. hpccDir=\"$hpccDir\". \@private_ip=(",join(",",@private_ip),")\n";
  foreach my $ip (@private_ip){
    print "In checkAllDisksMounted. ssh -o StrictHostKeyChecking=no -i $pem ec2-user\@$ip \"lsblk\"\n";
    $_ = `ssh -o StrictHostKeyChecking=no -i $pem ec2-user\@$ip "lsblk"`;
    print "In checkAllDisksMounted. returned from \"ssh -o StrictHostKeyChecking=no -i $pem ec2-user\@$ip \"lsblk\"\": \"$_\"\n";
    if ( ! /$hpccDir/s ){
      print "In checkAllDisksMounted. DID NOT SEE \"$hpccDir\". RETURNING!\n";

      $AllDisksMounted = 0;
      last;
    }
  }
return $AllDisksMounted;  
}
