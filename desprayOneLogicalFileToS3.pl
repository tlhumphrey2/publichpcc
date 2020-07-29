#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

# Ran ONLY on master (esp)

$thisDir = ( $0 =~ /^(.+)\// )? $1 : '.';

require "$thisDir/getConfigurationFile.pl";
require "$thisDir/cp2s3_common.pl";

=pod
~/desprayOneLogicalFileToS3.pl mhpcc-ca-central-1-8de-162 roxie::class::rt::intro::persons
=cut

$s3bucket = shift @ARGV; # Get s3 bucket name
$s3bucketpath = "/var/lib/HPCCSystems/mydropzone/$s3bucket";
$logicalfilename = shift @ARGV; # get logical file name 
$srccluster = shift @ARGV;

$stdout = *STDOUT;
$cp2s3_logname = 'desprayOneLogicalFileToS3.log';
openLog($cp2s3_logname);

printLog($cp2s3_logname,"Entering desprayOneLogicalFileToS3.pl s3bucketpath=\"$s3bucketpath\".\n");

$master_pip = master_ip();
printLog($cp2s3_logname,"In desprayOneLogicalFileToS3.pl. master_pip=\"$master_pip\"\n");
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
$_ = $logicalfilename;
s/^\.:://;
my $filename = $_;
$filename =~ s/::/\//g;
my $dstfile = "$s3bucketpath/despray/$filename";
my $ecl = $despray_template;
$ecl =~ s/<logicalfilename>/$_/;
$ecl =~ s/<dstip>/$master_pip/;
$ecl =~ s/<dstfile>/$dstfile/;
my $eclfile = putInFile($ecl,"ecl_$_.txt");
my $cluster = ($srccluster =~ /thor/)? 'thor' : 'roxie';

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
