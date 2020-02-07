#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "/$ThisDir/common.pl";

$region = shift @ARGV;
$stackname = shift @ARGV;
$type = shift @ARGV;

@asgnames = getASGNames( $region, $stackname, $type );
print "\@asgnames=(",join(",",@asgnames),")\n";

