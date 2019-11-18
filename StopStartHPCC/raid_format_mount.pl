#!/usr/bin/perl

$mountpoint=shift @ARGV;
$sshuser=shift @ARGV;

# Get all devices
$_=`lsblk`;
@x=split("\n",$_);
@xvdlines=grep(/\bxvd[b-z]/,@x);
print "\@xvdlines=(",join(", ",@xvdlines),")\n";

#----------------------------------------------------------------
# If drives xvd[b-z] exists, then do what is needed to raid, format, and mount them
if ( scalar(@xvdlines) >= 1 ){
   # umount devices that are mounted
   foreach (@xvdlines){
      # check to see if drive should be umounted
      my $drv=getdrv($_);
      print "After calling getdrv. drv=\"$drv\"\n";
      push @drv, $drv;

      if ( /disk\s+[^\s]/ ){
         print(" umount /dev/$drv\n");
         system(" umount /dev/$drv");
      }
   }

   #----------------------------------------------------------------
   # MAKE raid command which, in $raid_template, replacing <ndrives> and <driveletters> with appropriate values.
   $raid_template="mdadm --create /dev/md0 --force --run --assume-clean --level=0 --chunk=2048 --raid-devices=<ndrives> /dev/xvd[<driveletters>]";
   $ndrives=scalar(@drv);
   @driveletters=map(getsfx($_),@xvdlines);
   $driveletters=join('',@driveletters);
   $_=$raid_template;
   s/<ndrives>/$ndrives/;
   s/<driveletters>/$driveletters/;
}

if ( scalar(@xvdlines) > 1 ){
   #----------------------------------------------------------------
   # Do raid
   print("Do raid: $_\n");
   system("$_");
   $drv2mount='/dev/md0';
}
elsif ( scalar(@xvdlines) == 1 ){
   $drv2mount="/dev/$drv[0]";
}

if ( scalar(@xvdlines) > 0 ){
   #----------------------------------------------------------------
   print(" yum install xfsprogs.x86_64 -y\n");
   system(" yum install xfsprogs.x86_64 -y");

   #----------------------------------------------------------------
   # Construct XFS filesystem on $drv2mount
   print(" mkfs.ext4 $drv2mount\n");
   system(" mkfs.ext4 $drv2mount");

   #----------------------------------------------------------------
   print(" mount $drv2mount /mnt\n");
   system(" mount $drv2mount /mnt");

   #----------------------------------------------------------------
   print(" yum install bonnie++.x86_64 -y\n");
   system(" yum install bonnie++.x86_64 -y");

   #----------------------------------------------------------------
   print(" mount -o remount -o noatime /mnt/\n");
   system(" mount -o remount -o noatime /mnt/");

   #----------------------------------------------------------------
   mountDrive($drv2mount,$mountpoint);

   #----------------------------------------------------------------

}
#----------------------------------------------------------------
# SUBROUTINES
#----------------------------------------------------------------
sub getdrv{
my ($l)=@_;
print "Entering getdrv. l=\"$l\"\n";
  local $_=$l;
  s/^\s*(xvd.).+$/$1/;
print "Leaving getdrv. return \"$_\"\n";
return $_;
}
#----------------------------------------------------------------
sub getsfx{
my ($l)=@_;
  local $_=$l;
  s/^\s*xvd(.).+$/$1/;
print "Leaving getsfx. return \"$_\"\n";
return $_;
}
#----------------------------------------------------------------
sub mountDrive{
my ($drv2mount,$mountpoint)=@_;
 print("mkdir $mountpoint\n");
 system("mkdir $mountpoint");
 print("mount $drv2mount $mountpoint\n");
 my $x=`mount $drv2mount $mountpoint 2>&1`;chomp $x;
 print "Status of mount is \"$x\"\n";
 if ( $x =~ /is a symbolic link to nowhere/ ){
   print "$mountpoint is a symbolic link\n";
   print("rm -r $mountpoint\n");
   system("rm -r $mountpoint");
   print("mkdir $mountpoint\n");
   system("mkdir $mountpoint");
   print("mount $drv2mount $mountpoint\n");
   system("mount $drv2mount $mountpoint");
 }

 print("chown $sshuser:$sshuser $mountpoint\n");
 system("chown $sshuser:$sshuser $mountpoint");
}
