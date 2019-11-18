#!/usr/bin/perl

$ThisDir=($0 =~ /^(.+)[\\\/]/)? $1 : "." ;
require "$ThisDir/ClusterInitVariables.pl";

# NOTE: This scripts REQUIRES the aws cli be setup.

#----------------------------------
# Status all instances
#----------------------------------
@asgname=();
@all_instance_id=();
if ( open(IN,$asgfile) ){
 while (<IN>){
   chomp;
   my ($asgname,$csv_instance_list)=split(/:/,$_);
#  next if $asgname !~ /SlaveASG/; # DEBUG DEBUG DEBUG
   push @asgname, $_;
   my @asg_instance_id=split(/,/,$csv_instance_list);
   push @all_instance_id, @asg_instance_id;
 }
 close(IN);
}

if ( defined($instance_id) && -e $instance_id ){
  $_=`cat $instance_id`;
  @i=split(/\n/,$_);
  $description{$i[0]}='Master' if $no_hpcc==0; # First instance_id is the master's IF we have an hpcc.
  foreach my $instance_id (@i){
     if ( /\bi\-/ ){
       unshift @all_instance_id, $instance_id;
     }
  }
}
else{
 die "FATAL ERROR: \$instance_id should contain the of a file that contains instance ids.\n";
}

# Add any instances in @additional_instances.
foreach my $instance_id (@additional_instances){
   unshift @all_instance_id, $instance_id;
}

$all_instances_running=1;
print "There are ",scalar(@all_instance_id)," instances in this system.\n";
for( my $i=0; $i < scalar(@all_instance_id); $i++){
  my $instance_id=$all_instance_id[$i];
  my $status = InstanceStatus($instance_id);
  my $description = (exists($description{$instance_id}))? $description{$instance_id} : 'Slave';
  print "Instance, $instance_id, status is \"$status\": $description\n";
  $all_instances_running=0 if $no_hpcc || $status ne 'running';
}
if ($all_instances_running){
  print "\nCheck status of HPCC System\n";
  $master_ip=`head -1 $private_ips`;chomp $master_ip;
  system("ssh -i $pem -t $sshuser\@$master_ip \"sudo /opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init status\"");
}
#========================================================================================
sub InstanceStatus{
my ( $instance_id )=@_;
  local $_ = `aws ec2 describe-instance-status --instance-id $instance_id --region $region`;
#  print "DEBUG: In InstanceStatus. \"$_\"\n";
  my $InstanceState='';
  if ( /"InstanceState": \{(.+?)\}/s ){
     local $_ = $1;
     if ( /"Name" *: *"([^"]+)"/s ){
        $InstanceState=$1;
     }
  }
  elsif ( /"InstanceStatuses": \[\]/ ){
        $InstanceState="Stopping or Stopped";
  }
#print "DEBUG: Leaving InstanceStatus. InstanceState=\"$InstanceState\"\n";exit;
  return $InstanceState;
}
