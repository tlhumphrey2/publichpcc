#!/usr/bin/perl
@argv=@ARGV;
print "DEBUG: Entering setup_zz_zNxlarge_disks.pl. JUST AFTER 1ST LINE. \@argv=(",join(", ",@argv),")\n";
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/common.pl";
$sshuser=getSshUser();

# Get all lsblk lines with non-root device lines.
@xvdlines=get_lsblk_xvdlines();
local $nextdriveletter=(scalar(@xvdlines)>0)? getNextDriveLetter($xvdlines[$#xvdlines]) : 'b';
print "DEBUG: nextdriveletter=\"$nextdriveletter\"\n";

print "DEBUG: In setup_zz_zNxlarge_disks.pl. AFTER require getConfigurationFile.pl. \@ARGV=(",join(", ",@ARGV),")\n";

$sixteenTB=16384;

# If there are command line arguments and the 1st is nummeric or volume id
#  So, 1) if argument is nummeric then make an ebs volume the size given in 1st commandline argument, 
#  2) attach volume to this instance. NOTE. if $DownedVolumeId!~/^\s*$/ then we have an instance that 
#  has gone down and we need to attach its volume to this instance, which is just coming up.
if ( ($DownedInstanceId !~ /^\s*$/) || (( scalar(@argv) > 0 ) && (( $argv[0] =~ /^\d+$/ ) || ( $argv[0] =~ /^vol\-/ ))) ){
  local $ClusterComponent =($DownedInstanceId!~/^\s*$/)? $DownedNodeType : $argv[1];
  $ebsInfo = ($DownedInstanceId!~/^\s*$/)? getEBSVolumeID($stackname, $ClusterComponent) : $argv[0];
  shift @argv;
  shift @argv;
  local $instanceID=`curl http://169.254.169.254/latest/meta-data/instance-id`;
  local $az = getAZ($region,$instanceID);
  print "DEBUG: AS FOR EBS. ebsInfo=\"$ebsInfo\", region=\"$region\", az=\"$az\", nextdriveletter=\"$nextdriveletter\"\n";
  local $v='';
  local @Volume2Attach=();
  @xvdlines=();
  if ( $ebsInfo =~ /^\d+$/ ){
    # if volume size <= 16TB, which is maximum allowable size of single EBS volume.
    if ( $ebsInfo <= $sixteenTB ){
      my $v=makeEBSVolume($ebsInfo, $az, $region);
      push @Volume2Attach, $v;
      push @xvdlines, "xvd$nextdriveletter";
    }
    # Multiply ebs volumes must be made because $ebsInfo > 16TB.
    else{
      my $save_ebssize=$ebsInfo;
      my $v=makeEBSVolume($sixteenTB, $az, $region);
      push @Volume2Attach, $v;
      push @xvdlines, "xvd$nextdriveletter";
      $ebsInfo = $ebsInfo-$sixteenTB;
      while ( $ebsInfo > $sixteenTB ){
        $nextdriveletter++;
        my $v=makeEBSVolume($sixteenTB, $az, $region);
        push @Volume2Attach, $v;
        push @xvdlines, "xvd$nextdriveletter";
        $ebsInfo = $ebsInfo-$sixteenTB;
      }
      if ( $ebsInfo > 0 ){
        $nextdriveletter++;
        my $v=makeEBSVolume($ebsInfo, $az, $region);
        push @Volume2Attach, $v;
        push @xvdlines, "xvd$nextdriveletter";
      }
      $ebsInfo = $save_ebssize;
    }
  }
  # If $ebsInfo is not an integer (i.e. not ebs size) then it must be a volume id
  else{
    $v = $ebsInfo;
    #print "aws ec2 create-tags --resources $v --tags Key=Name,Value=$stackname--$ClusterComponent --region $region\n";
    #my $changeTag=`aws ec2 create-tags --resources $v --tags Key=Name,Value=$stackname-$ClusterComponent --region $region`;
    #print "DEBUG: changeTag=\"$changeTag\"\n";
    push @Volume2Attach, $v;
    push @xvdlines, "xvd$nextdriveletter";
  }

  # Attach all ebs volumes
  for (my $i=0; $i < scalar(@xvdlines); $i++){
    my $v=$Volume2Attach[$i];
    my $dev = $xvdlines[$i];

    #-------------------------------------------------------------------------------------------------------------------------
    # Loop until volume is attached (if instance isn't ready volume won't be attached).
    my $c=0;
    ATTACHVOLUME:
    $c++;
     print("$c. aws ec2 attach-volume --volume-id $v --instance-id $instanceID --device $dev --region $region &> /home/ec2-user/attach-volume.log\n");
     system("aws ec2 attach-volume --volume-id $v --instance-id $instanceID --device $dev --region $region &> /home/ec2-user/attach-volume.log");

     $_=`aws ec2 describe-volumes --volume-ids $v --region $region|$ThisDir/json2yaml.sh`;
     if ( ! /\{AttachTime: '\d{4}-\d{2}-\d{2}T/s ){
       sleep(5);
       goto "ATTACHVOLUME";
     }
=pod
     my $attach_vol=`cat /home/ec2-user/attach-volume.log`;
     $attach_vol =~ s/\n+//g;
     print "DEBUG: attach_vol=\"$attach_vol\"\n";
     sleep(5);
    goto "ATTACHVOLUME" if $attach_vol =~ /IncorrectState/s;
=cut
    #-------------------------------------------------------------------------------------------------------------------------

    # modify DeleteOnTermination to be true
    print "Change DeleteOnTermination to false\n";
    print("bash /home/ec2-user/DeleteOnTermination2False.sh $instanceID $dev $region\n");
    system("bash /home/ec2-user/DeleteOnTermination2False.sh $instanceID $dev $region");
  }
  print "DEBUG: Leaving EBS processing code.\n";
}

#----------------------------------------------------------------
# If drives xvd[b-z] exists, then do what is needed to raid, format, and mount them
if ( scalar(@xvdlines) >= 1 ){
   # umount devices that are mounted
   foreach (@xvdlines){
      # check to see if drive should be umounted
      my $drv=getdrv($_);
      push @drv, $drv;

      if ( /disk\s+[^\s]/ ){
         print(" umount /dev/$drv\n");
         system(" umount /dev/$drv");
      }
   }

   #----------------------------------------------------------------
   # MAKE raid command which, in $raid_template, replacing <ndrives> and <driveletters> with appropriate values.
   $raid_template=" mdadm --create /dev/md0 --run --assume-clean --level=0 --chunk=2048 --raid-devices=<ndrives> /dev/xvd[<driveletters>]";
   $ndrives=scalar(@drv);
   @driveletters=map(getsfx($_),@xvdlines);
   $driveletters=join('',@driveletters);
   $_=$raid_template;
   s/<ndrives>/$ndrives/;
   s/<driveletters>/$driveletters/;

   #----------------------------------------------------------------
   if ( scalar(@xvdlines) > 1 ){
     # Do raid
     print("$_\n");
     system("$_");
     $mountdevice="/dev/md0"
   }
   else{
     my $drv=getdrv($xvdlines[0]);
     $mountdevice="/dev/$drv"
   }

   #----------------------------------------------------------------
   print(" yum install xfsprogs.x86_64 -y\n");
   system(" yum install xfsprogs.x86_64 -y");

   #----------------------------------------------------------------
   if ((!defined($ebsInfo)) || ( $ebsInfo =~ /^\d+$/ )){
     print(" mkfs.ext4 $mountdevice\n");
     system(" mkfs.ext4 $mountdevice");
   }

   #----------------------------------------------------------------
   print(" mount $mountdevice /mnt\n");
   system(" mount $mountdevice /mnt");

   #----------------------------------------------------------------
   print(" yum install bonnie++.x86_64 -y\n");
   system(" yum install bonnie++.x86_64 -y");

   #----------------------------------------------------------------
   print(" mount -o remount -o noatime /mnt/\n");
   system(" mount -o remount -o noatime /mnt/");

   #----------------------------------------------------------------
   print(" mkdir -p /var/lib/HPCCSystems &&  mount $mountdevice /var/lib/HPCCSystems\n");
   system(" mkdir -p /var/lib/HPCCSystems &&  mount $mountdevice /var/lib/HPCCSystems");
#   print("mkdir -p /mnt/var/lib/HPCCSystems && ln -s  /mnt/var/lib/HPCCSystems  /var/lib/HPCCSystems\n");
#   system("mkdir -p /mnt/var/lib/HPCCSystems && ln -s  /mnt/var/lib/HPCCSystems  /var/lib/HPCCSystems");
}
#----------------------------------------------------------------
# SUBROUTINES
#----------------------------------------------------------------
sub getdrv{
my ($l)=@_;
  local $_=$l;
  s/^\s*(xvd.).+$/$1/;
print "Leaving getdrv. return \"$_\"\n";
return $_;
}
#----------------------------------------------------------------
sub getsfx{
my ($l)=@_;
  local $_=$l;
  s/^\s*xvd(.).*$/$1/;
print "Leaving getsfx. return \"$_\"\n";
return $_;
}
#----------------------------------------------------------------
sub getNextDriveLetter{
my ($lastxvdline)=@_;
my $lastdrv=getdrv($lastxvdline);
my $lastdrvletter=substr($lastdrv,length($lastdrv)-1);
my $nextdrvletter=++$lastdrvletter;
return $nextdrvletter;
}
#----------------------------------------------------------------
sub get_lsblk_xvdlines{
# Get all devices
local $_=`lsblk`;
my @x=split("\n",$_);
my @xvdlines=sort grep(/\bxvd[b-z]\b/,@x);
print "\@xvdlines=(",join(", ",@xvdlines),")\n";
return @xvdlines;
}
#----------------------------------------------------------------
sub getAZ{
my ($region,$instanceID)=@_;
  # Get instance id from metadata
  my $az=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone`;chomp $az;
  return $az;
}
#----------------------------------------------------------------
sub makeEBSVolume{
my ($ebssize, $az, $region)=@_;
   print "aws ec2 create-volume --size $ebssize --region $region --availability-zone $az --volume-type gp2  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=$stackname--$ClusterComponent}]'\n";
   my $makeebs=`aws ec2 create-volume --size $ebssize --region $region --availability-zone $az --volume-type gp2  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=$stackname--$ClusterComponent}]'`;
   print "DEBUG: makeebs=\"$makeebs\"\n";
   my $volumeid = ($makeebs=~/"VolumeId"\s*: "(vol-[^"]+)"/)? $1 : '';

   # Wait until volume is available
   print "In makeEBSVolme. aws ec2 describe-volumes --region $region --volume-ids $volumeid\n";
   local $_=`aws ec2 describe-volumes --region $region --volume-ids $volumeid 2>&1`;
   my $volume_available=(/"State"\s*:\s*"available"/s)? 1 : 0 ;
   my $c=0;
   while ( ! $volume_available && ( $c <= 20 ) ){
      $c++;
      print "In makeEBSVolume. $c. volume is not available, yet. WAITING.\n";
      sleep 5;
      print "In makeEBSVolme. aws ec2 describe-volumes --region $region --volume-ids $volumeid\n";
      local $_=`aws ec2 describe-volumes --region $region --volume-ids $volumeid 2>&1`;
      $volume_available=(/"State"\s*:\s*"available"/s)? 1 : 0 ;
   }

   print "In makeEBSVolume. Volume, $volumeid, is now available.\n";

return $volumeid;
}
#----------------------------------------------------------------
# call $volid=getEBSVolumeID($stackname, $ClusterComponent);
sub getEBSVolumeID{
my ($stackname, $ClusterComponent)=@_;
my $tagvalue="$stackname--$ClusterComponent";
local $_=`aws ec2 describe-volumes --filters Name=tag:Name,Values=$tagvalue --region $region|$ThisDir/json2yaml.sh`;
print "DEBUG: In getEBSVolumeID. \$_=\"$_\"\n";
my @volid=m/\n(- Attachments:.+?\n  VolumeType:[^\n]+)/gs;
foreach my $dv (@volid){ print "VolumeDescription=\"$dv\"\n"; }
die "FATAL ERROR: In getEBSVolumeID. Can't handle this situation, i.e. where more than one $ClusterComponent instance goes down.\n" if scalar(grep(/State: available/,@volid)) > 1;
die "FATAL ERROR: In getEBSVolumeID. There should be a volume available but there is not for $ClusterComponent instance that went down.\n" if scalar(grep(/State: available/,@volid)) == 0;
my $x; ($x)=grep(/State: available/,@volid);
print "DEBUG: In getEBSVolumeID. x=\"$x\"\n";
my $v=($x=~/VolumeId: (vol-\w+)/)? $1 : '';
print "DEBUG: Leaving getEBSVolumeID. v=\"$v\"\n";
return $v;
}
