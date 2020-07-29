#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

=pod
~/sprayFromS3Bucket.pl mhpcc-ca-central-1-8de-162
=cut

$s3bucket = shift @ARGV; # Get s3 bucket name
$s3bucketpath = "/var/lib/HPCCSystems/mydropzone/$s3bucket";

openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering sprayFromS3Bucket.pl s3bucketpath=\"$s3bucketpath\".\n");

#if ( ! -e $s3bucketpath ){
# printLog($cp2s3_logname,"sudo mkdir $s3bucketpath;sudo chown hpcc:hpcc $s3bucketpath\n");
# system("sudo mkdir $s3bucketpath;sudo chown hpcc:hpcc $s3bucketpath");
#}

$master_pip = master_ip();
printLog($cp2s3_logname,"In sprayFromS3Bucket.pl. master_pip=\"$master_pip\"\n");

#Check for files on this THOR
@FilesOnThor = FilesOnThor($master_pip);
printLog($cp2s3_logname, "\@FilesOnThor=(".join(", ",@FilesOnThor).").\n");

@FilesOnThor = getLogicalFileNames();
printLog($cp2s3_logname, "\@FilesOnThor=(".join(", ",@FilesOnThor).").\n");
#-------------------------------------------------------------------------------------------
#
# Despray logical files to $s3bucket.
printLog($cp2s3_logname, "Despray logical files to $s3bucket\n");
if (scalar(@FilesOnThor) > 0 ){
  #For each of the above files, get and put its metadata in ~/metadata
  foreach (@FilesOnThor){
     s/^\.:://;
     my $xmlfile = "$MetadataFolder/$_";
     if ( -e $xmlfile ){
       my $format = getFormat($xmlfile);
       my $filename = $_;
       $filename =~ s/\.xml$//;
       my $dstname = $filename;
       $filename =~ s/::/\//g;
       my $srcfile = "$s3bucketpath/despray/$filename";
       printLog($cp2s3_logname,"sudo $dfuplus server=$master_pip user=tlhumphrey2 password=hpccdemo action=spray srcip=$master_pip srcfile=$srcfile dstname=$dstname $format\n");
       $_ = `sudo $dfuplus server=$master_pip user=tlhumphrey2 password=hpccdemo action=spray srcip=$master_pip srcfile=$srcfile dstname=$dstname $format`;
       printLog($cp2s3_logname,"Return from $dfuplus is \"$_\".\n");
     }
     else{
     }
  }
  printLog($cp2s3_logname,"Completed spraying files.\n");
}
else{
   printLog($cp2s3_logname,"In sprayFromS3Bucket.pl. There are no files on the thor.\n");
}
#=============================================
sub getFormat{
my ($xmlfile)=@_;
  my $fmat='';
  local $_ = `egrep "recordSize=" $xmlfile`;
  if ( /recordSize="(\d+)"/ ){
      $fmat = "dstcluster=mythor format=fixed recordsize=$1";
  }
  else{
      $fmat = "dstcluster=mythor format=csv";
  }
return $fmat;
}
#---------------------------------------------
sub getLogicalFileNames{
  $_ = `ls -1 $MetadataFolder`; chomp $_;
  @LogicalFileNames = split(/\n/,$_);
return @LogicalFileNames;
}
