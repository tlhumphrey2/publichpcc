#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

=pod
~/cpLogicalFilesOnClusterToS3.pl mhpcc-ca-central-1-8de-162 thor
=cut

openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering cpLogicalFilesOnClusterToS3.pl.\n");

$master_pip = master_ip();
printLog($cp2s3_logname,"In cpLogicalFilesOnClusterToS3.pl. master_pip=\"$master_pip\"\n");

#Check for files on this THOR
@FilesOnThor = FilesOnThor($master_pip);
printLog($cp2s3_logname, "\@FilesOnThor=(".join(", ",@FilesOnThor).").\n");
