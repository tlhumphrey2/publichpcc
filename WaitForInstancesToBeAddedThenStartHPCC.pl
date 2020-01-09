#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
=pod
sudo ./WaitForInstancesToBeAddedThenStartHPCC.pl $stackname $region $pem &> ./WaitForInstancesToBeAddedThenStartHPCC.log
=cut

# This routine is executed on the master

$stackname = shift @ARGV;
$region = shift @ARGV;
$pem = shift @ARGV;

require "$ThisDir/cf_common.pl";
require "$ThisDir/common.pl";

# Wait 20 seconds before checking if hpcc platform installed
sleep(20);
#=============================================================================================
# After updating stack
@component = ('Slave', 'Roxie');
do{
   print "DEBUG: In WaitForInstancesToBeAddedThenStartHPCC.pl Waiting.\n";
   sleep(10);
   my @roxie_slave_ip = getComponentIPsByLaunchTime($stackname, $region, 'private', @component);
   print "DEBUG: In WaitForInstancesToBeAddedThenStartHPCC.pl \@roxie_slave_ip=(",join(", ",@roxie_slave_ip),").\n";
   my @InstallStatus = isHPCCInstalled($pem, @roxie_slave_ip);
   print "DEBUG: In WaitForInstancesToBeAddedThenStartHPCC.pl \@InstallStatus=(\"",join("\", \"",@InstallStatus),"\").\n";
   @installed = grep(! /^\s*$/, @InstallStatus);   
   $nip = scalar(@roxie_slave_ip);
   $ins = scalar(@installed);
} until( $nip == $ins );

print "sudo $ThisDir/MakeAndPushEnvThenStartHPCC.sh\n";
my $rc = `sudo $ThisDir/MakeAndPushEnvThenStartHPCC.sh 2>&1`;
print "DEBUG: In WaitForInstancesToBeAddedThenStartHPCC.pl rc=\"$rc\"\n";
#=============================================================================================
sub isHPCCInstalled{
my ($pem, @ip)=@_;
  my @InstallStatus = ();
  foreach my $ip (@ip){
    print "In isHPCCInstalled. ssh -o stricthostkeychecking=no -i $pem ec2-user\@$ip \"rpm -qa|egrep hpcc\"\n";
    my $rc = `ssh -o stricthostkeychecking=no -i $pem ec2-user\@$ip "rpm -qa|egrep hpcc"`; chomp $rc;
    print "In isHPCCInstalled. rc=\"$rc\"\n";
    push @InstallStatus, $rc;
  }
return @InstallStatus;
}
