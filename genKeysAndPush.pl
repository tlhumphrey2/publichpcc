#!/usr/bin/perl
# sudo perl genKeysAndPush.pl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";

require "$ThisDir/getConfigurationFile.pl";

require "$ThisDir/cp2s3_common.pl";
$ThisNodesPrivateIP=get_this_nodes_private_ip();

# Gen ssh keys and have them placed in /home/hpcc/.ssh with owner=hpcc and correct permissions
# NOTE. Need to use ssh to do this since keygen.sh contains sudo and therefore tty is needed.
print("ssh -o StrictHostKeyChecking=no -t -t -i $pem ec2-user\@$ThisNodesPrivateIP \"sudo bash $ThisDir/mygenKeys.sh\"\n");
system("ssh -o StrictHostKeyChecking=no -t -t -i $pem ec2-user\@$ThisNodesPrivateIP \"sudo bash $ThisDir/mygenKeys.sh\"");

print("bash $ThisDir/cpKeys2MyHome.sh\n");
system("bash $ThisDir/cpKeys2MyHome.sh");

# Get all private_ips
open(IN,$private_ips) || die "Can't open for input: \"$private_ips\"\n";
while(<IN>){
   next if /^\s*$/;
   chomp;
   $esp = $_ if $. == 1;
   push @private_ips, $_;
}
close(IN);

print("chmod 400 $pem\n");
system("chmod 400 $pem");

#Start HPCC on all instances.
for( my $i=$#private_ips; $i >= 0; $i--){
  my $ip=$private_ips[$i];
  if ( $ThisNodesPrivateIP ne $ip ){
    print("bash $ThisDir/cpKeys2Instance.sh $ip $pem\n");
    system("bash $ThisDir/cpKeys2Instance.sh $ip $pem");
  }
}
