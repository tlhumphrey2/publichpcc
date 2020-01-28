#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
# Get instance ids from instance_ids.txt.
$all_instance_ids=`cat $ThisDir/instance_ids.txt`;
@instance_ids=split(/\n/,$all_instance_ids);
# Make a line for the ClusterInitVariables.pl file for additional instance ids
$additional_instances_line="\@additional_instances=('".join("','",@instance_ids)."');";
$additional_instances_line =~ s/ '/'/g;

$ContentsOfClusterInitFile=`cat $ThisDir/ClusterInitVariables.pl`;
@ContentsOfClusterInitFile=split(/\n/,$ContentsOfClusterInitFile); 

for( my $i=0; $i < scalar(@ContentsOfClusterInitFile); $i++){
  local $_=$ContentsOfClusterInitFile[$i];
  if ( /additional_instances/ ){
     $_=$additional_instances_line;
  }
  $ContentsOfClusterInitFile[$i]=$_;
}
$all_lines=join("\n", @ContentsOfClusterInitFile);

print "Outputting $ThisDir/ClusterInitVariables.pl\n";
open(OUT,">$ThisDir/ClusterInitVariables.pl") || die "Can't open for output: \"$ThisDir/ClusterInitVariables.pl\"\n";
print OUT "$all_lines\n";
close(OUT);
