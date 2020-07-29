#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
=pod
USAGE EXAMPLE:
makeClusterInitVariables.pl $sshuser $region $stackname
=cut

# Below are commandline arguments in order they appear on line
$sshuser = shift @ARGV;
$region = shift @ARGV;
$stackname = shift @ARGV;

$home = "/home/$sshuser";
$pem = "$home/$stackname.pem";

$template_ClusterInitVariables=<<EOFF1;

\$pem="$pem";                         #Private ssh key file name
\$sshuser="$sshuser";                 #login userid
\$region="$region";                   #Region where this cluster exists
\$stackname="$stackname";             #Name of cloudformation stack that started this hpcc
\$name=(\$stackname !~ /^\\s*\$/)? \$stackname : "NO_NAME_GIVEN";
\$master_name="\$name--Master";
\$other_name="\$name--Slave,\$name--Roxie";
\$instance_ids="$ThisDir/instance_ids.txt";
\$private_ips="$ThisDir/private_ips.txt";  #File where all hpcc instances private IPs are stored (used by startHPCCOnAllInstances.pl)
\$public_ips="$ThisDir/public_ips.txt";
\$nodetypes="$ThisDir/nodetypes.txt";
\$mountpoint=(\$no_hpcc)? "/home/$sshuser/data" : "/var/lib/HPCCSystems"; # IF HPCC
require "$home/cf_common.pl";
require "$home/common.pl";

my \@sorted_InstanceInfo=InstanceVariablesFromInstanceDescriptions("$region","$stackname");
\@Filenames = (\$instance_ids, \$private_ips, \$public_ips, \$nodetypes);
my \@tmp = putHPCCInstanceInfoInFiles(\\\@sorted_InstanceInfo,\@Filenames);
1;
EOFF1

$_ = $template_ClusterInitVariables;

open(OUT,">$ThisDir/ClusterInitVariables.pl") || die "Can't open for output: \"$ThisDir/ClusterInitVariables.pl\"\n";
print OUT $_;
close(OUT);
print "Created $ThisDir/ClusterInitVariables.pl\n";

system("chmod 755 $ThisDir/ClusterInitVariables.pl");
