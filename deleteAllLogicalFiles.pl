#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

=pod
~/deleteAllLogicalFiles.pl
=cut

$cp2s3_logname = 'deleteAllLogicalFiles.log';
openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering deleteAllLogicalFiles.pl.\n");

$master_pip = master_ip();
printLog($cp2s3_logname,"In deleteAllLogicalFiles.pl. master_pip=\"$master_pip\"\n");

#Check for files on this THOR
@FilesOnThor = FilesOnThor($master_pip);
printLog($cp2s3_logname, "\@FilesOnThor=(".join(", ",@FilesOnThor).").\n");
#-------------------------------------------------------------------------------------------
#
printLog($cp2s3_logname, "Delete logical files.\n");
if (scalar(@FilesOnThor) > 0 ){
# Make a folder for metadata files
  mkdir $MetadataFolder if ! -e $MetadataFolder;
  
  #For each of the above files, get and put its metadata in ~/metadata
  printLog($cp2s3_logname,"Get metadata file for: ".join("\nGet metadata file for: ",@FilesOnThor)."\n");
  foreach (@FilesOnThor){
     s/^\.:://;
     printLog($cp2s3_logname,"sudo $dfuplus user=tlhumphrey2 password=hpccdemo server=$master_pip action=remove name=$_\n");
     $_ = `sudo $dfuplus user=tlhumphrey2 password=hpccdemo server=$master_pip action=remove name=$_`;
     printLog($cp2s3_logname,"Return from $dfuplus is \"$_\".\n");
  }
  printLog($cp2s3_logname,"Completed getting metadata for files.\n");
}
else{
   printLog($cp2s3_logname,"In deleteAllLogicalFiles.pl. There are no files on the thor.\n");
}
#=============================================
sub putInFile{
my ($ecl, $outfile)=@_;
open(OUT,">$outfile") || die "Can't open for output: \"$outfile\"\n";
print OUT $ecl;
close(OUT);
return $outfile;
}
