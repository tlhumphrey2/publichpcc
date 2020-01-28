#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
=pod
exe_orderEnvProcessLinesByLaunchTime.pl $stackname $region 'Slave' $env &> exe_orderEnvProcessLinesByLaunchTime.log
=cut
require "$ThisDir/common.pl";
$envfile = shift @ARGV;
$stackname = shift @ARGV;
$region = shift @ARGV;
$nodetype = shift @ARGV;

orderEnvProcessLinesByLaunchTime( $envfile, $stackname, $region, 'Slave');
orderEnvProcessLinesByLaunchTime( $envfile, $stackname, $region, 'Roxie');
