#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

=pod
~/deleteOnelLogicalFile.pl roxie::class::rt::intro::persons
=cut

$cp2s3_logname = 'deleteOnelLogicalFile.log';
openLog($cp2s3_logname);

$logicalfilename = shift @ARGV;

printLog($cp2s3_logname,"Entering deleteOnelLogicalFile.pl. logicalfilename=\"$logicalfilename\".\n");

$master_pip = master_ip();
printLog($cp2s3_logname,"In deleteOnelLogicalFile.pl. master_pip=\"$master_pip\"\n");
#-------------------------------------------------------------------------------------------
#
printLog($cp2s3_logname, "Delete logical files.\n");
$_ = $logicalfilename;
s/^\.:://;
printLog($cp2s3_logname,"sudo $dfuplus user=tlhumphrey2 password=hpccdemo server=$master_pip action=remove name=$_\n");
$_ = `sudo $dfuplus user=tlhumphrey2 password=hpccdemo server=$master_pip action=remove name=$_`;
printLog($cp2s3_logname,"Return from $dfuplus is \"$_\".\n");
