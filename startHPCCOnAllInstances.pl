#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/common.pl";
print "In startHPCCOnAllInstances.pl. pem=\"$pem\"\n";

# if this is the  Master then start cluster
if ($ThisClusterComponent eq 'Master'){
  # Start the hpcc system
  print("In $0. /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start\n");
  $_=`/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start 2>&1`;
  print "In $0. rc=\"$_\"\n";

  # I was doing the following only when thor timed out when I attempted to start it.
  #  But, because roxie doesn't indicate that it doesn't comeup correctly and a restart
  #  always seems to bring up everything correctly.
  sleep 10;
  print("In $0. /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart\n");
  $_=`/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart 2>&1`;
  print "In $0. rc=\"$_\"\n";

=pod
  # If thor didn't start then do a restart of cluster
  if ( /Starting mythor .*TIMEOUT/ ){
    print "THOR didn't start. So, doing a restart.\n";
    sleep 10;
    print("/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart\n");
    $_=`/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart 2>&1`;
    print "$_\n";
  }
=cut

  $EIP=getMasterEIP($region, $EIPAllocationId);
  print "In $0 after calling getMasterEIP. EIP=\"$EIP\".\n";

  my $message=checkStatusOfCluster($stackname,$EIP);
  AlertUserOfChangeInRunStatus($email, $stackname, $message);
}
# If this isn't a Master (i.e. thor or roxie) and no instances have been terminated (i.e. initial launch).
elsif (($ThisClusterComponent ne 'Master') && ($terminated_ip eq '')){
  print "In startHPCCOnAllInstances.pl. This is not Master (ThisClusterComponent=\"$ThisClusterComponent\") and not terminated instances. So, exiting.\n";
  exit;
}
# If this isn't a Master (i.e. thor or roxie) and instances have been terminated (i.e. not initial launch).
elsif (($ThisClusterComponent ne 'Master') && ($terminated_ip ne '')){
   my $MasterIP=`head -1 $private_ips`;chomp $MasterIP;

   # Note. terminated_ip and ThisInstanceIP are in cfg_BestHPCC.sh which is gotten with getConfigurationFile.pl above.
   print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$MasterIP \"sudo $ThisDir/forceUpdateDaliEnv.pl $terminated_ip $ThisInstanceIP $ThisClusterComponent\"");
   my $rc=`ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$MasterIP "sudo $ThisDir/forceUpdateDaliEnv.pl $terminated_ip $ThisInstanceIP $ThisClusterComponent"`;
   print "rc=\"$rc\"\n";
}
