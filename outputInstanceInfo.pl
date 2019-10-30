#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/getConfigurationFile.pl";

for ( my $i=0; $i < scalar(@InstanceId); $i++){
  print "$nodetype[$i]	$State[$i]	$InstanceId[$i]	$InstanceType[$i]	$PrivateIpAddress[$i]	$PublicIpAddress[$i]\n";
}
