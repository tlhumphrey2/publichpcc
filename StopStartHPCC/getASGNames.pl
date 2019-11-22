#!/usr/bin/perl
sub getASGNames{
my ( $region, $stackname, $filter )=@_;
print "\$asgnames=aws autoscaling describe-auto-scaling-groups --region $region\n";
$_=`aws autoscaling describe-auto-scaling-groups --region $region`;

# 2 greps. Inter-most gets only lines containing both 'AutoScalingGroupARN' and $stackname. The out-most grep
# extracts just the ASG name. All names are put in @asgnames.
@asgnames=grep($_=extractASGName($_),grep(/\"AutoScalingGroupARN\":.+$stackname/,split(/\n+/,$_)));
print "asgnames=(",join(",",@asgnames),")\n";

@asgnames = grep(/$filter,@asgnames) if $filter !~ /^\s*$/;

return @asgnames;
  sub extractASGName{
  my ( $a )=@_;
  local $_=$a;
    s/^.*autoScalingGroupName\///;# Remove everything before ASG name
    s/",\s*$//;                   # Remove everything after ASG name
  return $_;
  }
}
