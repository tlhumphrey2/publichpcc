#!/usr/bin/perl
$ThisDir=($0 =~ /^(.+)[\\\/]/)? $1 : "." ;
require "$ThisDir/ClusterInitVariables.pl";

# Note: If ASG is given then it must be either RoxieASG or SlaveASG
$ASG = (scalar(@ARGV) > 0)? shift @ARGV : '';
print "DEBUG: Entering suspendASGProcesses.pl name=\"$name\", master_name=\"$master_name\", other_name=\"$other_name\", region=\"$region\", ASG=\"$ASG\".\n";

if ( ! defined($stackname) || ($stackname=~/^\s*$/) ){
  if (defined($master_name) && ($master_name!~/^\s*$/) ){
    $stackname=$1 if $master_name =~ /^(.+)\-\-/;
  }
  elsif (defined($other_name) && ($other_name!~/^\s*$/) ){
    $stackname=$1 if $other_name =~ /^([^,]+)\-\-/; # [^,]++ is used here because there could be more than 1 name separated by commas.
  }
}

print "\$asgnames=aws autoscaling describe-auto-scaling-groups --region $region\|egrep AutoScalingGroupARN\|sed -e \"s/^.*autoScalingGroupName//\" -e \"s/\", *//\"\|egrep $stackname\n";
$_=`aws autoscaling describe-auto-scaling-groups --region $region`;

# 2 greps. Inter-most gets only lines containing both 'AutoScalingGroupARN' and $stackname. The out-most grep
# extracts just the ASG name. All names are put in @asgnames.
@asgnames=grep($_=extractASGName($_),grep(/\"AutoScalingGroupARN\":.+$stackname/,split(/\n+/,$_)));
print "asgnames=(",join(",",@asgnames),")\n";

sub extractASGName{
my ( $a )=@_;
local $_=$a;
  s/^.*autoScalingGroupName\///;# Remove everything before ASG name
  s/",\s*$//;                   # Remove everything after ASG name
return $_;
}
#-----------------------------------------------------------------------------------------------------
# For each autoscaling group whose name is in $asgnames, suspend these processes: Launch Terminate HealthCheck
foreach my $asgname (@asgnames){
  next if $asgname=~/^\s*$/;
  if ( $ASG ne '' ){
    if ( $asgname =~ /$stackname\-$ASG/ ){
      print "aws autoscaling suspend-processes --auto-scaling-group-name $asgname --scaling-processes Launch Terminate HealthCheck --region $region\n";
      my $rc=`aws autoscaling suspend-processes --auto-scaling-group-name $asgname --scaling-processes Launch Terminate HealthCheck --region $region`;
      print "$rc\n";
    }
  }
  else{
    print "aws autoscaling suspend-processes --auto-scaling-group-name $asgname --scaling-processes Launch Terminate HealthCheck --region $region\n";
    my $rc=`aws autoscaling suspend-processes --auto-scaling-group-name $asgname --scaling-processes Launch Terminate HealthCheck --region $region`;
    print "$rc\n";
  }
}
#================================================
sub appendStatement2ClusterInitVariables{
my ($line2add)=@_;
  my $save_delim=$/;
  $/="";
  open(IN, "$ThisDir/ClusterInitVariables.pl") || die "Can't open for input \"$ThisDir/ClusterInitVariables.pl\"\n";
  local $_=<IN>;
  s/\n1;\s*$//;
  close(IN);

  $_ .= "\n$line2add\n1;";

  open(OUT,">$ThisDir/ClusterInitVariables.pl") || die "Can't open for output \"$ThisDir/ClusterInitVariables.pl\"\n";
  print OUT $_;
  close(OUT);
}
