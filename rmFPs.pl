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
$nodeFromIp = "10.0.0.128";$nodeToIp = "10.0.0.105";
# Copy file parts
print "copyFilePartsFromTo($nodeFromIp,$nodeToIp)\n";
$rc = copyFilePartsFromTo($nodeFromIp,$nodeToIp);
print "rc of copyFilePartsFromTo is \"$rc\"\n";
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
  if ( ! -e $data ){
    system("mkdir $data");
    system("chown $sshuser:$sshuser $data")
  }
  else{
    $_ = `rm -vr $data/*`
  }

  print("scp -o StrictHostKeyChecking=no -r -i $pem $sshuser\@$nodeFromIp:/var/lib/HPCCSystems/hpcc-data/* $data\n");
  system("scp -o StrictHostKeyChecking=no -r -i $pem $sshuser\@$nodeFromIp:/var/lib/HPCCSystems/hpcc-data/* $data");
  print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo rm -vr $data/*\"\n");
  system("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo rm -vr $data/*\"");
  print("scp -o StrictHostKeyChecking=no -r -i $pem $data/* $sshuser\@$nodeToIp:/home/$sshuser/hpcc-data/\n");
  system("scp -o StrictHostKeyChecking=no -r -i $pem $data/* $sshuser\@$nodeToIp:/home/$sshuser/hpcc-data/");
  print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo cp -vr /home/$sshuser/hpcc-data/* /var/lib/HPCCSystems/hpcc-data\"\n");
  system("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo cp -vr /home/$sshuser/hpcc-data/* /var/lib/HPCCSystems/hpcc-data\"");
  print("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo chown -R hpcc:hpcc /var/lib/HPCCSystems/hpcc-data\"\n");
  system("ssh -o StrictHostKeyChecking=no -i $pem -t -t $sshuser\@$nodeToIp \"sudo chown -R hpcc:hpcc /var/lib/HPCCSystems/hpcc-data\"");
  print "chmod_each_file2_644();\n";
  chmod_each_file2_644();
return $_;
}
