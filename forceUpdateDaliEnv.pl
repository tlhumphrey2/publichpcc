#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/common.pl";

print "Entering $0. On $ThisClusterComponent, whose IP is \"$ThisInstancePrivateIP\"\n";

$new_ip=shift @ARGV;
$nodetype=shift @ARGV;
$terminated_ip=shift @ARGV;
print "In $0. terminated_ip=\"$terminated_ip\", new_ip=\"$new_ip\" nodetype=\"$nodetype\"\n";
if ( "$nodetype" eq 'Slave' ){
 print "In $0: sed -i \"s/^$terminated_ip\\b/$new_ip/\" /var/lib/HPCCSystems/mythor/uslaves\n";
 $_=`sed -i "s/^$terminated_ip\\b/$new_ip/" /var/lib/HPCCSystems/mythor/uslaves 2>&1`;
 print "In $0. Content of /var/lib/HPCCSystems/mythor/uslaves is ",`cat /var/lib/HPCCSystems/mythor/uslaves`,"\n";
 system("/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init -c thor stop");
 system("/opt/HPCCSystems/bin/updtdalienv /etc/HPCCSystems/environment.xml -f");
 system("/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init -c thor start");
}
elsif ( "$nodetype" eq 'Roxie' ){
 system("/opt/HPCCSystems/bin/updtdalienv /etc/HPCCSystems/environment.xml -f");
 system("/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init restart");
}

sleep 5;
$EIP=getMasterEIP($region, $EIPAllocationId);
print "In $0 after calling getMasterEIP. EIP=\"$EIP\".\n";

$message=checkStatusOfCluster($stackname,$EIP);
AlertUserOfChangeInRunStatus($region, $email, $stackname, $message);
