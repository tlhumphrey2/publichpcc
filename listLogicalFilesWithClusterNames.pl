#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

$stdout = *STDOUT;
$cp2s3_logname='listLogicalFilesWithClusterName.log';
openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering listLogicalFilesWithClusterName.pl stdout=\"$stdout\".\n");

($master_pip, @slave_pip)=thor_nodes_ips();
printLog($cp2s3_logname,"In listLogicalFilesWithClusterName.pl. master_pip=\"$master_pip\"\n");

#Check for files on this THOR
@FilesOnCluster = FilesOnCluster($master_pip);
printLog($cp2s3_logname, "\@FilesOnCluster=(".join(", ",@FilesOnCluster)."), MetadataFolder=\"$MetadataFolder\".\n");

#-------------------------------------------------------------------------------------------

if (scalar(@FilesOnCluster) > 0 ){
# Make a folder for metadata files
  mkdir $MetadataFolder if ! -e $MetadataFolder;
  
  #For each of the above files, get and put its metadata in ~/metadata
  printLog($cp2s3_logname,"Get metadata file for: ".join("\nGet metadata file for: ",@FilesOnCluster)."\n");
  my @FilesAndClusters = ();
  foreach (@FilesOnCluster){
     s/^\.:://;
     my $xmlfile = "$MetadataFolder/$_.xml";
     printLog($cp2s3_logname,"sudo $dfuplus server=$master_pip action=savexml srcname=$_ dstxml=$xmlfile\n");
     system("sudo $dfuplus server=$master_pip action=savexml srcname=$_ dstxml=$xmlfile");
     push @FilesAndClusters, outputFilenameAndCluster($xmlfile);
  }
  printLog($cp2s3_logname,"Completed getting metadata for files. \@FilesAndClusters=(".join(", ",@FilesAndClusters).")\n");
  *STDOUT = $stdout;
  print join("\n",@FilesAndClusters),"\n";
}
else{
   printLog($cp2s3_logname,"In listLogicalFilesWithClusterName.pl. There are no files on the thor.\n");
}
#===================================================
sub outputFilenameAndCluster{
my ($xmlfile)=@_;
  my $filename = $1 if $xmlfile =~ /([^\/]+)\.xml$/;
  my $fac = '';
  local $_ = `egrep "group=" $xmlfile`;
  if ( /group="(\w+)"/ ){
      $fac = "$filename,$1";
  }
  printLog($cp2s3_logname,"Leaving outputFilenameAndCluster. xmlfile=\"$xmlfile\", filename=\"$filename\", fac=\"$fac\".\n");
return $fac;
}

