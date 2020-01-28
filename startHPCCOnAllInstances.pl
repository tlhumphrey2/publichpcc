#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/common.pl";
print "Entering startHPCCOnAllInstances.pl. pem=\"$pem\"\n";

# Master doesn't exist of $master_exists is blank.
$master_exists=`aws s3 ls s3://$stackname/master-created`;

# If this instance is Master OR Master already exists and no instance is down (meaning this instance is newly added non-master instance)
if (($ThisClusterComponent eq 'Master')){
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

  $EIP=getMasterEIP($stackname, $region, $EIPAllocationId);
  print "In $0 after calling getMasterEIP. EIP=\"$EIP\".\n";

  my $message = checkStatusOfCluster($stackname,$EIP);
  AlertUserOfChangeInRunStatus($region, $email, $stackname, $message);
}
# If this isn't a Master (i.e. thor or roxie) and (instances have been terminated OR Master already exists)
#   (i.e. not initial launch).
elsif (($ThisClusterComponent ne 'Master') && ($terminated_ip ne '')){
   my $MasterIP=`head -1 $private_ips`;chomp $MasterIP;

   # Note. terminated_ip and ThisInstancePrivateIP are in cfg_BestHPCC.sh which is gotten with getConfigurationFile.pl above.
   print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$MasterIP \"sudo $ThisDir/forceUpdateDaliEnv.pl $ThisInstancePrivateIP $ThisClusterComponent $terminated_ip\"");
   my $rc=`ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$MasterIP "sudo $ThisDir/forceUpdateDaliEnv.pl $ThisInstancePrivateIP $ThisClusterComponent $terminated_ip"`;
   print "rc=\"$rc\"\n";
}
=pod
# COMMENTED OUT BECAUSE ADDING INSTANCES NOT DONE BY USERDATA NOW (20200109) 
# if this instance is slave or roxie and master already exists then adjust process lines of env 
#  and push to all instances and restart cluster.
elsif (($ThisClusterComponent ne 'Master') && ($master_exists ne '')){
  print "In $0. Slave or Roxie & Master exists. orderComponentProcessLinesByLaunchTime( '/etc/HPCCSystems/environment.xml', $stackname, $ThisClusterComponent)\n";
  my $new_env_file = orderComponentProcessLinesByLaunchTime( '/etc/HPCCSystems/environment.xml', $stackname, $ThisClusterComponent);
  print "In $0. cp -v $new_env_file $out_environment_file\n";
  $_=`cp -v $new_env_file $out_environment_file`;
  print "In $0. cp new_environment.xml return code is \"$_\"\n";
  print "In $0. cp -v $new_env_file $created_environment_file\n";
  $_=`cp -v $new_env_file $created_environment_file`;

  # push to all cluster instances
  print "In $0. /opt/HPCCSystems/sbin/hpcc-push.sh -s $created_environment_file -t $out_environment_file\n"; 
  $_ = `/opt/HPCCSystems/sbin/hpcc-push.sh -s $created_environment_file -t $out_environment_file`; 
  print "In $0. push return code is \"$_\"\n";

  # restart cluster
  print("In $0. /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart\n");
  $_=`/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart 2>&1`;
  print "In $0. rc=\"$_\"\n";

  my $message = checkStatusOfCluster($stackname,$EIP);
  AlertUserOfChangeInRunStatus($region, $email, $stackname, $message);
}
=cut
else{
  print "In $0. DID NOT START CLUSTER.\n";
}
