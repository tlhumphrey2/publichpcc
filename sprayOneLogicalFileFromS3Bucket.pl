#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

=pod
~/sprayOneLogicalFileFromS3Bucket.pl mhpcc-ca-central-1-8de-162 roxie::class::rt::intro::persons myroxie
=cut

$s3bucket = shift @ARGV; # Get s3 bucket name
$s3bucketpath = "/var/lib/HPCCSystems/mydropzone/$s3bucket";
$logicalfilename = shift @ARGV;
$dstcluster = shift @ARGV;

$stdout = *STDOUT;
$cp2s3_logname = 'sprayOneLogicalFileFromS3Bucket.log';
openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering sprayOneLogicalFileFromS3Bucket.pl s3bucketpath=\"$s3bucketpath\".\n");

$master_pip = master_ip();
printLog($cp2s3_logname,"In sprayOneLogicalFileFromS3Bucket.pl. master_pip=\"$master_pip\"\n");
#-------------------------------------------------------------------------------------------
#
# Despray logical files to $s3bucket.
printLog($cp2s3_logname, "Despray logical files to $s3bucket\n");
$_ = $logicalfilename;
s/^\.:://;
my $xmlfile = "$MetadataFolder/$_.xml";
if ( -e $xmlfile ){
  my $format = getFormat($xmlfile);
  my $filename = $_;
  $filename =~ s/\.xml$//;
  my $dstname = $filename;
  $filename =~ s/::/\//g;
  my $srcfile = "$s3bucketpath/despray/$filename";
  printLog($cp2s3_logname,"sudo $dfuplus server=$master_pip user=tlhumphrey2 password=hpccdemo action=spray dstcluster=$dstcluster srcip=$master_pip srcfile=$srcfile dstname=$dstname $format\n");
  $_ = `sudo $dfuplus server=$master_pip user=tlhumphrey2 password=hpccdemo action=spray dstcluster=$dstcluster srcip=$master_pip srcfile=$srcfile dstname=$dstname $format`;
  printLog($cp2s3_logname,"Return from $dfuplus is \"$_\".\n");
}
else{
  *STDOUT = $stdout;
  print "ERROR. Metadata xml file does NOT exists: \"$xmlfile\".\n";
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
