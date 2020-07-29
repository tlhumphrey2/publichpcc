#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

$cp2s3_logname='outputMetadataFileForLogicalFile.log';
openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering outputMetadataFileForLogicalFile.pl.pl\n");

($master_pip, @slave_pip)=thor_nodes_ips();
printLog($cp2s3_logname,"In outputMetadataFileForLogicalFile.pl. master_pip=\"$master_pip\"\n");

#Check for files on this THOR
@FilesOnThor = FilesOnThor($master_pip);
printLog($cp2s3_logname, "\@FilesOnThor=(".join(", ",@FilesOnThor)."), MetadataFolder=\"$MetadataFolder\".\n");

#-------------------------------------------------------------------------------------------
# Put metadata for all files on mythor out to $s3bucket. Plus, copy files of LZ to $s3bucket.
#-------------------------------------------------------------------------------------------

if (scalar(@FilesOnThor) > 0 ){
# Make a folder for metadata files
  mkdir $MetadataFolder if ! -e $MetadataFolder;
  
  #For each of the above files, get and put its metadata in ~/metadata
  printLog($cp2s3_logname,"Get metadata file for: ".join("\nGet metadata file for: ",@FilesOnThor)."\n");
  foreach (@FilesOnThor){
     s/^\.:://;
     printLog($cp2s3_logname,"sudo $dfuplus server=$master_pip action=savexml srcname=$_ dstxml=$MetadataFolder/$_.xml\n");
     system("sudo $dfuplus server=$master_pip action=savexml srcname=$_ dstxml=$MetadataFolder/$_.xml");
  }
  printLog($cp2s3_logname,"Completed getting metadata for files.\n");
}
else{
   printLog($cp2s3_logname,"In outputMetadataFileForLogicalFile.pl. There are no files on the thor.\n");
}
