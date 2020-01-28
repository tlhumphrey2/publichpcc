#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
print "ThisDir=\"$ThisDir\"\n";
require "$ThisDir/ClusterInitVariables.pl";
local $home = "$ThisDir/..";
require "$home/getConfigurationFile.pl";
require "$home/common.pl";
require "$home/cf_common.pl";

=pod
IMPORTANT NOTE: root will call this routine.

USAGE EXAMPLE:
StopStartHPCC/removeClusterInstance.pl 'ThorCluster' 2

The command line arguments are: 1) the cluster type, and 2) the number of instances to remove.
=cut
#=============================================================================================================
$ClusterType = shift @ARGV;
$Number2Remove = shift @ARGV;

# Save environment.xml file in case we need to recover.
save_environment_file();

#1. Disable these processes in ASGs: Launch, Terminate, HealthCheck
print "$ThisDir/suspendASGProcesses.pl\n";
$_=`$ThisDir/suspendASGProcesses.pl 2>&1`;
print "rc=$_\n";

@nodeFromIp = ();
$ErrorCondition = 0;
REMOVE_INSTANCES:
 # 2. get IP of instance to remove: any instance for roxie and for thor this is highest s value instance.)
 print "python $ThisDir/getNodeIdAndIpOfCluster.py $ClusterType\n";
 $_ = `python $ThisDir/getNodeIdAndIpOfCluster.py $ClusterType`;chomp;
 ( $node2remove, $node2cpfiles ) = split(/,\s+(?=node2)/,$_);
 eval("\$$node2remove");
 eval("\$$node2cpfiles");
 print "\@node2remove=\"@$node2remove\", \@node2cpfiles=\"@$node2cpfiles\".\n";

 # 3. NodeIP = node2remove[1]
 $nodeIP = $$node2remove[1];
 print "IP of instance to remove is \"$nodeIP\"\n";

 # 4. FilePartsExists = checkForFilePartsOn(ClusterType, nodeIP)
 print "checkForFilePartsOn($ClusterType, $nodeIP)\n";
 $FilePartsExists = checkForFilePartsOn($ClusterType, $nodeIP);
 print "FilePartsExists=\"$FilePartsExists\"\n";

 # 5. removeInstanceFromEnv(ClusterType, FilePartsExists)
 print "python $ThisDir/removeInstanceFromEnv.py $ClusterType \"$FilePartsExists\"\n";
 $_ = `python $ThisDir/removeInstanceFromEnv.py $ClusterType "$FilePartsExists"`;chomp;
 ( $node2remove, $node2cpfiles ) = split(/,\s+(?=node2)/,$_);
 eval("\$$node2remove");
 eval("\$$node2cpfiles");
 print "After call to removeInstanceFromEnv.py. \@node2remove=\"@$node2remove\", \@node2cpfiles=\"@$node2cpfiles\".\n";

 # if node to remove is 'None' then environment.xml cannot be modified and user needs to know.
 if ( $$node2remove[0] eq 'None'){
   print "Cannot modify environment.xml because $ClusterType doesn't exists.\n";
   my $message = "Cannot modify environment.xml because $ClusterType doesn't exists.";
   AlertUserOfChangeInRunStatus($region, $email, $stackname, $message);
   restore_environment_file();
   $ErrorCondition = 1;
 }
 elsif ( $FilePartsExists && ($$node2cpfiles[0] eq 'None') ){
   print "Cannot modify environment.xml because File Parts Exists on node to remove, IP=\"$$node2remove[1]\", but no other $ClusterType node exists to put file parts on.\n"; 
   my $message = "Cannot modify environment.xml because File Parts Exists on node to remove, IP=\"$$node2remove[1]\", but no other $ClusterType node exists to put file parts on.";
   AlertUserOfChangeInRunStatus($region, $email, $stackname, $message);
   restore_environment_file();
   $ErrorCondition = 1;
 }
 # ELSE 7. environment.xml was modified and we know there is another node to copy file parts, if they exists.
 else{
   $nodeToIp = $$node2cpfiles[1];
   $nodeFromIp = $$node2remove[1];
   print "(nodeFromIp,nodeToIp)=($nodeFromIp,$nodeToIp)\n";

   push @nodeFromIp, $nodeFromIp;

   if ($FilePartsExists ){
 # 8.Copy file parts
     print "copyFilePartsFromTo($nodeFromIp,$nodeToIp)\n";
     $rc = copyFilePartsFromTo($nodeFromIp,$nodeToIp);
     print "rc of copyFilePartsFromTo is \"$rc\"\n";
   }
 }
   
 $Number2Remove--; # Decrement Number2Remove
 goto "REMOVE_INSTANCES" if ( ! $ErrorCondition ) && ( $Number2Remove > 0 );

if ( ! $ErrorCondition ){
# 9. Push new environment.xml to all cluster instances
  $envfile = '/etc/HPCCSystems/environment.xml';
  print "/opt/HPCCSystems/sbin/hpcc-push.sh -s $envfile -t $envfile\n";
  $_ = `/opt/HPCCSystems/sbin/hpcc-push.sh -s $envfile -t $envfile`;
  print "Push return come is \"$_\"\n";

# A. restart cluster
  print "/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart\n";
  $_ = `/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart`;
  print "Push return come is \"$_\"\n";

 foreach $nodeFromIp (@nodeFromIp){
   # B. Take instance out of autoscaling group
   $instance_id = getInstanceId($nodeFromIp);
   print "takeInstanceOutOfASG($region, $stackname, $ClusterType, $instance_id)\n";
   $_ = takeInstanceOutOfASG($region, $stackname, $ClusterType, $instance_id);
   print "rc of takeInstanceOutOfASG is \"$_\"\n";

   # C. terminate $nodeFromIp
   print "aws ec2 terminate-instances --instance-ids $instance_id --region $region\n";
   $_ = `aws ec2 terminate-instances --instance-ids $instance_id --region $region`;
   print "rc of terminate-instances is \"$_\"\n";
 }
}

# D. Enable these processes in appropriate ASG:Launch, Terminate, HealthCheck
print "$ThisDir/resumeASGProcesses.pl\n";
$_=`$ThisDir/resumeASGProcesses.pl 2>&1`;
print "rc=$_\n";
#===============================================================================
sub checkForFilePartsOn{
my ($ClusterType, $nodeIP)=@_;
print "Entering checkForFilePartsOn. ClusterType = \"$ClusterType\", nodeIP=\"$nodeIP\", pem=\"$pem\".\n";
  $cluster = ($ClusterType eq 'ThorCluster')? 'thor': 'roxie';
  $_ = `ssh -o StrictHostKeyChecking=no -i $pem $sshuser\@$nodeIP "ls -Rl /var/lib/HPCCSystems/hpcc-data/" 2>&1`;chomp;
$rc = ( /\._\d+_of_\d+/s )? 1 : 0;    
print "Leaving checkForFilePartsOn. rc = \"$rc\".\n";
return $rc;    
}
#===============================================================================
sub getAllPartFiles{
my ( $dir, @partfiles )=@_;
  if ( opendir(DIR,$dir) )
  {
      my @dir_entry = readdir(DIR);
      closedir(DIR);
      foreach (@dir_entry){
        next if /^\./;
        if ( -d $_ ){
          my $dir = "$dir/$_";
          @partfiles = getAllPartFiles($dir, @partfiles);
        }
        elsif ( /\._\d+_of_\d+$/ ){
          push @partfiles, "$dir/$_";
        }
      }
  }
  else
  {
     print("In getAllPartFiles. FATAL ERROR: Couldn't open directory for \"$dir\"\n");
     exit 1;
  }
return @partfiles;
}
#===============================================================================
sub chmod_each_file2_644{
my ( $nodeToIp )=@_;
  @partfiles = ();
  $dir = '/var/lib/HPCCSystems/hpcc-data';
  @partfiles = getAllPartFiles($dir, @partfiles);
  foreach my $partfile (@partfiles){
    print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo chmod 664 $partfile\"\n");
    system("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo chmod 664 $partfile\"");
  }
}
#===============================================================================
sub copyFilePartsFromTo{
my ( $nodeFromIp, $nodeToIp )=@_;
  my $data = "/home/$sshuser/hpcc-data";
  if ( -e $data ){
    $_ = `rm -vr $data`
  }
=pod
  else{
    system("mkdir $data");
  }
=cut

  print("scp -o StrictHostKeyChecking=no -r -i $pem $sshuser\@$nodeFromIp:/var/lib/HPCCSystems/hpcc-data $data\n");
  system("scp -o StrictHostKeyChecking=no -r -i $pem $sshuser\@$nodeFromIp:/var/lib/HPCCSystems/hpcc-data $data");
  print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"if [ -e \"$data\" ];then sudo rm -vr $data;fi\"\n");
  system("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"if [ -e \"$data\" ];then sudo rm -vr $data;fi\"");
  print("scp -o StrictHostKeyChecking=no -r -i $pem $data $sshuser\@$nodeToIp:/home/$sshuser/hpcc-data/\n");
  system("scp -o StrictHostKeyChecking=no -r -i $pem $data $sshuser\@$nodeToIp:/home/$sshuser/hpcc-data/");
  print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo cp -vr /home/$sshuser/hpcc-data/* /var/lib/HPCCSystems/hpcc-data\"\n");
  system("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo cp -vr /home/$sshuser/hpcc-data/* /var/lib/HPCCSystems/hpcc-data\"");
  print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo chown -R hpcc:hpcc /var/lib/HPCCSystems/hpcc-data\"\n");
  system("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo chown -R hpcc:hpcc /var/lib/HPCCSystems/hpcc-data\"");
  print "chmod_each_file2_644();\n";
return $_;
}
#===============================================================================
# USAGE EXAMPLE: $rc = takeInstanceOutOfASG($region, $stackname, $ClusterType, $instance_id);
sub takeInstanceOutOfASG{
my ($region, $stackname, $ClusterType, $instance_id)=@_;
  my $filter = ( $ClusterType eq 'ThorCluster')? 'SlaveASG': 'RoxieASG';
  ($asgname) = getASGNames( $region, $stackname, $filter );
  print "In takeInstanceOutOfASG. \$MinSize=aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $asgname --region $region --query \"AutoScalingGroups[*].[MinSize]\" --output text\n";
  $MinSize=`aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $asgname --region $region --query "AutoScalingGroups[*].[MinSize]" --output text`; chomp $MinSize;
  $MinSize = $MinSize-1 if $MinSize > 0;
  print "In takeInstanceOutOfASG. MinSize=\"$MinSize\"\n";
  print "In takeInstanceOutOfASG. aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asgname --min-size $MinSize --region $region\n";
  $_=`aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asgname --min-size $MinSize --region $region`;
  print "rc of 'aws autoscaling update-auto-scaling-group --min-size' is \"$_\"\n";
  print "aws autoscaling detach-instances --instance-ids $instance_id --auto-scaling-group-name $asgname --should-decrement-desired-capacity --region $region\n";
  $_ = `aws autoscaling detach-instances --instance-ids $instance_id --auto-scaling-group-name $asgname --should-decrement-desired-capacity --region $region`;
  return $_;
}
#===============================================================================
sub getInstanceId{
my ($nodeFromIp)=@_;
print "Entering getInstance. nodeFromIp=\"$nodeFromIp\"\n";
$_ = `paste $instance_ids $private_ips`; chomp;
my @instance=split(/\n/,$_);
( $_ ) = grep(/\b$nodeFromIp\b/,@instance);
s/[ \t]*$nodeFromIp\s*$//;
print "Leaving getInstance. nodeFromIp's instance id is \"$_\"\n";
return $_;
}
#===============================================================================
sub restore_environment_file{
  print "cp -v /etc/HPCCSystems/environment.xml-saved-for-recovery /etc/HPCCSystems/environment.xml\n";
  system("cp -v /etc/HPCCSystems/environment.xml-saved-for-recovery /etc/HPCCSystems/environment.xml");
}
#===============================================================================
sub save_environment_file{
  print "cp -v /etc/HPCCSystems/environment.xml /etc/HPCCSystems/environment.xml-saved-for-recovery\n";
  system("cp -v /etc/HPCCSystems/environment.xml /etc/HPCCSystems/environment.xml-saved-for-recovery");
}
