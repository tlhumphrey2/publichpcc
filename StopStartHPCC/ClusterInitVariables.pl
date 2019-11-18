$sshuser="ec2-user";
#$no_hpcc=1;
#$EBSVolumesMountedByFstab=1;                       #If this is set then mounting DOES NOT happen in startHPCCOnAllInstances.pl
#$ephemeral=1;
$region="us-west-2";                               #Region where this cluster exists
$stackname="another-test";#Name of cloudformation stack that started this hpcc
$name=($stackname !~ /^\s*$/)? $stackname : "test-python3-20171110-2";
$master_name="$name--Master";
$other_name="$name--Slave,$name--Roxie";
$pem="tlh_keys_us_west_2.pem";         #Private ssh key
$private_ipse="private_ips.txt";          #File where all hpcc instances private IPs are stored (used by startHPCCOnAllInstances.pl)
$instance_id="instance_ids.txt";
$mountpoint=($no_hpcc)? "/home/$sshuser/data" : "/var/lib/HPCCSystems"; # IF HPCC
1;
