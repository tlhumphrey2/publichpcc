#!/usr/bin/perl
=pod

=cut
$ThisDir=($0 =~ /^(.+)[\\\/]/)? $1 : "." ;
require "$ThisDir/ClusterInitVariables.pl";
require "$ThisDir/formatDateTimeString.pl";

# NOTE: This scripts REQUIRES the aws cli be setup.

#================== Get Arguments ================================
if ( $ARGV[0] eq '-asgname' ){
  shift @ARGV;
  $in_asgname = shift @ARGV;
  print "DEBUG: GIVEN -asgname \"$in_asgname\"\n";
}
#===============END Get Arguments ================================

# Get json summary descriptions of all ASGs
$asgs_descriptions=`aws autoscaling describe-auto-scaling-instances --region $region 2> aws_errors.txt`;
print $asgs_descriptions;
