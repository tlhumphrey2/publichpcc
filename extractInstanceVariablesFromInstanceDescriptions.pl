#!/usr/bin/perl
=pod
=cut

$region="eu-west-1";
$stackname="HaaS-20190111-2";
InstanceVariablesFromInstanceDescriptions($region,$stackname);

$OutputOnceVariables{"HPCCPlatform"}=1;
$OutputOnceVariables{"pem"}=1;
$OutputOnceVariables{"roxienodes"}=1;
$OutputOnceVariables{"slavesPerNode"}=1;

my %InstanceVariable=%{$sorted_InstanceInfo[0]};
print "# Instance Variables outputted once:\n";
foreach (sort keys %OutputOnceVariables){
  print "$_=$InstanceVariable{$_}\n";
}
print "\n";

print "# Arrays of Instance Variables:\n";
for( my $i=0; $i < scalar(@sorted_InstanceInfo); $i++){
  my %InstanceVariable=%{$sorted_InstanceInfo[$i]};
  foreach my $v (@InstanceVariable){
    $display_v = ($v eq 'Name')? 'nodetype' : $v ;
    print "$display_v\[$i\]=$InstanceVariable{$v}\n" if ! $OutputOnceVariables{$v};
  }
}
#------------------------------------------------------------------------
sub InstanceVariablesFromInstanceDescriptions{
my ($region,$stackname)=@_;
#$re1="(^    - DeviceName: |^        VolumeId: |^    InstanceId: |^    InstanceType: |^    PrivateIpAddress: |^    PublicIpAddress: |^    - {Key: slavesPerNode, Value: '|^    - {Key: HPCCPlatform, Value: |^    - {Key: roxienodes, Value: '|^    - {Key: pem, Value: |^    - {Key: Name, Value: $stackname--|^    State: {Code: \\d+, Name: )";
$re1="(^    - {Key: Name, Value: $stackname--|^    State: {Code: \\d+, Name: |^    - DeviceName: |^        VolumeId: |^    InstanceId: |^    InstanceType: |^    PrivateIpAddress: |^    PublicIpAddress: |^    - {Key: slavesPerNode, Value: '|^    - {Key: HPCCPlatform, Value: |^    - {Key: roxienodes, Value: '|^    - {Key: pem, Value: )";
$_=`aws ec2 describe-instances --region $region --filter "Name=tag:StackName,Values=$stackname"|./json2yaml.sh`;
#print "DEBUG: Size of input is \"",length($_),"\"\n";
$stackname="HaaS-20190111-2";
@instance_description= $_ =~ m/\n(  Instances:\n.+?\n  ReservationId:[^\n]+)/gs;
#print "DEBUG: scalar(\@instance_description)=",scalar(@instance_description),"\n";
for( my $i=0; $i < scalar(@instance_description); $i++){
  local $_=$instance_description[$i];
  $description[$i]=extractLines($_);
}
#print "DEBUG: OUTPUT: scalar(\@description)=",scalar(@description),"\n";
my $re2=$re1;
$re2 =~ s/Key: (\w+)/$1:/g;
$re2 =~ s/[^\(\|]+?(\w+):/$1/g;
$re2 =~ s/[^\(\)\|\w]+?//g;
$re2 =~ s/Value[^\|\(\)]*//g;
$re2 =~ s/StateCodeName/State/;
#print "DEBUG: 1. re2=\"$re2\"\n";
$v=$re2; $v=~s/\|/,/g;
eval("\@InstanceVariable=$v");
$re2='\b'.$re2.'\b';
#print "DEBUG: 2. re2=\"$re2\"\n";
#print "DEBUG: \@InstanceVariable=(@InstanceVariable)\n";

for( my $i=0; $i < scalar(@description); $i++){
  my %InstanceVariable=();
  #print "DEBUG: Instance\[$i\]:\n";
  foreach my $line (@{$description[$i]}){
    $l = spaces2dots($1,$line) if $line=~/^( +)/;
    #print "DEBUG: i=$i line:$l\n";
    if ($line =~ /$re1(.*)(?:'?})?/){
      my $s=$1;
      my $value=$2;
      $value=~s/'}\s*$|}\s*$//;
      #print "DEBUG: s=\"$s\", value=\"$value\"\n";
      if ($s =~ /$re2/){
	my $key=$1;
	#$key =~ s/([A-Z]+)/\L$1/g;
        $InstanceVariable{$key}=$value;
	#print "DEBUG: \$InstanceVariable\{$1\}=\"$value\"\n";
      }
      else{
        print "ERROR: Found string=\"$s\", in line=\"$line\", BUT NO variable found.\n";
      }
    }
  }
  $InstanceInfo[$i]=\%InstanceVariable;
}

@sorted_InstanceInfo=sort { HashValue($a,'Name','a') cmp HashValue($b,'Name','b') } @InstanceInfo;
}
#===================================================================
sub HashValue{
my ($varPtr,$key, $ab)=@_;
 my %InstanceVariable=%{$varPtr};
#print "DEBUG: In HashValue. ab=\"$ab\", key=\"$key\", value=\"$InstanceVariable{$key}\"\n";
return $InstanceVariable{$key}; 
}
#===================================================================
sub spaces2dots{
my ($s,$line)=@_;
$s =~ s/ /./g;
$line=~s/^ +//;
return $s.$line;
}
#===================================================================
sub extractLines{
my ($d)=@_;
my @line=split(/\n+/,$d);
#print "In extractLines. Number of lines is ",scalar(@line),"\n";
@line=grep(!/^\s*$/,@line);
#print "In extractLines. After removing blank lines. Number of lines is ",scalar(@line),"\n";
return \@line;
}
