#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;

require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/cf_common.pl";
require "$ThisDir/common.pl";

#==============================================================================
# If this instance is NOT the master and an instance has terminated then
#  add terminated_ip and ThisInstancePrivateIP to cfg_BestHPCC.sh
#==============================================================================
my @terminated=grep(/terminate/,@State);
print "DEBUG: In saveIPOfTerminated.pl. ThisClusterComponent=\"$ThisClusterComponent\", Size of \@terminated=",scalar(@terminated),"\n";
if ( ($ThisClusterComponent ne 'Master') && (scalar(@terminated)>0) ){
  my $terminated_ip=getTerminatedIP();

  $cfgfile="$ThisDir/cfg_BestHPCC.sh";
  open(OUT,">>$cfgfile") || die "Can't open for append: \"$cfgfile\"\n";
  print OUT "terminated_ip=$terminated_ip\n";
  close(OUT);
}
