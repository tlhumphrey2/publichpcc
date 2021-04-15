#!/usr/bin/perl
#==========================================================================================================
# USAGE: my $TagsAndValuesString = makeKeyValueString($TagsAndValuesRef,$TagArrayRef);
sub makeKeyValueString{
my ($TagsAndValuesRef,$TagArrayRef)=@_;
  my @TagAndValue = ();
  foreach my $tag (@$TagArrayRef){
          my $tv = "Key=$tag,Value=$$TagsAndValuesRef{$tag}";
          push @TagAndValue, $tv;
  }
  return join(" ",@TagAndValue);
}
#==========================================================================================================
# USAGE: my ($TagsAndValuesRef, $TagArrayRef) = getAllTagsAndValues($TagsAndValuesFile);
sub getAllTagsAndValues{
my ($TagsAndValuesFile)=@_;
   my %TagsAndValues = ();
   my @TagArray = ();
   open(IN, $TagsAndValuesFile) || die "Can't open for input: \"$TagsAndValuesFile\"\n";
   while(<IN>){
           chomp;
           my ($tag, $value) = split(/=/,$_);
           push @TagArray, $tag;
           $TagsAndValues{$tag} = ($value !~ /[\@\.]/)? "$value" : "'".$value."'";
   }
return (\%TagsAndValues,\@TagArray);
}
#==========================================================================================================
# detachEBSVolume($volumeid, $region);
sub detachEBSVolume{
my ($volumeid, $region)=@_;
    local $_;
    my $c=0;
    DETACHVOLUME:
    $c++;
     print("$c. aws ec2 detach-volume --volume-id $volumeid --region $region\n");
     $_ = `aws ec2 detach-volume --volume-id $volumeid --region $region`;
     print("Return from 'aws ec2 attach-volume' is \"$_\"\n");

     WAITDETACH:
     $_=`aws ec2 describe-volumes --volume-ids $volumeid --region $region|$ThisDir/json2yaml.sh`;
     print("Return from 'aws ec2 describe-volumes' is \"$_\"\n");
     sleep(5);
    goto "WAITDETACH" if ! /State: available/s; # Go back and check if volume has detached if not 'State: available'
}
#==========================================================================================================
# attachEBSVolume($volumeid, $ThisInstanceId, $dev, $region);
sub attachEBSVolume{
my ($volumeid, $ThisInstanceId, $dev, $region)=@_;
    local $_;
    my $c=0;
    ATTACHVOLUME:
    $c++;
     print("$c. aws ec2 attach-volume --volume-id $volumeid --instance-id $ThisInstanceId --device $dev --region $region\n");
     $_ = `aws ec2 attach-volume --volume-id $volumeid --instance-id $ThisInstanceId --device $dev --region $region`;
     print("Return from 'aws ec2 attach-volume' is \"$_\"\n");

     WAITATTACH:
     $_=`aws ec2 describe-volumes --volume-ids $volumeid --region $region|$ThisDir/json2yaml.sh`;
     print("Return from 'aws ec2 describe-volumes' is \"$_\"\n");
     if ( ! /\{AttachTime: '\d{4}-\d{2}-\d{2}T/s ){ # If there isn't a time then volume hasn't attached
       sleep(5);
       goto "ATTACHVOLUME";
     }

     print "DEBUG: volume description is \"$_\"\n";
     sleep(5);
    goto "ATTACHVOLUME" if /IncorrectState/s; # Go back and do attach again when 'IncorrectState'
    goto "WAITATTACH" if /\battaching\b/s; # Go back and check if volume has attached if 'attaching'
}
#==========================================================================================================
# $volumeid = makeEBSVolume($ebssize, $az, $region);
sub makeEBSVolume{
my ($ebssize, $az, $region, $stackname, $ClusterComponent)=@_;
   print "aws ec2 create-volume --size $ebssize --region $region --availability-zone $az --volume-type gp2  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=$stackname--$ClusterComponent}]'\n";
   my $makeebs=`aws ec2 create-volume --size $ebssize --region $region --availability-zone $az --volume-type gp2  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=$stackname--$ClusterComponent}]'`;
   print "DEBUG: makeebs=\"$makeebs\"\n";
   my $volumeid = ($makeebs=~/"VolumeId"\s*: "(vol-[^"]+)"/)? $1 : '';

   # Wait until volume is available
   print "In makeEBSVolume. aws ec2 describe-volumes --region $region --volume-ids $volumeid\n";
   local $_=`aws ec2 describe-volumes --region $region --volume-ids $volumeid 2>&1`;
   my $volume_available=(/"State"\s*:\s*"available"/s)? 1 : 0 ; 
   my $c=0;
   while ( ! $volume_available && ( $c <= 20 ) ){ 
      $c++;   
      print "In makeEBSVolume. $c. volume is not available, yet. WAITING.\n";
      sleep 5;
      print "In makeEBSVolme. aws ec2 describe-volumes --region $region --volume-ids $volumeid\n";
      local $_=`aws ec2 describe-volumes --region $region --volume-ids $volumeid 2>&1`;
      $volume_available=(/"State"\s*:\s*"available"/s)? 1 : 0 ; 
   }

   print "In makeEBSVolume. Volume, $volumeid, is now available.\n";

return $volumeid;
}
#==========================================================================================================
# USAGE EXAMPLE: @asgnames = getASGNames( $region, $stackname, $filter );
sub getASGNames{
my ( $region, $stackname, $filter )=@_;
print STDERR "aws autoscaling describe-auto-scaling-groups --region $region\n";
$_=`aws autoscaling describe-auto-scaling-groups --region $region`;

# 2 greps. Inter-most gets only lines containing both 'AutoScalingGroupARN' and $stackname. The out-most grep
# extracts just the ASG name. All names are put in @asgnames.
@asgnames=grep($_=extractASGName($_),grep(/\"AutoScalingGroupARN\":.+$stackname/,split(/\n+/,$_)));
print STDERR "asgnames=(",join(",",@asgnames),")\n";

@asgnames = grep(/$filter/,@asgnames) if $filter !~ /^\s*$/;

return @asgnames;
}
#------------------------------------------
sub extractASGName{
my ( $a )=@_;
local $_=$a;
  s/^.*autoScalingGroupName\///;
  s/\",\s*$//;
return $_;
}
#==========================================================================================================
sub getComponentIPsByLaunchTime{
my ($stackname, $region, $ip_type, @component)=@_;
require "$ThisDir/cf_common.pl";
require "$ThisDir/common.pl";

  my @DesiredInfo = ();
  $DesiredInfo[0]='LaunchTime';
  $DesiredInfo[1]=($ip_type eq 'private')? 'PrivateIpAddress': 'PublicIpAddress';
  $DesiredInfo[2]='Name';
  $DesiredInfo[3]='State';

  my @InstanceInfo0 = getClusterInstanceInfo ($region, $stackname, @DesiredInfo);
  #print STDERR "DEBUG: ",join("\nDEBUG: ",@InstanceInfo0),"\n";
   
  my $undesired_states = '\b(?:stopp|terminat)';
  @InstanceInfo = grep(!/$undesired_states/,@InstanceInfo0);

  my @SortedInstanceInfo = sort {(split(/\s+/,$a))[0] cmp (split(/\s+/,$b))[0]} @InstanceInfo;
  my $nodetype = '(?:' . join('|',@component) . ')';
  my @NodeTypeInstance = grep(/\-\-$nodetype\b/,@SortedInstanceInfo);
  
  my @PrivateIP = ();
  foreach (@NodeTypeInstance){
    push @PrivateIP, (split(/\s+/,$_))[1];
  }
return @PrivateIP;
}
#==========================================================================================================
sub makeComponentProcessLines{
my ( $nodetype, @IPs )=@_;
print STDERR "DEBUG: Entering makeComponentProcessLines. nodetype=\"$nodetype\", \@IPs=(",join(", ",@IPs),")\n";

 my $thor_process_template = '   <ThorSlaveProcess computer="<node_id>" name="s<num>"/>'; 
 my $roxie_process_template = '   <RoxieServerProcess computer="<node_id>" name="<node_id>" netAddress="<ip>"/>'; 
 my @process_line = ();
 my $num=1;
 foreach (@IPs){
   my $ip = $_;
   s/^\d+\.\d+.\d+.(\d+)$/$1/;
   my $pline = ($nodetype eq 'Slave')? $thor_process_template : $roxie_process_template ;
   my $node_id = sprintf "node%06d",$_;
   $pline =~ s/<node_id>/$node_id/g;
   $pline =~ s/<num>/$num/g;
   $pline =~ s/<ip>/$ip/g;
   push @process_line, $pline;
   $num++;
 }
print STDERR "DEBUG: Leaving makeComponentProcessLines. \@process_line=(",join(", ",@process_line),")\n";
return @process_line;
}
#==========================================================================================================
sub replaceComponentProcessLines{
my ( $envfile, $nodetype, @process_line )=@_;
print STDERR "DEBUG: Entering replaceComponentProcessLines. nodetype=\"$nodetype\", \@process_line=(",join(", ",@process_line),")\n";
  @process_line = grep(! /^\s*$/,@process_line);
  local $_ = `cat $envfile`;
  my @line = split(/\n/,$_);
  my $slave_process = '<ThorSlaveProcess';
  my $roxie_process = '<RoxieServerProcess';
  my $pid  = ($nodetype eq 'Slave')? $slave_process : $roxie_process ;
  my @new = ();
  my $found_processes = 0;
  for ( my $i=0; $i < scalar(@line); ){
    $_ = $line[$i];
    if ( /$pid/ ){
      $found_processes = 1;
      do{
        print STDERR "DEBUG: In replaceComponentProcessLines. Found process line: \"$_\"\n";
        $i++;
        $_ = $line[$i];
      } while( /$pid/ );
      push @new, @process_line;
    }

    if ( $found_processes ){
      push @new, @line[ $i .. $#line ];
      last;
    }
    else{
      push @new, $_;
    }
    $i++;
  }

  if ( $found_processes == 0 ){
    print STDERR "DEBUG: In replaceComponentProcessLines. ERROR. DID NOT find any lined beginning with \"$pid\"\n";
  }
return join("\n",@new);
}
#==========================================================================================================
# This routine replaces component (either Slave or Roxie) process lines with process lines ordered by launch time
sub orderComponentProcessLinesByLaunchTime{
my ($envfile, $stackname, $region, $nodetype)=@_;
  print STDERR "Entering orderComponentProcessLinesByLaunchTime. envfile=\"$envfile\", stackname=\"$stackname\", region=\"$region\", nodetype=\"$nodetype\".\n";

  print STDERR "In orderComponentProcessLinesByLaunchTime. getComponentIPsByLaunchTime($stackname, $region, 'private', ($nodetype))\n";
  my @IPs = getComponentIPsByLaunchTime($stackname, $region, 'private', ($nodetype));
  print STDERR "In orderComponentProcessLinesByLaunchTime. ",join("\nIn orderComponentProcessLinesByLaunchTime. ",@IPs),"\n";

  print STDERR "In orderComponentProcessLinesByLaunchTime. makeComponentProcessLines( $nodetype, @IPs )\n";
  my @process_line = makeComponentProcessLines( $nodetype, @IPs );
  print STDERR "\n============================ Process Lines ============================\n";
  print STDERR "In orderComponentProcessLinesByLaunchTime. ",join("\nIn orderComponentProcessLinesByLaunchTime. ",@process_line),"\n";

  print STDERR "In orderComponentProcessLinesByLaunchTime. replaceComponentProcessLines( $envfile, $nodetype, @process_line )\n";
  my $new_environment = replaceComponentProcessLines( $envfile, $nodetype, @process_line );
  open(OUT,">$ThisDir/new_environment.xml") || die "Can't open for output: \"$ThisDir/new_environment.xml\"\n";
  print OUT "$new_environment\n";
  close(OUT);
  print STDERR "In fixComponentProcessLines. new_environment.xml file=\"$ThisDir/new_environment.xml\"\n";
return "$ThisDir/new_environment.xml";
}
#==========================================================================================================
# EXAMPLE USAGE: orderEnvProcessLinesByLaunchTime('/etc/HPCCSystems/environment.xml', $stackname, $region, 'Slave');
sub orderEnvProcessLinesByLaunchTime{
my ($envfile, $stackname, $region, $nodetype)=@_;
  print STDERR "Enter orderEnvProcessLinesByLaunchTime. orderComponentProcessLinesByLaunchTime( $envfile, $stackname, $region, $nodetype)\n";
  my $new_env_file = orderComponentProcessLinesByLaunchTime( $envfile, $stackname, $region, $nodetype);
  print STDERR "In orderEnvProcessLinesByLaunchTime.. cp -v $new_env_file $out_environment_file\n";
  $_=`cp -v $new_env_file $envfile`;
  print STDERR "In orderEnvProcessLinesByLaunchTime.. cp new_environment.xml return code is \"$_\"\n";
  if ( $envfile eq '/etc/HPCCSystems/environment.xml' ){
    print STDERR "In orderEnvProcessLinesByLaunchTime.. cp -v $new_env_file $created_environment_file\n";
    $_=`cp -v $new_env_file $created_environment_file`;
  }
  else{
    print STDERR "In orderEnvProcessLinesByLaunchTime. DID NOT cp -v $new_env_file created_environment_file\n";
  }
}
#==========================================================================================================
sub getSshUser{
  my $sshuser=`basename $ThisDir`;chomp $sshuser;
  return $sshuser;
}
#==========================================================================================================
sub getTerminatedIP{
=pod
This routine returns terminated_ip and new_ip. Here is how it does it.
It gets all the IPs from the environment.xml file on the master and removes the master's IP (the 1st IP). This leaves
IPs for the slaves and roxies and possibly other support IPs. It then gets all the IPs of this instance in $private_ips and
removes the master's IP (1st IP) from the list. Then a regex is made of both of these lists of IPs. $re_tt2 is the list of
IPs from the master's environment.xml file and $re_pri_ips for the IPs found in $private_ips of this instance.
Then the last grep statement at the end of this routine gets the IP of the terminated instance. 
=cut
  my $MasterIP=`head -1 $private_ips`;chomp $MasterIP;
  print STDERR "In getTerminatedIPAndNewIP. In getTerminatedIPAndNewIP. MasterIP=\"$MasterIP\"\n";
  # Get all private IPs of environment.xml file and put in file, tt2. Then make array @tt2. Make regexp $re_tt2.
  print STDERR "ssh -o StrictHostKeyChecking=no -i $pem $sshuser\@$MasterIP \"/opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -machines\" \> tt2\n";
  my $rc0=`ssh -o StrictHostKeyChecking=no -i $pem $sshuser\@$MasterIP "/opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -machines" > tt2`;
  print STDERR "In getTerminatedIPAndNewIP. rc0=\"$rc0\"\n";
  my $tt2=`cat tt2|sed -e "s/,.*\$//"`; print STDERR "In getTerminatedIPAndNewIP. tt2=\"$tt2\"\n";
  my @tt2=split(/\n/,$tt2); @tt2=grep(/\d+(?:\.\d+){3}/,@tt2); shift @tt2; grep(s/[^\d\.]//g,@tt2);
  print STDERR "In getTerminatedIPAndNewIP. \@tt2=(",join("\n",@tt2),")\n";

  # Get current private ips and remove master's ip (i.e. shift @pri_ips). Make regex $re_pri_ips.
  my $pri_ips=`cat $private_ips`;print STDERR "In getTerminatedIPAndNewIP. pri_ips=\"$pri_ips\"\n";
  my @pri_ips=split(/\n/,$pri_ips); @pri_ips=grep(/\d+(?:\.\d+){3}/,@pri_ips);shift @pri_ips; print STDERR "In getTerminatedIPAndNewIP. \@pri_ips=(",join(",",@pri_ips),")\n";
  my $re_pri_ips=join("|",@pri_ips);print STDERR "In getTerminatedIPAndNewIP. re_pri_ips=\"$re_pri_ips\"\n";

  #Get ip that is being replaced by new ip because it terminated.
  my $terminated_ip; ($terminated_ip)=grep( ! /$re_pri_ips/, @tt2);
  print STDERR "In getTerminatedIPAndNewIP. terminated_ip=\"$terminated_ip\", new_ip=\"$new_ip\"\n";
return $terminated_ip;
}
#==========================================================================================================
sub InstanceVariablesFromInstanceDescriptions{
my ($region,$stackname)=@_;
require "$ThisDir/cf_common.pl";

my @DesiredInfo = ();
$DesiredInfo[0]='InstanceId';
$DesiredInfo[1]='State';
$DesiredInfo[2]='LaunchTime';
$DesiredInfo[3]='InstanceType';
$DesiredInfo[4]='PublicIpAddress';
$DesiredInfo[5]='PrivateIpAddress';
$DesiredInfo[6]='Name';
$DesiredInfo[7]='HPCCPlatform';
$DesiredInfo[8]='pem';
$DesiredInfo[9]='slavesPerNode';
$DesiredInfo[10]='roxienodes';
$DesiredInfo[11]='VolumeIds';

my @InstanceInfo0 = getClusterInstanceInfo ($region, $stackname, @DesiredInfo);
my @InstanceInfo=();
foreach (@InstanceInfo0){
  my @info = split(/\s+/,$_);
  my %InstanceVariable=(); 
  for( my $i=0; $i < scalar(@info); $i++){
    local $_ = $info[$i];
    s/$stackname\-\-(.+)$/$1/;
    if ( /\bvol\-/ ){
      s/^\s+//;
      s/\s+$//;
      my @vol=@info[$i .. $#info];
      $_ = \@vol;
      last;
    }
    $InstanceVariable{$DesiredInfo[$i]} = $_;
  }
  push @InstanceInfo, \%InstanceVariable;
}

my @sorted_InstanceInfo=sort { HashValue($a,'Name','a') cmp HashValue($b,'Name','b') } @InstanceInfo;
#print STDERR "Leaving InstanceVariablesFromInstanceDescriptions. Size of \@sorted_InstanceInfo=",scalar(@sorted_InstanceInfo),"\n";
return @sorted_InstanceInfo;
}
#==========================================================================================================
sub putHPCCInstanceInfoInFiles{
my ($ref_sorted_InstanceInfo, @Filenames)=@_;
   my @sorted_InstanceInfo=@$ref_sorted_InstanceInfo;
   print STDERR "Entering putHPCCInstanceInfoInFiles. scalar(\@sorted_InstanceInfo)=\"",scalar(@sorted_InstanceInfo),"\"\n";
   #------------------------------------------------------------------------------------
   # Get Instance Ids, private_ips, public_ips, and nodetypes of ONLY HPCC instances
   #------------------------------------------------------------------------------------
   @sorted_InstanceInfo=InstanceVariablesFromInstanceDescriptions($region,$stackname) if scalar(@sorted_InstanceInfo) == 0;
   my (@InstanceIds, @private_ips, @public_ips, @nodetypes);
   my $roxienodes=0;
   my $supportnodes=0;
   my $slave_instances=0;
   for( my $i=0; $i < scalar(@sorted_InstanceInfo); $i++){
     my %InstanceVariable=%{$sorted_InstanceInfo[$i]};
     #print STDERR "In putHPCCInstanceInfoInFiles. InstanceVariable{'nodetype'}=\"$InstanceVariable{'Name'}\"\n";
     if ((($InstanceVariable{'State'} eq 'running') || ($InstanceVariable{'State'} eq 'stopped')) && ($InstanceVariable{'Name'} !~ /Bastion/)){
       push @InstanceIds, $InstanceVariable{'InstanceId'};
       push @private_ips, $InstanceVariable{'PrivateIpAddress'};
       push @public_ips, $InstanceVariable{'PublicIpAddress'} if ($InstanceVariable{'State'} eq 'running');
       push @nodetypes, $InstanceVariable{'Name'};
       
       if ( $InstanceVariable{'Name'} =~ /Roxie/ ){
         $roxienodes++;
       }
       elsif ( $InstanceVariable{'Name'} =~ /Slave/ ){
         $slave_instances++;
       }
       else{
         $supportnodes++;
       }
     }
   }
   print STDERR "In putHPCCInstanceInfoInFiles. scalar(\@InstanceIds)=\"",scalar(@InstanceIds),"\"\n";

   if ( scalar(@Filenames) == 4 ){
     $instance_ids = shift @Filenames;
     $private_ips = shift @Filenames;
     $public_ips = shift @Filenames;
     $nodetypes = shift @Filenames;
     print STDERR "In putHPCCInstanceInfoInFiles. Filenames: ($instance_ids, $private_ips, $public_ips, $nodetypes)\n";
   }
   #------------------------------------------------------------------------------------
   # Put Instance Ids of HPCC System in the file, $instance_ids.
   #------------------------------------------------------------------------------------
   open(OUT,">$instance_ids") || die "Can't open for output: \"$instance_ids\"\n";
   for( my $i=0; $i < scalar(@InstanceIds); $i++){
     #print STDERR "In putHPCCInstanceInfoInFiles. OUTPUT InstanceIds\[$i\]=$InstanceIds[$i]\n";
     print OUT "$InstanceIds[$i]\n";
   }
   close(OUT);
   
   #------------------------------------------------------------------------------------
   # Put private ips of HPCC System in the file, $private_ips.
   #------------------------------------------------------------------------------------
   open(OUT,">$private_ips") || die "Can't open for output: \"$private_ips\"\n";
   for( my $i=0; $i < scalar(@private_ips); $i++){
     #print STDERR "In putHPCCInstanceInfoInFiles. OUTPUT private_ips\[$i\]=$private_ips[$i]\n";
     print OUT "$private_ips[$i]\n";
   }
   close(OUT);
   
   #------------------------------------------------------------------------------------
   # Put public ips of HPCC System in the file, $public_ips.
   #------------------------------------------------------------------------------------
   open(OUT,">$public_ips") || die "Can't open for output: \"$public_ips\"\n";
   for( my $i=0; $i < scalar(@public_ips); $i++){
     #print STDERR "In putHPCCInstanceInfoInFiles. OUTPUT public_ips\[$i\]=$public_ips[$i]\n";
     print OUT "$public_ips[$i]\n";
   }
   close(OUT);
   
   #------------------------------------------------------------------------------------
   # Put nodetypes of HPCC System in the file, $nodetypes.
   #------------------------------------------------------------------------------------
   open(OUT,">$nodetypes") || die "Can't open for output: \"$nodetypes\"\n";
   for( my $i=0; $i < scalar(@nodetypes); $i++){
     #print STDERR "In putHPCCInstanceInfoInFiles. OUTPUT nodetypes\[$i\]=$nodetypes[$i]\n";
     print OUT "$nodetypes[$i]\n";
   }
   close(OUT);
return ($roxienodes,$slave_instances,$supportnodes);
}
#==========================================================================================================
sub extractLines{
my ($d)=@_;
my @line=split(/\n+/,$d);
#print STDERR "In extractLines. Number of lines is ",scalar(@line),"\n";
@line=grep(!/^\s*$/,@line);
#print STDERR "In extractLines. After removing blank lines. Number of lines is ",scalar(@line),"\n";
return \@line;
}
#==========================================================================================================
sub spaces2dots{
my ($s,$line)=@_;
$s =~ s/ /./g;
$line=~s/^ +//;
return $s.$line;
}
#==========================================================================================================
sub getRunningNoneBastionInstances{
my ($region,$stackname)=@_;
 print STDERR "Entering getRunningNoneBastionInstances. region=\"$region\",stackname=\"$stackname\"\n";
 my @sorted_InstanceInfo=InstanceVariablesFromInstanceDescriptions($region,$stackname);

 my @ii=();
 for( my $i=0; $i < scalar(@sorted_InstanceInfo); $i++){
   my %InstanceVariable=%{$sorted_InstanceInfo[$i]};
   if (($InstanceVariable{'State'} eq 'running') && ($InstanceVariable{'Name'} ne 'Bastion')){
     print STDERR "Found running none Bastion instance. InstanceVariable{'Name'}=\"$InstanceVariable{'Name'}\"\n";
     push @ii, \%InstanceVariable;
   }
 }
 print STDERR "Leaving getRunningNoneBastionInstances. Size of \@ii is ",scalar(@ii),"\n";
return @ii;
}
#===================================================================
sub HashValue{
my ($varPtr,$key, $ab)=@_;
 my %InstanceVariable=%{$varPtr};
return $InstanceVariable{$key}; 
}
#==========================================================================================================
sub makeEIP{
my ($region, $stackname, $s3bucket, $prefix)=@_;
# Example of $prefix is 'bastion_'
  local $EIP;
  local $EIPAllocationId;

  # Make EIP for vpc domain
  print STDERR "aws ec2 allocate-address --domain vpc --region $region\n";
  local $_=`aws ec2 allocate-address --domain vpc --region $region 2>&1`;

  print STDERR "In makeEIP. allocate-address rc=\"$_\"\n";

  # If maximum number of addresses has been reached. Find EIP that isn't being used.
  if ($_ =~ /The maximum number of addresses has been reached/s){
    print STDERR "In makeEIP. Maximum number of addresses has been reached.\n";
    print STDERR "In makeEIP: aws ec2 describe-addresses --region $region|./json2yaml.sh\n";
    local $_=`aws ec2 describe-addresses --region $region|$ThisDir/json2yaml.sh`;
    ($EIPAllocationId, $EIP) = getUnusedEIP($_);
  }
  elsif ( $_ =~ /error occurred/s ){
     die "FATAL ERROR: In makeEIP. There was an error when trying to execute \"aws ec2 allocate-address\". See 'rc' for details. rc=\"$rc\".\n";
  }
  else{
    # Get EIP from $_
    $EIP=$1 if $_ =~ /"PublicIp": "(\d+(?:\.\d+){3})"/s;
    # Get EIP AllocationId from $_
    $EIPAllocationId=$1 if $_ =~ /"AllocationId": "(eipalloc-\w+)"/s;
    print STDERR "In makeEIP. Created. EIP=\"$EIP\", EIPAllocationId=\"$EIPAllocationId\".\n";
  }


  # Put $EIPAllocationId in a file named "${prefix}EIPAllocationId" and put file in s3 bucket, $s3bucket
  my $eipfile = "${prefix}EIPAllocationId";
  print STDERR "Put $EIPAllocationId in the $ThisDir/$eipfile and place file in s3bucket, $s3bucket\n";
  putInFileAndStoreInS3Bucket("$ThisDir/$eipfile", $EIPAllocationId, $s3bucket );

  # Put EIP and EIPAllocationId in configuration file
  my $vEIP = "${prefix}EIP";
  print STDERR "In makeEIP. echo \"$vEIP=$EIP\" \>\> $ThisDir/cfg_BestHPCC.sh\n";
  my $rc=`echo "$vEIP=$EIP" >> $ThisDir/cfg_BestHPCC.sh 2>&1`;
  print STDERR "In makeEIP. rc for putting $vEIP in cfg_BestHPCC.sh is \"$rc\"\n";
  print STDERR "In makeEIP. echo \"$eipfile=$EIPAllocationId\" \>\> $ThisDir/cfg_BestHPCC.sh\n";
  my $rc=`echo "$eipfile=$EIPAllocationId" >> $ThisDir/cfg_BestHPCC.sh 2>&1`;
  print STDERR "In makeEIP. rc for putting $eipfile in cfg_BestHPCC.sh is \"$rc\"\n";

  print STDERR "In makeEIP:aws ec2 create-tags --resources $EIPAllocationId --tags \"Key=Name,Value=$stackname\" --region $region\n";
  my $rc=`aws ec2 create-tags --resources $EIPAllocationId --tags "Key=Name,Value=$stackname" --region $region`;
  print STDERR "In makeEIP. 'create-tags' rc is \"$rc\"\n";

  print STDERR "Leaving makeEIP. EIP=\"$EIP\", EIPAllocationId=\"$EIPAllocationId\"\n";
  return ($EIP, $EIPAllocationId);
}
#==========================================================================================================
sub AlertUserOfChangeInRunStatus{
my ($region, $email, $stackname, $subject, $body)=@_;
  $body = $subject if $body =~ /^\s*$/;
  my $toJsonFile="$ThisDir/toFileRunStatusChange.json";
  my $emailJsonFile="$ThisDir/emailFileRunStatusChange.json";
  
  # If HPCC Managed Service started this cluster then put message on HMS-Change-Notification SQS Queue
  if ( $stackname =~ /^mhpcc-/ ){
    print STDERR "aws sqs send-message --queue-url https://sqs.$region.amazonaws.com/633162230041/$stackname --message-body \"$body\" --delay-seconds 0 --region us-east-1\n";
    $rc=`aws sqs send-message --queue-url https://sqs.$region.amazonaws.com/633162230041/$stackname --message-body "$body" --delay-seconds 0 --region $region`;
    # For DEBUG we will send email as well as message to sqs queue, $stackname
    sendMail($email, $email, $subject, $body, $toJsonFile, $emailJsonFile);
  }
  else{
    sendMail($email, $email, $subject, $body, $toJsonFile, $emailJsonFile);
  }
}
#==========================================================================================================
sub sendMail{
my ($from, $to, $subject, $body, $to_filepath, $email_filepath)=@_;
print STDERR "Entering sendMail. from=\"$from\", to=\"$to\", subject=\"$subject\", body=\"$body\", to_filepath=\"$to_filepath\", email_filepath=\"$email_filepath\"\n";

my $email_json=<<EOFF1;
{
  "Subject": {
    "Data": "<subject>",
    "Charset": "UTF-8"
  },
  "Body": {
    "Text": {
    "Data": "<body>",
      "Charset": "UTF-8"
    }
  }
}
EOFF1

my $to_json=<<EOFF2;
{
  "ToAddresses": ["<to>"]
}
EOFF2

$_=$email_json;
s/<subject>/$subject/s;
s/<body>/$body/s;
put2file($email_filepath,$_);

$_=$to_json;
s/<to>/$to/s;
s/\\\@/\@/gs;
put2file($to_filepath,$_);

print STDERR "In sendMail. aws ses send-email --from $from --destination file://$to_filepath --message file://$email_filepath --region us-east-1\n";
my $rc=`aws ses send-email --from $from --destination file://$to_filepath --message file://$email_filepath --region us-east-1`;
print STDERR "In sendMail. aws ses send-email rc=\"$rc\"\n";
}
#==========================================================================================================
sub put2file{
my ($outfile, $content)=@_;
open(OUT,">$outfile") || die "In $0. Can't open for output: \"$outfile\"\n";
print OUT "$content\n";
close(OUT);
}
#==========================================================================================================
sub putInFileAndStoreInS3Bucket{
my ($outfile, $content, $s3bucket)=@_;
put2file($outfile,$content);

my $filename=`basename $outfile`; chomp $filename;
print STDERR "In putInFileAndStoreInS3Bucket. aws s3 cp $outfile s3://$s3bucket/$filename\n";
my $rc=`aws s3 cp $outfile s3://$s3bucket/$filename 2>&1`;
print STDERR "In putInFileAndStoreInS3Bucket. cp $outfile to s3 bucket, $s3bucket. rc=\"$rc\"\n";
}
#==========================================================================================================
sub checkStatusOfCluster{
my ($stackname, $MasterEIP)=@_;
  my @component=("mydfuserver","myeclagent","myeclccserver","myeclscheduler","myesp","mysasha","mydafilesrv");

  # Add THOR and/or ROXIE if in the configuration.
  my %found=();
  foreach (@nodetype){
    if ( ($_ eq 'Slave') && (! $found{'mythor'}) ){
      $found{'mythor'}=1;
      push @component, 'mythor';
    }
    elsif ( ($_ eq 'Roxie') && (! $found{'myroxie'}) ){
      $found{'myroxie'}=1;
      push @component, 'myroxie';
    }
  }

  # Make regular expression of component names
  my $re_component='(?:' . join('|', @component) . ')';
  
  # Set all component run status to "not running" (0).
  my %Running=();
  foreach my $c (@component){
    $Running{$c}=0;
  }

  # Get status of all components in configuration
  local $_=`/opt/HPCCSystems/sbin/hpcc-run.sh -a hpcc-init status 2>&1`;
  my @line=split(/\n+/,$_);

  # Check status of each component
  my $NumberRunning=0;
  foreach (@line){
    if ( /\b($re_component)\b.* is running/ ){
      $Running{$1}=1;
      $NumberRunning++;
    }
  }

  my $NumberComponents=scalar(@component);
  my $message='UNKNOWN';
  if ( $NumberRunning == $NumberComponents ) {
    $message="$stackname. All components are running. Cluster, $stackname (Master public IP is $MasterEIP).";
  }
  elsif ( $NumberRunning < ($NumberComponents-1) ) {
    $message="$stackname. More than one component is down. Cluster, $stackname (Master public IP is $MasterEIP).";
  }
  else{
    my $DownComponent='UNKNOWN';
    foreach (@component){
      $DownComponent=$_ if $Running{$_} != 1;
    }
    $message="$stackname. $DownComponent is down. Cluster, $stackname (Master public IP is $MasterEIP).";
  }  
  
return $message;
}
#==========================================================================================================
sub putInS3AddingSlavesOrRoxies{
my ($stackname, $region, $value)=@_;
$stackname = lc($stackname);
my $rc = `echo $value > $ThisDir/AddingSlavesOrRoxies`;
$rc = `aws s3 cp $ThisDir/AddingSlavesOrRoxies s3://$stackname/AddingSlavesOrRoxies 2>&1`;
return $rc;
}
#==========================================================================================================
# USAGE EXAMPLE: $AddingSlavesOrRoxies = getAddingSlavesOrRoxies($stackname,$region);
sub getAddingSlavesOrRoxies{
my ($stackname, $region)=@_;
$stackname = lc($stackname);
print STDERR "Entering getAddingSlavesOrRoxies. stackname=\"$stackname\", region=\"$region\".\n";
$AddingSlavesOrRoxies = `aws s3 cp s3://$stackname/AddingSlavesOrRoxies -`; chomp $AddingSlavesOrRoxies;
$AddingSlavesOrRoxies = 'false' if $AddingSlavesOrRoxies =~ /\bNot Found\b/i;
print STDERR "Leaving getAddingSlavesOrRoxies. AddingSlavesOrRoxies=\"AddingSlavesOrRoxiesip\".\n";
return $AddingSlavesOrRoxies;
}
#==========================================================================================================
sub getMasterEIP{
my ($stackname, $region, $EIPAllocationId)=@_;
$stackname = lc($stackname);
print STDERR "Entering getMasterEIP. region=\"$region\", EIPAllocationId=\"$EIPAllocationId\".\n";
if ( $EIPAllocationId =~ /^\s*$/ ){
  $EIPAllocationId = `aws s3 cp s3://$stackname/EIPAllocationId -`; chomp $EIPAllocationId;
}
print STDERR "In getMasterEIP: aws ec2 describe-addresses --allocation-ids $EIPAllocationId --region $region|$ThisDir/json2yaml.sh\n";
local $_=`aws ec2 describe-addresses --allocation-ids $EIPAllocationId --region $region|$ThisDir/json2yaml.sh`;
my $ip=$1 if /PublicIp: (\d+(?:\.\d+){3})/s;
print STDERR "Leaving getMasterEIP. ip=\"$ip\".\n";
return $ip;
}
#==========================================================================================================
=pod
sub getUnusedEIP{
my ($a)=@_;
local $_=$a;
    my @eip= m/\bAllocationId: eipalloc.+?(?=\bAllocationId: eipalloc|$)/sg;
    print STDERR "Before removing assigned: ";for( my $i=0; $i < scalar(@eip); $i++){ print STDERR "eip $i is \"$eip[$i]\"\n\n"; }
    @eip=grep(!/InstanceId:/,@eip);
    print STDERR "After removing assigned: ";for( my $i=0; $i < scalar(@eip); $i++){ print STDERR "eip $i is \"$eip[$i]\"\n\n"; }

    local $FoundEIP=0;
    foreach (@eip){
      if ( /\bAllocationId: (eipalloc-\w+)\b.*\bvpc\b.* PublicIp: (\d+(?:\.\d+){3})/s ){
        $EIPAllocationId=$1;
        $EIP=$2;
        print STDERR "In makeEIP. Found unused. EIP=\"$EIP\", EIPAllocationId=\"$EIPAllocationId\".\n";
	$FoundEIP=1;
        last;
      }
    }
    die "FATAL ERROR: In makeEIP. While searching for unused EIP. None found.\n" if ! $FoundEIP;
return ($EIPAllocationId, $EIP);
}
#==========================================================================================================
=cut
sub getUnusedEIP{
my ($a)=@_;
local $_=$a;
    my @eip= m/\bAllocationId: (eipalloc-\w+)/sg;
    print STDERR "DEBUG: In getUnusedEIP. \@eip=(",join(", ",@eip),")\n";

    local $FoundEIP=0;
    my ($EIPAllocationId,$EIP);
    foreach $EIPAllocationId (@eip){
      print STDERR "DEBUG: In getUnusedEIP.pl. aws ec2 describe-addresses --allocation-ids $EIPAllocationId\|$ThisDir/json2yaml.sh\n";
      local $_ = `aws ec2 describe-addresses --allocation-ids $EIPAllocationId|$ThisDir/json2yaml.sh`;
      if ( ! /AssociationId:/s ){
        print STDERR "DEBUG: In makeEIP. Found unused. EIPAllocationId=\"$EIPAllocationId\". Description is \"$_\"\n";
        $EIP=$1 if /PublicIp: (\d+(?:\.\d+){3})[^\d]/s;
        print STDERR "DEBUG: In makeEIP. Found unused. EIP=\"$EIP\", EIPAllocationId=\"$EIPAllocationId\".\n";
        $FoundEIP=1;
        last;
      }
    }
    die "FATAL ERROR: In makeEIP. While searching for unused EIP. None found.\n" if ! $FoundEIP;
return ($EIPAllocationId, $EIP);
}
#==========================================================================================================

1;
