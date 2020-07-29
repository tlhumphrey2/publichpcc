#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

=pod
sudo $ThisDir/dismountDetachAndDeleteDesprayEBSVolume.pl
=cut

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";
require "$thisDir/common.pl";

$stdout = *STDOUT;
$cp2s3_logname='dismountDetachAndDeleteDesprayEBSVolume.log';
openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering dismountDetachAndDeleteDesprayEBSVolume.pl stdout=\"$stdout\".\n");

($master_pip, @slave_pip)=thor_nodes_ips();
printLog($cp2s3_logname,"In dismountDetachAndDeleteDesprayEBSVolume.pl. master_pip=\"$master_pip\"\n");

# 1. umount ebs volume
printLog($cp2s3_logname,"\$_ = \`sudo umount /dev/xdvz\`\n");
$_ = `sudo umount /dev/xvdz 2>&1`;
printLog($cp2s3_logname,"Return from umount is \"$_\"\n");
sleep(3);
# 2. remove directory /var/lib/HPCCSystems/mydropzone/$stackname
printLog($cp2s3_logname,"\$_ = \`rm -vr /var/lib/HPCCSystems/mydropzone/$stackname\`\n");
$_ = `rm -vr /var/lib/HPCCSystems/mydropzone/$stackname 2>&1`;
printLog($cp2s3_logname,"Return from remove $stackname from LZ is \"$_\"\n");
# 3. get volumeid from cfg_BestHPCC.sh
printLog($cp2s3_logname,"\$volumeid = \`egrep \"^despray_volume=\" $ThisDir/cfg_BestHPCC.sh|tail -1|sed \"s/^despray_volume=//\"\`; chomp $volumeid\n");
$volumeid = `egrep "^despray_volume=" $ThisDir/cfg_BestHPCC.sh|tail -1|sed "s/^despray_volume=//"`; chomp $volumeid;
printLog($cp2s3_logname,"volumeid=\"$volumeid\"\n");
# 4. detach ebs volume
printLog($cp2s3_logname,"\$_ = detachEBSVolume($volumeid,$region)\n");
$_ = detachEBSVolume($volumeid,$region);
printLog($cp2s3_logname,"Return from detach-volume is \"$_\"\n");
# 5. delete ebs volume
printLog($cp2s3_logname,"\$_ = \`aws ec2 delete-volume --volume-id $volumeid --region $region\`\n");
$_ = `aws ec2 delete-volume --volume-id $volumeid --region $region 2>&1`;
printLog($cp2s3_logname,"Return from delete-volume is \"$_\"\n");
printLog($cp2s3_logname,"\$_ = \`rm -vr $MetadataFolder\`\n");
$_ = `rm -vr $MetadataFolder 2>&1`;
printLog($cp2s3_logname,"Return from rm -vr $MetadataFolder is \"$_\"\n");
