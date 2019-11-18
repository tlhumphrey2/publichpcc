#!/usr/bin/perl
#=====================================================================
# $stackname_prefix is all of the prefix except the last dash and the
#  digits that follow (just to the right of) it.
# This routine finds all the StackNames with the prefix of $stackname_prefix
#  that were gotten by "aws cloudformation list-stacks". Sorts then
#  and returns 1 more than the one with the largest digits.
sub NextStackNumber{
my ($stackname_prefix,$region)=@_;
$x=`aws cloudformation list-stacks --region $region`;
@x=split(/\n/,$x);
@y=grep(/"StackName": "$stackname_prefix/,@x);
@z = sort { RMN($a) <=> RMN($b)} @y; # Do numeric sort on just the right most number
$hnum_sname = ( $z[$#z] =~ /$stackname_prefix-(\d+)/ )? $1+1 : 1 ;
return $hnum_sname;
}
#====================================
# Gets the number at the end of a string(i.e. right most end).
sub RMN{
my ( $s )=@_;
# e.g. input '            "StackName": "XPertHR-ML-2016-02-19-2", '
local $_=($s=~/\"StackName": \"([^\"]+)\"/)? $1 : '';
#print "DEBUG: Entering RMN. s=\"$_\"\n";
my $n=(/^.*?(\d+)$/)? $1 : '' ;
#print "DEBUG: Leaving RMN. n=\"$n\"\n";
return $n;
}
#=====================================================================
sub getHPCCInstanceIds{
my ( $region, $stackname )=@_;
# Get just instances with tag:Name Value of "$stackname--*"
my $t=`aws ec2 describe-instances --region $region --filter "Name=tag:Name,Values=$stackname--*"`;
my @t=split("\n",$t);
#print "DEBUG: length of instance with stackname = \"$stackname\" is ",`wc -c t`,"\n";

my $HPCCNodeTypes_re='(?:Master|Slave|Roxie)';
my $m_re="$stackname--($HPCCNodeTypes_re)|InstanceId.:";
my @x=grep(/$m_re/,@t);
# reverse list if first entry isn't a HPCC node type. We want the list to be node type following by instance_id, ... 
@x=reverse @x if $x[0] !~ /$HPCCNodeTypes_re/;
for( my $i=0; $i < scalar(@x); $i++){
  local $_=$x[$i];
  if ( /$stackname--Master/ ){
     push @master, $x[$i+1]; # push master instance_id
  }
  elsif ( /$stackname--Slave/ ){
     push @slave, $x[$i+1]; # push master instance_id
  }
  elsif ( /$stackname--Roxie/ ){
     push @roxie, $x[$i+1]; # push master instance_id
  }
}
@x=(@master,@slave,@roxie);

# Remove everything but instance id.
@x=grep(s/^.+InstanceId\":\s\"([^\"]+)\".*$/$1/,@x);
#print "DEBUG: instance ids=(",join(",",@x),")\n";
return @x;
}
#=====================================================================
1;
