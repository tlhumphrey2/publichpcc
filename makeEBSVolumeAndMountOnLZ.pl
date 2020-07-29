#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

=pod
sudo $ThisDir/makeEBSVolumeAndMountOnLZ.pl
=cut

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";
require "$thisDir/common.pl";

$stdout = *STDOUT;
$cp2s3_logname='makeEBSVolumeAndMountOnLZ.log';
openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering makeEBSVolumeAndMountOnLZ.pl stdout=\"$stdout\".\n");

($master_pip, @slave_pip)=thor_nodes_ips();
printLog($cp2s3_logname,"In makeEBSVolumeAndMountOnLZ.pl. master_pip=\"$master_pip\"\n");

# List logical files with cluster name and sizes (this assumes logical files' metadata in $ThisDir/metadata)
printLog($cp2s3_logname, "\$_ = \`$ThisDir/listLogicalFilesWithClusterNamesAndSizes.pl\`\n");
$_ = `$ThisDir/listLogicalFilesWithClusterNamesAndSizes.pl`;
printLog($cp2s3_logname, "Output of listLogicalFilesWithClusterNamesAndSizes.pl is \"$_\".\n");

@lfile_and_info = split(/\n/, $_);
# Calculate total files size
$total_size = 0;
foreach (@lfile_and_info){
	my ($filename, $cluster, $size) = split(/,/,$_);
	$total_size += $size;
}
#convert total_size to GB
$total_gb_size = $total_size/(1024*1024*1024);
use POSIX;
$total_whole_gb_size   = ceil($total_gb_size);
$ebssize = 2*$total_whole_gb_size;
$az = `curl http://169.254.169.254/latest/meta-data/placement/availability-zone`;chomp $az;
printLog($cp2s3_logname, "total_size=\"$total_size\", total_gb_size=\"$total_gb_size\", total_whole_gb_size=\"$total_whole_gb_size\", ebssize=\"$ebssize\", az=\"$az\".\n");


printLog($cp2s3_logname, "\$volumeid = makeEBSVolume($ebssize, $az, $region)\n");
$volumeid = makeEBSVolume($ebssize, $az, $region, $stackname, 'despray');
printLog($cp2s3_logname, "volumeid=\"$volumeid\".\n");

# Save volume id in cfg_BestHPCC.sh, so remove ebs volume can get it
printLog($cp2s3_logname, "\$_ = \`sudo echo \"despray_volume=$volumeid\" >> $ThisDir/cfg_BestHPCC.sh\`\n");
$_ = `sudo echo "despray_volume=$volumeid" >> $ThisDir/cfg_BestHPCC.sh`;

$ThisInstanceId = `curl http://169.254.169.254/latest/meta-data/instance-id`;chomp $ThisInstanceId;
$dev = 'xvdz';
$mountdevice = "/dev/$dev";

printLog($cp2s3_logname, "\$_ = \`aws ec2 attach-volume --volume-id $volumeid --instance-id $ThisInstanceId --device $dev --region $region\`\n");
printLog($cp2s3_logname, "attachEBSVolume($volumeid, $ThisInstanceId, $dev, $region)\n");
attachEBSVolume($volumeid, $ThisInstanceId, $dev, $region);

printLog($cp2s3_logname, "\$_ = \`mkfs.ext4 $mountdevice\`\n");
$_ = `mkfs.ext4 $mountdevice`;

$lz = "/var/lib/HPCCSystems/mydropzone";

printLog($cp2s3_logname, "\$_ = \`mkdir $lz/$stackname; chown hpcc:hpcc $lz/$stackname; mount $mountdevice $lz/$stackname; mkdir $lz/$stackname/despray; chown hpcc:hpcc $lz/$stackname/despray\`\n");
$_ = `mkdir $lz/$stackname; chown hpcc:hpcc $lz/$stackname; mount $mountdevice $lz/$stackname; mkdir $lz/$stackname/despray; chown hpcc:hpcc $lz/$stackname/despray`;
printLog($cp2s3_logname, "Return from mounting ebs volume on LZ is \"$_\"\n");
