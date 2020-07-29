#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
$outfile = "$ThisDir/ClusterInitVariables.pl";
if ( scalar(@ARGV) > 0 ){
  $path = shift @ARGV;
  $filter = (scalar(@ARGV) > 0)? shift @ARGV : '';
  $ClusterInfoFilesExist = (scalar(@ARGV)>0)? 1: 0;
  goto "PRINTCLUSTERINFOFILECONTENTS" if $ClusterInfoFilesExist ne "";
  $_ = `cat $ThisDir/ClusterInitVariables.pl`;
  $re = '(instance_ids|private_ips|public_ips|nodetypes)="[^\n]*\/?((?:instance_ids|private_ips|public_ips|nodetypes)\.txt)"';
  s/$re/$1="$path\/$2"/gs;
  $outfile = "$ThisDir/tmpClusterInitVariables.pl";
  open(OUT,">$outfile") || die "Can't open for output: \"$outfile\"";
  print OUT $_;
  close(OUT);
}
PRINTCLUSTERINFOFILECONTENTS:
require "$outfile";
print "$region $stackname\n";
`echo "DEBUG: instance_ids=\"$instance_ids\", nodetypes=\"$nodetypes\", private_ips=\"$private_ips\", public_ips=\"$public_ips\"" > $ThisDir/debug-output-of-setupClusterInfoFiles.log`;
$_ = `paste $instance_ids $nodetypes $private_ips $public_ips|egrep "$filter"`;
print "$_\n";
