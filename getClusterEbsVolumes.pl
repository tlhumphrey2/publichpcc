#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
require "$ThisDir/cf_common.pl";
=pod
getClusterEbsVolumes.pl us-east-2 mhpcc-us-east-2-55 10.0.0.44 10.0.0.250
getClusterEbsVolumes.pl eu-west-1 mhpcc-eu-west-1-40 10.0.0.237 10.0.0.54
getClusterEbsVolumes.pl us-east-2 yuting-oxford-university-hpcc-cluster-5 10.0.0.145 10.0.0.37 &> yuting-cluster-instance-ids.log
getClusterEbsVolumes.pl $region $stackname 10.0.0.102 10.0.0.130 &> cluster-instance-ids.log

HERE IS WHAT IS OUTPUT:
InstanceId State LaunchTime InstanceType PublicIp PrivateIp InstanceName slavesPerNode roxienodes HPCCPlatform pem {VolumeId:DeviceName}+
i-05bf898259c1d0611 running 2019-11-15T14:55:18.000Z 3.134.117.31 t2.micro 10.0.0.102 test-add-drop-cluster-instances-3--Bastion None None None None vol-083fe4625bfcfed89:/dev/xvda

i-034c5f3629334f88f running 2019-11-15T14:58:23.000Z 18.222.152.193 r4.large 10.0.0.130 test-add-drop-cluster-instances-3--Slave test-add-drop-cluster-instances-3 1 2 HPCC-Platform-7.6.8-1 vol-061b3a8d8c7e23a4e:/dev/xvda vol-0212b5acdf3da4f2e:xvdb

i-0c6d3b1cbf4093821 running 2019-11-15T15:03:37.000Z 13.59.228.158 r4.large 10.0.0.211 test-add-drop-cluster-instances-3--Master test-add-drop-cluster-instances-3 1 2 HPCC-Platform-7.6.8-1 vol-01b74b34c7131b534:/dev/xvda vol-05a44491f8875ee33:xvdb

i-05fec77d7f23bdfcb running 2019-11-15T17:30:25.000Z 3.134.80.109 r4.large 10.0.0.203 test-add-drop-cluster-instances-3--Roxie test-add-drop-cluster-instances-3 1 2 HPCC-Platform-7.6.8-1 vol-08e5aadcc3c45b0a4:/dev/xvda vol-0f30a4d094860caff:xvdb

=cut

$region = shift @ARGV;
$stackname = shift @ARGV;
@private_ip = ();
while(scalar(@ARGV) > 0){
  push @private_ip, shift @ARGV;
}
#print "DEBUG: Entering getClusterEbsVolumes.pl region=\"$region\", stackname=\"$stackname\", \@private_ip=(",join(",",@private_ip),")\n";

$DesiredInfo[0]='PrivateIp';
$DesiredInfo[1]='VolumeIds';

@DesiredInfo = getClusterInstanceInfo ($region, $stackname, @DesiredInfo);
#print join("\n",@InstanceInfo),"\n";

$re = '\b(?:'. join("|", @private_ip) . ')\b';
$re =~ s/\./\\\./g;
#print "DEBUG: re=\"$re\"\n";

@DesiredInfo = grep(s/^\s*$re\s+//, @DesiredInfo);
print join("\n",@DesiredInfo),"\n";

