
$pem="/home/ec2-user/mhpcc-eu-west-1-68.pem";                         #Private ssh key file name
$sshuser="ec2-user";                 #login userid
$region="eu-west-1";                   #Region where this cluster exists
$stackname="mhpcc-eu-west-1-68";             #Name of cloudformation stack that started this hpcc
$name=($stackname !~ /^\s*$/)? $stackname : "NO_NAME_GIVEN";
$master_name="$name--Master";
$other_name="$name--Slave,$name--Roxie";
$instance_ids="/home/ec2-user/StopStartHPCC/instance_ids.txt";
$private_ips="/home/ec2-user/StopStartHPCC/private_ips.txt";  #File where all hpcc instances private IPs are stored (used by startHPCCOnAllInstances.pl)
$public_ips="/home/ec2-user/StopStartHPCC/public_ips.txt";
$nodetypes="/home/ec2-user/StopStartHPCC/nodetypes.txt";
$mountpoint=($no_hpcc)? "/home/ec2-user/data" : "/var/lib/HPCCSystems"; # IF HPCC
require "/home/ec2-user/cf_common.pl";
require "/home/ec2-user/common.pl";

# Refill cluster info files, i.e. public_ips.txt, private_ips.txt, instance_ids.txt, and nodetypes.txt
my @sorted_InstanceInfo=InstanceVariablesFromInstanceDescriptions("eu-west-1","mhpcc-eu-west-1-68");
@Filenames = ($instance_ids, $private_ips, $public_ips, $nodetypes);
my @tmp = putHPCCInstanceInfoInFiles(\@sorted_InstanceInfo,@Filenames);
1;
