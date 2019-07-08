#!/usr/bin/perl

$ThisDir=($0=~/^(.*)\//)? $1 : ".";

require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/common.pl";

my $stackname=shift @ARGV;
my $region=shift @ARGV;
my $sshuser=shift @ARGV;

my $pem = "$ThisDir/$stackname.pem";
my $pemfile;
($pemfile=$pem) =~ s/^.*\///;
print "chmod 400 $pem\n";
$_=`chmod 400 $pem`;
print "rc of chmod 400 $pem is \"$_\"\n";

local $instance_ids="$ThisDir/instance_ids.txt";
local $private_ips="$ThisDir/private_ips.txt";
local $has_private_ips="$ThisDir/has_private_ips.txt";
local $public_ips="$ThisDir/public_ips.txt";
local $nodetypes="$ThisDir/nodetypes.txt";

my @sorted_InstanceInfo=InstanceVariablesFromInstanceDescriptions($region,$stackname);
putHPCCInstanceInfoInFiles(\@sorted_InstanceInfo) if scalar(@sorted_InstanceInfo)>0;
my @nodetypes=(scalar(@sorted_InstanceInfo)==0)? () : split(/\n/,`cat $nodetypes`); @nodetypes=grep(!/^\s*$/,@nodetypes); 
print "Size of \@nodetypes is ",scalar(@nodetypes),"\n";

if (scalar(@nodetypes)==0){
  print "NO HPCC INSTANCES. So exiting.\n";
  exit;
}

if ( -e $has_private_ips ){
 @has_private_ips=split(/\n/,`cat $has_private_ips`); @has_private_ips=grep(!/^\s*$/,@has_private_ips); 
 foreach my $ip (@has_private_ips){
   $HasPemFile{$ip}=1;
 }
}

my @private_ips=split(/\n/,`cat $private_ips`); @private_ips=grep(!/^\s*$/,@private_ips); 
foreach my $ip (@private_ips){
  next if $HasPemFile{$ip};

  print "scp -i $pem $sshuser\@$ip:/home/$sshuser/$pemfile\n";
  my $rc=`scp -i $pem $sshuser\@$ip:/home/$sshuser/$pemfile`;
  print "rc of scp is \"$rc\"\n";
  print "ssh -i $pem $sshuser\@$ip \"chmod 400 /home/ec2-use/$pemfile\"\n";
  my $rc=`ssh -i $pem $sshuser\@$ip "chmod 400 /home/ec2-use/$pemfile"`;
  print "rc of ssh is \"$rc\"\n";
  my $rc=`echo $ip >> $has_private_ips`;
  print "rc of \"echo $ip \>\> $has_private_ips\" is \"$rc\"\n";
}
