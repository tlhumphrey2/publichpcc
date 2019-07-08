#!/usr/bin/perl
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
  print "In getTerminatedIPAndNewIP. In getTerminatedIPAndNewIP. MasterIP=\"$MasterIP\"\n";
  # Get all private IPs of environment.xml file and put in file, tt2. Then make array @tt2. Make regexp $re_tt2.
  print "ssh -o StrictHostKeyChecking=no -i $pem $sshuser\@$MasterIP \"/opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -machines\" \> tt2\n";
  my $rc0=`ssh -o StrictHostKeyChecking=no -i $pem $sshuser\@$MasterIP "/opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -machines" > tt2`;
  print "In getTerminatedIPAndNewIP. rc0=\"$rc0\"\n";
  my $tt2=`cat tt2|sed -e "s/,.*\$//"`; print "In getTerminatedIPAndNewIP. tt2=\"$tt2\"\n";
  my @tt2=split(/\n/,$tt2); @tt2=grep(/\d+(?:\.\d+){3}/,@tt2); shift @tt2; grep(s/[^\d\.]//g,@tt2);
  print "In getTerminatedIPAndNewIP. \@tt2=(",join("\n",@tt2),")\n";

  # Get current private ips and remove master's ip (i.e. shift @pri_ips). Make regex $re_pri_ips.
  my $pri_ips=`cat $private_ips`;print "In getTerminatedIPAndNewIP. pri_ips=\"$pri_ips\"\n";
  my @pri_ips=split(/\n/,$pri_ips); @pri_ips=grep(/\d+(?:\.\d+){3}/,@pri_ips);shift @pri_ips; print "In getTerminatedIPAndNewIP. \@pri_ips=(",join(",",@pri_ips),")\n";
  my $re_pri_ips=join("|",@pri_ips);print "In getTerminatedIPAndNewIP. re_pri_ips=\"$re_pri_ips\"\n";

  #Get ip that is being replaced by new ip because it terminated.
  my $terminated_ip; ($terminated_ip)=grep( ! /$re_pri_ips/, @tt2);
  print "In getTerminatedIPAndNewIP. terminated_ip=\"$terminated_ip\", new_ip=\"$new_ip\"\n";
return $terminated_ip;
}
#==========================================================================================================
sub InstanceVariablesFromInstanceDescriptions{
my ($region,$stackname)=@_;
my $re1="(^    - {Key: Name, Value: $stackname--|^    State: {Code: \\d+, Name: |^    - DeviceName: |^        VolumeId: |^    InstanceId: |^    InstanceType: |^    PrivateIpAddress: |^    PublicIpAddress: |^    - {Key: slavesPerNode, Value: '|^    - {Key: HPCCPlatform, Value: |^    - {Key: roxienodes, Value: '|^    - {Key: pem, Value: )";
$_=`aws ec2 describe-instances --region $region --filter "Name=tag:StackName,Values=$stackname"|$ThisDir/json2yaml.sh|tee $ThisDir/$stackname-instance-descriptions.yaml`;
print "DEBUG: In InstanceVariablesFromInstanceDescriptions. Size of input is \"",length($_),"\"\n";

# Get all instance descriptions in the array @instance_description.
my @instance_description= $_ =~ m/\n(  - AmiLaunchIndex:.+?\n    VirtualizationType:[^\n]+)/gs;
print "DEBUG: In InstanceVariablesFromInstanceDescriptions. Number of instance descriptions (scalar(\@instance_description)) is ",scalar(@instance_description),"\n";
my @description=();
for( my $i=0; $i < scalar(@instance_description); $i++){
  local $_=$instance_description[$i];
  $description[$i]=extractLines($_);
}
print "DEBUG: In InstanceVariablesFromInstanceDescriptions. OUTPUT: scalar(\@description)=",scalar(@description),"\n";
my $re2=$re1;
$re2 =~ s/Key: (\w+)/$1:/g;
$re2 =~ s/[^\(\|]+?(\w+):/$1/g;
$re2 =~ s/[^\(\)\|\w]+?//g;
$re2 =~ s/Value[^\|\(\)]*//g;
$re2 =~ s/StateCodeName/State/;
print "DEBUG: In InstanceVariablesFromInstanceDescriptions. 1. re2=\"$re2\"\n";
my $v=$re2; $v=~s/\|/,/g;
eval("\@InstanceVariable=$v");
$re2='\b'.$re2.'\b';
print "DEBUG: In InstanceVariablesFromInstanceDescriptions. 2. re2=\"$re2\"\n";
print "DEBUG: In InstanceVariablesFromInstanceDescriptions. \@InstanceVariable=(@InstanceVariable)\n";

my @InstanceInfo=();
for( my $i=0; $i < scalar(@description); $i++){
  my %InstanceVariable=();
  print "DEBUG: In InstanceVariablesFromInstanceDescriptions. Instance\[$i\]:\n";
  foreach my $line (@{$description[$i]}){
    my $l = spaces2dots($1,$line) if $line=~/^( +)/;
    #print "DEBUG: In InstanceVariablesFromInstanceDescriptions. i=$i line:$l\n";
    if ($line =~ /$re1(.*)(?:'?})?/){
      my $s=$1;
      my $value=$2;
      $value=~s/'}\s*$|}\s*$//;
      print "DEBUG: In InstanceVariablesFromInstanceDescriptions. s=\"$s\", value=\"$value\"\n";
      if ($s =~ /$re2/){
        my $key=$1;
        $InstanceVariable{$key}=$value;
        print "DEBUG: In InstanceVariablesFromInstanceDescriptions. \$InstanceVariable\{$key\}=\"$value\"\n";
      }
      else{   
        print "ERROR: Found string=\"$s\", in line=\"$line\", BUT NO variable found.\n";
      }
    }
  }
  $InstanceInfo[$i]=\%InstanceVariable;
}

my @sorted_InstanceInfo=sort { HashValue($a,'Name','a') cmp HashValue($b,'Name','b') } @InstanceInfo;
print "Leaving InstanceVariablesFromInstanceDescriptions. Size of \@sorted_InstanceInfo=",scalar(@sorted_InstanceInfo),"\n";
return @sorted_InstanceInfo;
}
#==========================================================================================================
sub putHPCCInstanceInfoInFiles{
my ($ref_sorted_InstanceInfo)=@_;
   my @sorted_InstanceInfo=@$ref_sorted_InstanceInfo;
   print "Entering putHPCCInstanceInfoInFiles. scalar(\@sorted_InstanceInfo)=\"",scalar(@sorted_InstanceInfo),"\"\n";
   #------------------------------------------------------------------------------------
   # Get Instance Ids, private_ips, public_ips, and nodetypes of ONLY HPCC instances
   #------------------------------------------------------------------------------------
   my (@InstanceIds, @private_ips, @public_ips, @nodetypes);
   for( my $i=0; $i < scalar(@sorted_InstanceInfo); $i++){
     my %InstanceVariable=%{$sorted_InstanceInfo[$i]};
     print "In putHPCCInstanceInfoInFiles. InstanceVariable{'nodetype'}=\"$InstanceVariable{'nodetype'}\"\n";
     if (($InstanceVariable{'State'} eq 'running') && ($InstanceVariable{'Name'} ne 'Bastion')){
       push @InstanceIds, $InstanceVariable{'InstanceId'};
       push @private_ips, $InstanceVariable{'PrivateIpAddress'};
       push @public_ips, $InstanceVariable{'PublicIpAddress'};
       push @nodetypes, $InstanceVariable{'Name'};
     }
   }
   print "In putHPCCInstanceInfoInFiles. scalar(\@InstanceIds)=\"",scalar(@InstanceIds),"\"\n";

   #------------------------------------------------------------------------------------
   # Put Instance Ids of HPCC System in the file, $instance_ids.
   #------------------------------------------------------------------------------------
   open(OUT,">$instance_ids") || die "Can't open for output: \"$instance_ids\"\n";
   for( my $i=0; $i < scalar(@InstanceIds); $i++){
     print "In putHPCCInstanceInfoInFiles. OUTPUT InstanceIds\[$i\]=$InstanceIds[$i]\n";
     print OUT "$InstanceIds[$i]\n";
   }
   close(OUT);
   
   #------------------------------------------------------------------------------------
   # Put private ips of HPCC System in the file, $private_ips.
   #------------------------------------------------------------------------------------
   open(OUT,">$private_ips") || die "Can't open for output: \"$private_ips\"\n";
   for( my $i=0; $i < scalar(@private_ips); $i++){
     print "In putHPCCInstanceInfoInFiles. OUTPUT private_ips\[$i\]=$private_ips[$i]\n";
     print OUT "$private_ips[$i]\n";
   }
   close(OUT);
   
   #------------------------------------------------------------------------------------
   # Put public ips of HPCC System in the file, $public_ips.
   #------------------------------------------------------------------------------------
   open(OUT,">$public_ips") || die "Can't open for output: \"$public_ips\"\n";
   for( my $i=0; $i < scalar(@public_ips); $i++){
     print "In putHPCCInstanceInfoInFiles. OUTPUT public_ips\[$i\]=$public_ips[$i]\n";
     print OUT "$public_ips[$i]\n";
   }
   close(OUT);
   
   #------------------------------------------------------------------------------------
   # Put nodetypes of HPCC System in the file, $nodetypes.
   #------------------------------------------------------------------------------------
   open(OUT,">$nodetypes") || die "Can't open for output: \"$nodetypes\"\n";
   for( my $i=0; $i < scalar(@nodetypes); $i++){
     print "In putHPCCInstanceInfoInFiles. OUTPUT nodetypes\[$i\]=$nodetypes[$i]\n";
     print OUT "$nodetypes[$i]\n";
   }
   close(OUT);
}
#==========================================================================================================
sub extractLines{
my ($d)=@_;
my @line=split(/\n+/,$d);
#print "In extractLines. Number of lines is ",scalar(@line),"\n";
@line=grep(!/^\s*$/,@line);
#print "In extractLines. After removing blank lines. Number of lines is ",scalar(@line),"\n";
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
 print "Entering getRunningNoneBastionInstances. region=\"$region\",stackname=\"$stackname\"\n";
 my @sorted_InstanceInfo=InstanceVariablesFromInstanceDescriptions($region,$stackname);

 my @ii=();
 for( my $i=0; $i < scalar(@sorted_InstanceInfo); $i++){
   my %InstanceVariable=%{$sorted_InstanceInfo[$i]};
   if (($InstanceVariable{'State'} eq 'running') && ($InstanceVariable{'Name'} ne 'Bastion')){
     print "Found running none Bastion instance. InstanceVariable{'Name'}=\"$InstanceVariable{'Name'}\"\n";
     push @ii, \%InstanceVariable;
   }
 }
 print "Leaving getRunningNoneBastionInstances. Size of \@ii is ",scalar(@ii),"\n";
return @ii;
}
#===================================================================
sub HashValue{
my ($varPtr,$key, $ab)=@_;
 my %InstanceVariable=%{$varPtr};
print "DEBUG: In HashValue. ab=\"$ab\", key=\"$key\", value=\"$InstanceVariable{$key}\"\n";
return $InstanceVariable{$key}; 
}
#==========================================================================================================
sub makeEIP{
my ($region, $stackname, $s3bucket)=@_;
  local $EIP;
  local $EIPAllocationId;

  # Make EIP for vpc domain
  print "aws ec2 allocate-address --domain vpc --region $region\n";
  local $_=`aws ec2 allocate-address --domain vpc --region $region 2>&1`;

  print "In makeEIP. allocate-address rc=\"$_\"\n";

  # If maximum number of addresses has been reached. Find EIP that isn't being used.
  if ($_ =~ /The maximum number of addresses has been reached/s){
    print "In makeEIP. Maximum number of addresses has been reached.\n";
    print "In makeEIP: aws ec2 describe-addresses --region $region|./json2yaml.sh\n";
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
    print "In makeEIP. Created. EIP=\"$EIP\", EIPAllocationId=\"$EIPAllocationId\".\n";
  }


  # Put $EIPAllocationId in a file named "EIPAllocationId" and put file is s3 bucket, $s3bucket
  print "Put $EIPAllocationId in the $ThisDir/EIPAllocationId and place file is s3bucket, $s3bucket\n";
  putInFileAndStoreInS3Bucket("$ThisDir/EIPAllocationId", $EIPAllocationId, $s3bucket );

  # Put EIP and EIPAllocationId in configuration file
  print "In makeEIP. echo \"EIP=$EIP\" \>\> $ThisDir/cfg_BestHPCC.sh\n";
  my $rc=`echo "EIP=$EIP" >> $ThisDir/cfg_BestHPCC.sh 2>&1`;
  print "In makeEIP. rc for putting EIP in cfg_BestHPCC.sh is \"$rc\"\n";
  print "In makeEIP. echo \"EIPAllocationId=$EIPAllocationId\" \>\> $ThisDir/cfg_BestHPCC.sh\n";
  my $rc=`echo "EIPAllocationId=$EIPAllocationId" >> $ThisDir/cfg_BestHPCC.sh 2>&1`;
  print "In makeEIP. rc for putting EIPAllocationId in cfg_BestHPCC.sh is \"$rc\"\n";

  print "In makeEIP:aws ec2 create-tags --resources $EIPAllocationId --tags \"Key=Name,Value=$stackname\" --region $region\n";
  my $rc=`aws ec2 create-tags --resources $EIPAllocationId --tags "Key=Name,Value=$stackname" --region $region`;
  print "In makeEIP. 'create-tags' rc is \"$rc\"\n";

  print "Leaving makeEIP. EIP=\"$EIP\", EIPAllocationId=\"$EIPAllocationId\"\n";
  return $EIP;
}
#==========================================================================================================
sub sendMail{
my ($from, $to, $subject, $body, $to_filepath, $email_filepath)=@_;
print "Entering sendMail. from=\"$from\", to=\"$to\", subject=\"$subject\", body=\"$body\", to_filepath=\"$to_filepath\", email_filepath=\"$email_filepath\"\n";

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

print "In sendMail. aws ses send-email --from $from --destination file://$to_filepath --message file://$email_filepath --region us-east-1\n";
my $rc=`aws ses send-email --from $from --destination file://$to_filepath --message file://$email_filepath --region us-east-1`;
print "In sendMail. aws ses send-email rc=\"$rc\"\n";
}
#==========================================================================================================
sub put2file{
my ($outfile, $content)=@_;
open(OUT,">$outfile") || die "In $0. Can't open for output: \"$outfile\"\n";
print OUT "$content\n";
close(OUT);
}
#==========================================================================================================
sub AlertUserOfChangeInRunStatus{
my ($email,$message)=@_;
  my $toJsonFile="$ThisDir/toFileRunStatusChange.json";
  my $emailJsonFile="$ThisDir/emailFileRunStatusChange.json";
  
  sendMail($email, $email, $message, $message, $toJsonFile, $emailJsonFile);
}
#==========================================================================================================
sub putInFileAndStoreInS3Bucket{
my ($outfile, $content, $s3bucket)=@_;
put2file($outfile,$content);

my $filename=`basename $outfile`; chomp $filename;
print "In putInFileAndStoreInS3Bucket. aws s3 cp $outfile s3://$s3bucket/$filename\n";
my $rc=`aws s3 cp $outfile s3://$s3bucket/$filename 2>&1`;
print "In putInFileAndStoreInS3Bucket. cp $outfile to s3 bucket, $s3bucket. rc=\"$rc\"\n";
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
  foreach (@line){
    if ( /\b($re_component)\b.* is running/ ){
      $Running{$1}=1;
    }
  }

  my $NumberRunning=scalar(keys %Running);
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
sub getMasterEIP{
my ($region, $EIPAllocationId)=@_;
print "Entering getMasterEIP. region=\"$region\", EIPAllocationId=\"$EIPAllocationId\".\n";
print "In getMasterEIP: aws ec2 describe-addresses --allocation-ids $EIPAllocationId --region $region|$ThisDir/json2yaml.sh\n";
local $_=`aws ec2 describe-addresses --allocation-ids $EIPAllocationId --region $region|$ThisDir/json2yaml.sh`;
my $ip=$1 if /PublicIp: (\d+(?:\.\d+){3})/s;
print "Leaving getMasterEIP. ip=\"$ip\".\n";
return $ip;
}
#==========================================================================================================
sub getUnusedEIP{
my ($a)=@_;
local $_=$a;
    my @eip= m/\bAllocationId: eipalloc.+?(?=\bAllocationId: eipalloc|$)/sg;
    print "Before removing assigned: ";for( my $i=0; $i < scalar(@eip); $i++){ print "eip $i is \"$eip[$i]\"\n\n"; }
    @eip=grep(!/InstanceId:/,@eip);
    print "After removing assigned: ";for( my $i=0; $i < scalar(@eip); $i++){ print "eip $i is \"$eip[$i]\"\n\n"; }

    local $FoundEIP=0;
    foreach (@eip){
      if ( /\bAllocationId: (eipalloc-\w+)\b.*\bvpc\b.* PublicIp: (\d+(?:\.\d+){3})/s ){
        $EIPAllocationId=$1;
        $EIP=$2;
        print "In makeEIP. Found unused. EIP=\"$EIP\", EIPAllocationId=\"$EIPAllocationId\".\n";
	$FoundEIP=1;
        last;
      }
    }
    die "FATAL ERROR: In makeEIP. While searching for unused EIP. None found.\n" if ! $FoundEIP;
return ($EIPAllocationId, $EIP);
}
#==========================================================================================================

1;
