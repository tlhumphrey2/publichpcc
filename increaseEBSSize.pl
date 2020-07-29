#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
=pod
~/increaseEBSSize.pl Slave 10 cluster-info-files-setup 2>&1|tee increaseEBSSize.log
~/increaseEBSSize.pl Slave 20 cluster-info-files-setup
~/increaseEBSSize.pl Master 20
=cut
$input_nodetype = shift @ARGV;
$size = shift @ARGV;
$ClusterInfoFilesExist = (scalar(@ARGV)>0)? 1 : 0;
shift @ARGV if scalar(@ARGV)>0;

print "DEBUG: Entering increaseEBSSize.pl input_nodetype=\"$input_nodetype\", size=\"$size\", ClusterInfoFilesExist=\"$ClusterInfoFilesExist\"\n";

# Get all instance
print "DEBUG: In increaseDBSSize.pl. $ThisDir/StopStartHPCC/setupClusterInfoFiles.pl 2> /dev/null\n";
$_ = `$ThisDir/StopStartHPCC/setupClusterInfoFiles.pl 2> /dev/null`;
s/\n+$//s;
@instance = split(/\n/,$_);
print "DEBUG: In increaseEBSSize.pl \@instance:\n",join("\nDEBUG: In increaseEBSSize.pl ",@instance),"\nDEBUG: In increaseEBSSize.pl -----------------\n";
$region_and_stackname = shift @instance;
($region, $stackname) = split(/\s+/,$region_and_stackname);
$pem = "$ThisDir/$stackname.pem";
foreach my $i (@instance){
  # Get instance's info
  my ($instance_id, $nodetype, $private_ip, $public_ip) = split(/\s+/,$i);
  next if $nodetype ne $input_nodetype;

  # Get volume id of /dev/xvdb attached to instance
  my $volume_id = `$ThisDir/getClusterEbsVolumes.pl $region $stackname $private_ip|cut -d" " -f 2|sed "s/:xvdb//"`;chomp $volume_id;
  print "DEBUG: In increaseEBSSize.pl. instance_id=\"$instance_id\", nodetype=\"$nodetype\", private_ip=\"$private_ip\", public_ip=\"$public_ip\", volume_id=\"$volume_id\".\n";

  $current_size = `$ThisDir/describe-volumes.sh $volume_id $region|cut -d" " -f 6`;chomp $current_size;
  print "DEBUG: current_size=\"$current_size\"\n";

  if ( $size != $current_size ){
    # aws ec2 modify-volume --size $size --volume-id $volume_id
    print "DEBUG: In increaseEBSSize.pl: aws ec2 modify-volume --size $size --volume-id $volume_id --region $region\n";
    $_ = `aws ec2 modify-volume --size $size --volume-id $volume_id --region $region 2>&1`;
    s/^\s+//s;
    print "$volume_id: $_\n";

    waitVolumeToComplete($region,$volume_id);
  
    if ( ! /error occurred/s ){
      RESIZE:
      # ssh into instance and do "resize2fs /dev/xvdb".
      print "DEBUG: In increaseEBSSize.pl: ssh -o StrictHostKeyChecking=no -t -t -i $pem ec2-user\@$ip \"sudo resize2fs /dev/xvdb\"\n";
      $_ = `ssh -o StrictHostKeyChecking=no -t -t -i $pem ec2-user\@$private_ip "sudo resize2fs /dev/xvdb 2>&1"`;
      $_ = (/(The filesystem on .+ is now \d+ blocks long.)/)? $1 : "WARNING: Something went wrong with resize2fs because we did not get \"The filesystem on $volume_id is now N blocks long.\" message returned.";
      s/\/dev\/xvdb/$volume_id/;
      print "volume_sizes_changed. $_\n";
    }
  }
  else{
	  print "WARNING: Volume, \"$volume_id\", of $instance_id is currently at the desired size, $size\n";
  }
}
# ===========================================================================
# waitVolumeToComplete($REGION,$VolumeId);
sub waitVolumeToComplete{
my ($REGION,$VolumeId)=@_;
   my $VOLUMEPROGRESS="0%";
   while (( "$VOLUMEPROGRESS" ne "available" ) && ( "$VOLUMEPROGRESS" ne "in-use" )){
     print "Volume ID: ${VolumeId} ${VOLUMEPROGRESS}\n";
     sleep 10;

     @volume_details=describe_volumes($REGION,$VolumeId);
     $VOLUMEPROGRESS=$volume_details[5];
     print "DEBUG: \@volume_details=\"",join("\n",@volume_details),"\"\n";
   }
   print "Volume ID: ${VolumeId} 100%\n";
}
# ===========================================================================
sub describe_volumes{
my ($REGION, $VolumeId)=@_;
   local $_;
   my @volume_details=();
   # if $VolumeId exists
   # The following commented-out command gets the 'Name' of the volume on the end
#  print "aws ec2 describe-volumes --region $REGION --volume-ids $VolumeId --query 'Volumes[*].[VolumeId, Attachments[0].InstanceId, AvailabilityZone, Attachments[0].Device, Encrypted, State, Size, Tags[?Key==\`Name\`].Value], CreateTime' --output text\n";
   $_=`aws ec2 describe-volumes --region $REGION --volume-ids $VolumeId --query 'Volumes[*].[VolumeId, Attachments[0].InstanceId, AvailabilityZone, Attachments[0].Device, Encrypted, State, Size, Tags[?Key==\`Name\`].Value, CreateTime]' --output text 2>&1`; chomp $_;
   if ( ! /does not exist/s ){
     @volume_details=split(/[\s,]+/,$_);
   }
   else{
    print "$_";
   }
return @volume_details;
}

