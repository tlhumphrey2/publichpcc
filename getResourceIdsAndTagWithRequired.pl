#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
=pod
USAGE EXAMPLE:
getResourceIdsAndTagWithRequired.pl $stackname $region
WHAT THIS SCRIPT DOES:
1. Uses describe-instances, filtering on $stackname, get descriptions of all instances
2. Then we do the following to 1) get only lines the contain resource IDs, 2) sort then and 3) remove everything but the resource type and the resource IDs(separated by a comma): egrep "Id\":" $stackname-instance-descriptions.json|egrep -v "\"RequesterId\":|\"ReservationId\":|\"OwnerId\":|\"AttachmentId\":|\"ImageId\":|\"Id\":|\"IpOwnerId\":"|sed "s/^  *//"|sort|uniq|sed -e "s/\"//g" -e "s/: /,/" -e "s/, *$//" -e "s/^GroupId,/SG,/" -e "s/Id,/,/". The list should look like the following:
      SG,sg-59888121
      SG,sg-5b888123
      Instance,i-00f91d30c45259a35
      Instance,i-858ad51f
      Instance,i-ce376854
      NetworkInterface,eni-77e6ad6f
      NetworkInterface,eni-8928de4d
      NetworkInterface,eni-9ba0d9c9
      Subnet,subnet-e90891b1
      Subnet,subnet-ea0891b2
      Volume,vol-9944423c
      Volume,vol-aa35320f
      Volume,vol-c6353263
      Vpc,vpc-f27a9c95
3. Then for each ResourceType,ResourceId/line, I create a line that looks like the following:
$resource_id,$region,research,research,research,$stackname,$resource_type,dev,timothy.humphrey@lexisnexisrisk.com,timothy.humphrey@lexisnexisrisk.com
4. Then I put these in a file called ResourceAndRequiredTags.csv, where the 1st line of the file is the following:
resource_id,region,market,product,application,project,service,lifecycle,owner_email,support_email
5. The last thing I do is call tag-resources.pl to add the required tags to all resources. This call looks like:
$ThisDir/tag-resources.pl $ThisDir/ResourceAndRequiredTags.csv
=cut

#require "$ThisDir/getConfigurationFile.pl";
#require "$ThisDir/common.pl";

# Get commandline arguments
my $stackname=shift @ARGV;
my $region=shift @ARGV;

# 1. Uses describe-instances, filtering on $stackname, get descriptions of all instances
print "In getResourceIdsAndTagWithRequired.pl: aws ec2 describe-instances --region $region --filter \"Name=tag:StackName,Values=$stackname\".\n";
$_=`aws ec2 describe-instances --region $region --filter "Name=tag:StackName,Values=$stackname" > $ThisDir/$stackname-instance-descriptions.json`;

# 2. Then we do the following to 1) get only lines that contain resource IDs, 2) sort then and 3) remove everything but the resource type and the resource IDs(separated by a comma)
print "In getResourceIdsAndTagWithRequired.pl: From instance descriptions remove everything but resource types and resource ids.\n";
$_=`cat $stackname-instance-descriptions.json`;
my @idline=split(/\n/,$_);
@idline=grep(/Id\":/,@idline);
@idline=grep(!/\"RequesterId\":|\"ReservationId\":|\"OwnerId\":|\"AttachmentId\":|\"ImageId\":|\"Id\":|\"IpOwnerId\":/,@idline);
@idline=grep(s/^\s+//,@idline);
@idline=grep(s/\"//g,@idline);
@idline=grep(s/: /,/,@idline);
@idline=grep(s/,?\s*$//,@idline);
@idline=grep($_=GroupIdReplacedWithSG($_),@idline);
@idline=sort @idline;
my @ResourceTypeResourceId=();
my %ResourceTypeResourceId=();
foreach my $r (@idline){
  if ( ! exists($ResourceTypeResourceId{$r}) ){
    $ResourceTypeResourceId{$r}=1;
    push @ResourceTypeResourceId,$r;
  }
}

# 3. Then for each ResourceType,ResourceId/line, I create a line that looks like the following:
print "In getResourceIdsAndTagWithRequired.pl: Create contents of ResourceAndRequiredTags.csv\n";
@ResourceAndRequiredTags=("resource_id,region,market,product,application,project,service,lifecycle,owner_email,support_email");
foreach (@ResourceTypeResourceId){
  next if /^\s*$/;
  my ($resource_type,$resource_id)=split(/,/,$_);
  $resource_type=~s/Id$//;
  push @ResourceAndRequiredTags, "$resource_id,$region,research,research,research,$stackname,$resource_type,dev,timothy.humphrey\@lexisnexisrisk.com,timothy.humphrey\@lexisnexisrisk.com";
}

# 4. Then I put these in a file called ResourceAndRequiredTags.csv, where the 1st line of the file is the following:
print "In getResourceIdsAndTagWithRequired.pl: Fill the file, $ThisDir/ResourceAndRequiredTags.csv with contents of \@ResourceAndRequiredTags\n";
open(OUT,">$ThisDir/ResourceAndRequiredTags.csv") || die "Can't open for output \"$ThisDir/ResourceAndRequiredTags.csv\"\n";
print OUT join("\n",@ResourceAndRequiredTags),"\n";
close(OUT);

# 5. The last thing to do is call tag-resources.pl to add the required tags to all resources. This call looks like:
print "In getResourceIdsAndTagWithRequired.pl: $ThisDir/tag-resources.pl $ThisDir/ResourceAndRequiredTags.csv\n";
$_=`$ThisDir/tag-resources.pl $ThisDir/ResourceAndRequiredTags.csv`;
print "In getResourceIdsAndTagWithRequired.pl: RC of tag-resources.pl is \"$_\"\n";
#============================================
sub GroupIdReplacedWithSG{
my ($x)=@_;
local $_=$x;
 my $y=$_;
 if (/^GroupId,/){
  $y =~ s/^GroupId,/SG,/;
 }
return $y;
}
