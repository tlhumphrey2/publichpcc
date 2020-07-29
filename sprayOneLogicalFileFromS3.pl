#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

=pod
~/sprayOneLogicalFileFromS3.pl mhpcc-ca-central-1-8de-162 roxie::class::rt::intro::persons myroxie
~/sprayOneLogicalFileFromS3.pl mhpcc-ca-central-1-8de-162 class::rt::intro::persons mythor
=cut

$s3bucket = shift @ARGV; # Get s3 bucket name
$s3bucketpath = "/var/lib/HPCCSystems/mydropzone/$s3bucket";
$logicalfilename = shift @ARGV; # get logical file name 
$dstcluster = shift @ARGV;

$stdout = *STDOUT;
$cp2s3_logname = 'sprayOneLogicalFileFromS3.log';
openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering sprayOneLogicalFileFromS3.pl s3bucketpath=\"$s3bucketpath\".\n");

$master_pip = master_ip();
printLog($cp2s3_logname,"In sprayOneLogicalFileFromS3.pl. master_pip=\"$master_pip\"\n");
#-------------------------------------------------------------------------------------------
#
# Spray logical files from $s3bucket.
$spray_fixed_template = <<EOFF;
IMPORT STD;
rec_size := <rec_size>;
LandingZoneIP:='<lzip>';
Path2LZFile:='<srcfile>';
FileOnLogicalName:='~<logicalfilename>';
spray2component:='<dstcluster>';
STD.File.SprayFixed(
                    LandingZoneIP
                    ,Path2LZFile
                    ,rec_size
                    ,spray2component
                    ,FileOnLogicalName
		    ,,,,TRUE
);
EOFF
$spray_variable_template = <<EOFF2;
IMPORT STD;
LandingZoneIP:='<lzip>';
Path2LZFile:='<srcfile>';
FileOnLogicalName:='~<logicalfilename>';
spray2component:='<dstcluster>';
STD.File.SprayVariable(
                           LandingZoneIP
                           ,Path2LZFile
                           ,21000
                           ,','
                           ,'\\n'
                           ,''
                           ,spray2component
                           ,FileOnLogicalName
                           ,-1
                           ,
                           ,
                           ,true
);
EOFF2
$eclplus = '/opt/HPCCSystems/bin/eclplus';
printLog($cp2s3_logname, "Spray logical files from $s3bucket\n");
$_ = $logicalfilename;
s/^\.:://;
my $xmlfile = "$MetadataFolder/$_.xml";
my $rec_size = getRecordSize($xmlfile);
my $filename = $_;
$filename =~ s/::/\//g;
my $srcfile = "$s3bucketpath/despray/$filename";
my $ecl = ($rec_size =~ /^\s*$/)? $spray_variable_template : $spray_fixed_template;
$ecl =~ s/<logicalfilename>/$logicalfilename/;
$ecl =~ s/<lzip>/$master_pip/;
$ecl =~ s/<srcfile>/$srcfile/;
$ecl =~ s/<dstcluster>/$dstcluster/;
$ecl =~ s/<rec_size>/$rec_size/;
my $eclfile = putInFile($ecl,"ecl_$_.txt");
my $cluster = ($dstcluster =~ /thor/)? 'thor' : 'roxie';

printLog($cp2s3_logname,"sudo $eclplus user=tlhumphrey2 password=hpccdemo server=$master_pip cluster=$cluster \@$eclfile\n");
$_ = `sudo $eclplus user=tlhumphrey2 password=hpccdemo server=$master_pip cluster=$cluster \@$eclfile`;
printLog($cp2s3_logname,"Return from $eclplus is \"$_\".\n");
closeLog($cp2s3_logname);
$_ = `cat $cp2s3_logname|egrep -i "error|invalid"`;
print $stdout "$_\n";
#=============================================
sub putInFile{
my ($ecl, $outfile)=@_;
open(OUT,">$outfile") || die "Can't open for output: \"$outfile\"\n";
print OUT $ecl;
close(OUT);
return $outfile;
}
#=============================================
sub getRecordSize{
my ($xmlfile)=@_;
  my $recsize='';
  local $_ = `egrep "recordSize=" $xmlfile`;
  if ( /recordSize="(\d+)"/ ){
      $recsize = $1;
  }
return $recsize;
}
