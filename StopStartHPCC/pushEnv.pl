#!/usr/bin/perl
=pod
=cut

$ThisDir=($0 =~ /^(.+)[\\\/]/)? $1 : "." ;
require "$ThisDir/ClusterInitVariables.pl";
require "$ThisDir/formatDateTimeString.pl";
print "DEBUG: ThisDir=\"$ThisDir\"\n";

if ( $ARGV[0] !~ /^\s*$/ ){
$envfile=shift @ARGV;
}
else{
die "FATAL USAGE ERROR: $0. MUST HAVE ONE command line argument -- a environment.xml file.\n";
}

$ip=`head -1 $private_ips`; chomp $ip;

#------------------------------------------------------------
# Stop cluster
#------------------------------------------------------------
print("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init stop\"\n");
system("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init stop\"");

sleep(5); # wait 5 seconds before changing environment.xml file (this is a precaution ONLY)

#------------------------------------------------------------
# Push inputted environment.xml file to all cluster instances
#------------------------------------------------------------
# Put $envfile on master
print("scp -i $pem $envfile $sshuser\@$ip:/home/$sshuser/$envfile\n");
system("scp -i $pem $envfile $sshuser\@$ip:/home/$sshuser/$envfile");

# Push $envfile to all cluster instances
print("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo /opt/HPCCSystems/sbin/hpcc-push.sh -s /home/$sshuser/$envfile -t /etc/HPCCSystems/environment.xml\"\n");
system("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo /opt/HPCCSystems/sbin/hpcc-push.sh -s /home/$sshuser/$envfile -t /etc/HPCCSystems/environment.xml\"");

#------------------------------------------------------------
# Start cluster
#------------------------------------------------------------
print("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start\"\n");
system("ssh -o StrictHostKeyChecking=no -t -t -i $pem $sshuser\@$ip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init start\"");
