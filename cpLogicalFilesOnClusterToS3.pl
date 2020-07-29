#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

=pod
~/cpLogicalFilesOnClusterToS3.pl mhpcc-ca-central-1-8de-162 thor
=cut

$s3bucket = shift @ARGV; # Get s3 bucket name
$s3bucketpath = "/var/lib/HPCCSystems/mydropzone/$s3bucket";
$cluster = shift @ARGV; # get cluster name

openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering cpLogicalFilesOnClusterToS3.pl s3bucketpath=\"$s3bucketpath\".\n");

#if ( ! -e $s3bucketpath ){
# printLog($cp2s3_logname,"sudo mkdir $s3bucketpath;sudo chown hpcc:hpcc $s3bucketpath\n");
# system("sudo mkdir $s3bucketpath;sudo chown hpcc:hpcc $s3bucketpath");
#}

$master_pip = master_ip();
printLog($cp2s3_logname,"In cpLogicalFilesOnClusterToS3.pl. master_pip=\"$master_pip\"\n");

#Check for files on this THOR
@FilesOnThor = FilesOnThor($master_pip);
printLog($cp2s3_logname, "\@FilesOnThor=(".join(", ",@FilesOnThor).").\n");

@FilesOnThor = FilesOnThor($master_pip);
printLog($cp2s3_logname, "\@FilesOnThor=(".join(", ",@FilesOnThor).").\n");
#-------------------------------------------------------------------------------------------
#
# Despray logical files to $s3bucket.
$despray_template = <<EOFF;
IMPORT STD;
LandingZoneIP:='<dstip>';
logicalname:='~<logicalfilename>';
LZ_filename:='<dstfile>';
STD.File.DeSpray( logicalname ,LandingZoneIP ,LZ_filename ,-1,,,TRUE);
EOFF
$eclplus = '/opt/HPCCSystems/bin/eclplus';
printLog($cp2s3_logname, "Despray logical files to $s3bucket\n");
if (scalar(@FilesOnThor) > 0 ){
# Make a folder for metadata files
  mkdir $MetadataFolder if ! -e $MetadataFolder;
  
  #For each of the above files, get and put its metadata in ~/metadata
  printLog($cp2s3_logname,"Get metadata file for: ".join("\nGet metadata file for: ",@FilesOnThor)."\n");
  foreach (@FilesOnThor){
     s/^\.:://;
     my $filename = $_;
     $filename =~ s/::/\//g;
     my $dstfile = "$s3bucketpath/despray/$filename";
     my $ecl = $despray_template;
     $ecl =~ s/<logicalfilename>/$_/;
     $ecl =~ s/<dstip>/$master_pip/;
     $ecl =~ s/<dstfile>/$dstfile/;
     my $eclfile = putInFile($ecl,"ecl_$_.txt");
     #
     #printLog($cp2s3_logname,"sudo $dfuplus server=$master_pip action=despray dstip=$master_pip dstfile=$dstfile srcname=$_\n");
     #system("sudo $dfuplus server=$master_pip action=despray dstip=$master_pip dstfile=$dstfile srcname=$_");

     printLog($cp2s3_logname,"sudo $eclplus user=tlhumphrey2 password=hpccdemo server=$master_pip cluster=thor \@$eclfile\n");
     $_ = `sudo $eclplus user=tlhumphrey2 password=hpccdemo server=$master_pip cluster=thor \@$eclfile`;
     printLog($cp2s3_logname,"Return from $eclplus is \"$_\".\n");
  }
  printLog($cp2s3_logname,"Completed getting metadata for files.\n");
}
else{
   printLog($cp2s3_logname,"In cpLogicalFilesOnClusterToS3.pl. There are no files on the thor.\n");
}
#=============================================
sub putInFile{
my ($ecl, $outfile)=@_;
open(OUT,">$outfile") || die "Can't open for output: \"$outfile\"\n";
print OUT $ecl;
close(OUT);
return $outfile;
}
