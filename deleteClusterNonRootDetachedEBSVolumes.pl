#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/cf_common.pl";
=pod
deleteClusterNonRootDetachedEBSVolumes.pl eu-west-1 mhpcc-eu-west-1-tdj-130 vol-080020c04e1508e21
deleteClusterNonRootDetachedEBSVolumes.pl eu-west-1 mhpcc-eu-west-1-uyv-129 vol-04d10fc61230dbada vol-0b9de362a7215db53 vol-017ac34c5e03684b9
=cut

$region = shift @ARGV;
$stackname = shift @ARGV;
@volume_id = ();
while(scalar(@ARGV) > 0 ){
  push @volume_id, shift @ARGV;
}
print STDERR "DEBUG: Entering deleteClusterNonRootEBSVolumes.pl region=\"$region\", \@volume_id=(",join(",",@volume_id),")\n";

my %volume_ids2delete = ();
foreach (@volume_id){
  $volume_ids2delete{$_}=1;
}

#  First get ebs volumes that are still attached
%attached_ebs_volumes = getAttachedNonRootEBSVolumes($region,$stackname);
if ( scalar(keys %attached_ebs_volumes) > 0 ){
  foreach my $v (keys %attached_ebs_volumes){
     my ($volume_id, $device)=split(/:/,$v);
     if ( $volume_ids2delete{$volume_id} ){
        $volume_ids2delete{$volume_id}=0;
     }
  }
}

# Second, delete each ebs volume
foreach my $volume_id (keys %volume_ids2delete){
  if ( $volume_ids2delete{$volume_id} ){
    $rc = delete_volume($region, $volume_id);
    print STDERR "delete_volume($region, $volume_id) rc=\"$rc\"\n";
  }
}

#=================================================================================
sub delete_volume{
my ($REGION, $VolumeId)=@_;
   local $_=`aws ec2 delete-volume --region $REGION --volume-id $VolumeId`; chomp $_;
   return $_;
}
#---------------------------------------------------------------------------------
sub getAttachedNonRootEBSVolumes{
my ($region, $stackname)=@_;
  my @DesiredInfo = ();
  $DesiredInfo[0]='InstanceId';
  $DesiredInfo[1]='VolumeIds';

  my @InstanceInfo = getClusterInstanceInfo ($region, $stackname, @DesiredInfo);
  print STDERR "DEBUG: In getAttachedNonRootEBSVolumes. ",join("\nDEBUG: In getAttachedNonRootEBSVolumes ",@InstanceInfo),"\n";

  %attached_ebs_volumes = ();
  foreach (@InstanceInfo){
    my ($instance_id, $root_volume, $non_root_volume) = split(/\s+/,$_);
    $attached_ebs_volumes{$non_root_volume} = $instance_id;
  }

return %attached_ebs_volumes;
}
