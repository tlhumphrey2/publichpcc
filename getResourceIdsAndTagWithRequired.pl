#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "$ThisDir/getConfigurationFile.pl";
require "$ThisDir/cf_common.pl";
require "$ThisDir/common.pl";

=pod
USAGE EXAMPLE:
getResourceIdsAndTagWithRequired.pl

NOTE: You can have an email address as one commandline argument. If you don't have one then the email is assumed to be mine, i.e.
      timothy.humphrey@lexisnexisrisk.com
WHAT THIS SCRIPT DOES:
0. Get all tags and their default values from TagsAndValues.txt
1. Uses describe-instances, filtering on $stackname, get descriptions of all instances
2. Extract ids of all autoscaling groups using the following and put in a file. Plus, run the ASG tagger, tagASGs.sh:
   egrep "$stackname.*ASG-" $stackname-instance-descriptions.json|sed -e "s/^  *\"Value\": \"//" -e "s/\", *$//"|sort|uniq
3. Then we do the following to 1) get only lines the contain resource IDs, 2) sort then and 3) remove everything but the resource type and the resource IDs(separated by a comma): egrep "Id\":" $stackname-instance-descriptions.json|egrep -v "\"RequesterId\":|\"ReservationId\":|\"OwnerId\":|\"AttachmentId\":|\"ImageId\":|\"Id\":|\"IpOwnerId\":"|sed "s/^  *//"|sort|uniq|sed -e "s/\"//g" -e "s/: /,/" -e "s/, *$//" -e "s/^GroupId,/SG,/" -e "s/Id,/,/". The list should look like the following:
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
4. Then for each ResourceType,ResourceId/line, I create a line that looks like the following:
$resource_id,$region,research,research,research,$stackname,$resource_type,dev,$email,$email
5. Then I put these in a file called ResourceAndRequiredTags.csv, where the 1st line of the file is the following:
resource_id,region,market,product,application,project,service,lifecycle,owner_email,support_email
6. The last thing I do is call tag-resources.pl to add the required tags to all resources. This call looks like:
$ThisDir/tag-resources.pl $ThisDir/ResourceAndRequiredTags.csv
7. Tag the s3 bucket, $stackname
=cut
my $email = (scalar(@ARGV) > 0)? shift @ARGV : 'timothy.humphrey@lexisnexisrisk.com' ;

# 0. Get all tags and their default values from TagsAndValues.txt
my ($TagsAndValuesRef,$TagArrayRef) = getAllTagsAndValues("$ThisDir/TagsAndValues.txt");
$TagsAndValuesRef->{'owner_email'} = "'".$email."'";
$TagsAndValuesRef->{'support_email'} = "'".$email."'";
$TagsAndValuesRef->{'application'} = "'".$stackname."'";
print "In getResourceIdsAndTagWithRequired.pl. TagsAndValues=(",getTagsAndValues($TagsAndValuesRef,$TagArrayRef),")\n";
sub getTagsAndValues{
my ($TagsAndValuesRef,$TagArrayRef)=@_;
  my $s = '';
  foreach my $tag (@$TagArrayRef){
	  $s .= "$tag,$TagsAndValuesRef->{$tag} ";
  }
  return $s;
}

$instance_descriptions_file="$ThisDir/tagging-$stackname-instance-descriptions.json";
# 1. Uses describe-instances, filtering on $stackname, get descriptions of all instances
print "In getResourceIdsAndTagWithRequired.pl: aws ec2 describe-instances --region $region --filter \"Name=tag:StackName,Values=$stackname\" > $ThisDir/$instance_descriptions_file\n";
$_=`aws ec2 describe-instances --region $region --filter "Name=tag:StackName,Values=$stackname" > $instance_descriptions_file`;
my $idescriptions =`cat $instance_descriptions_file`;
my @idline=split(/\n/,$idescriptions);

# 2. Extract ids of all autoscaling groups and put in a file. Then, run the ASG tagger, tagASGs.sh to tag all of them.
print "Extract ids of all autoscaling groups and put in a file. Then, run the ASG tagger, tagASGs.sh to tag all of them.\n";
$_ = `aws autoscaling describe-auto-scaling-groups --region $region|egrep "AutoScalingGroupName.: .$stackname"|cut -d: -f 2`;
@asg_id = m/($stackname-[^"]+)/sg;
=pod
#Contents of $_ will look like the following:
 "mhpcc-ca-central-1-ndw-219-MasterASG-1493DNXL0HFZN", 
 "mhpcc-ca-central-1-ndw-219-RoxieASG-1WEBICIY37T9H", 
 "mhpcc-ca-central-1-ndw-219-SlaveASG-1WU8ITYEZWN5C", 
=cut
open(OUT,">$stackname-autoscaling-groups-$region.txt") || die "Can't open for output: \"$stackname-autoscaling-groups-$region.txt\"\n";
print OUT join("\n",@asg_id),"\n";
close(OUT);

my $KeysAndValues = makeKeyValueString($TagsAndValuesRef,$TagArrayRef);
print "$ThisDir/tagASGs.sh $region $stackname-autoscaling-groups-$region.txt \"$KeysAndValues\" &> $ThisDir/$stackname-autoscaling-groups-$region.log\n";
$_=`$ThisDir/tagASGs.sh $region $stackname-autoscaling-groups-$region.txt "$KeysAndValues" &> $ThisDir/$stackname-autoscaling-groups-$region.log`;

# 3. Then we do the following to 1) get only lines that contain resource IDs, 2) sort then and 3) remove everything but the resource type and the resource IDs(separated by a comma)
print "In getResourceIdsAndTagWithRequired.pl: From instance descriptions remove everything but resource types and resource ids.\n";
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
print "In getResourceIdsAndTagWithRequired.pl: \nResourceTypeResourceId=",join("\nResourceTypeResourceId=",@ResourceTypeResourceId),"\n";

# 4. Then for each ResourceType,ResourceId/line, I create a line that looks like the following:
print "In getResourceIdsAndTagWithRequired.pl: Create contents of ResourceAndRequiredTags.csv\n";
@ResourceAndRequiredTags=("resource_id,region,".join(",",@$TagArrayRef));
print "In getResourceIdsAndTagWithRequired.pl: Header Row: \@ResourceAndRequiredTags=(",join(", ",@ResourceAndRequiredTags),")\n";
my @values = ();
foreach my $tag (@$TagArrayRef){
	push @values, $TagsAndValuesRef->{$tag};
}
my $values_string = join(",",@values);
print "In getResourceIdsAndTagWithRequired.pl: values_string=\"$values_string\"\n";
foreach (@ResourceTypeResourceId){
  next if /^\s*$/;
  my ($resource_type,$resource_id)=split(/,/,$_);
  $resource_type=~s/Id$//;
  my $line = "$resource_id,$region,$values_string";
  push @ResourceAndRequiredTags, $line;
}

# 5. Then I put these in a file called ResourceAndRequiredTags.csv, where the 1st line of the file is the following:
print "In getResourceIdsAndTagWithRequired.pl: Fill the file, $ThisDir/ResourceAndRequiredTags.csv with contents of \@ResourceAndRequiredTags\n";
open(OUT,">$ThisDir/ResourceAndRequiredTags.csv") || die "Can't open for output \"$ThisDir/ResourceAndRequiredTags.csv\"\n";
print OUT join("\n",@ResourceAndRequiredTags),"\n";
close(OUT);

# 6. The last thing to do is call tag-resources.pl to add the required tags to all resources. This call looks like:
print "In getResourceIdsAndTagWithRequired.pl: $ThisDir/tag-resources.pl $ThisDir/ResourceAndRequiredTags.csv\n";
$_=`$ThisDir/tag-resources.pl $ThisDir/ResourceAndRequiredTags.csv 2>&1`;
print "In getResourceIdsAndTagWithRequired.pl: RC of tag-resources.pl is \"$_\"\n";
# 7. Tag the s3 bucket, $stackname
# Change "key" to "Key" and "value" to "Value"
print "$ThisDir/tagOneS3Bucket.sh $stackname \"$KeysAndValues\" &> $ThisDir/$stackname-tagOneS3Bucket.log\n";
$_=`$ThisDir/tagOneS3Bucket.sh $stackname "$KeysAndValues" &> $ThisDir/$stackname-tagOneS3Bucket.log`;
#============================================
sub uniq{
my (@asg_id)=@_;
  my @uniq = ();
  my %asg_id = ();
  foreach (@asg_id){
     if ( ! exists($asg_id{$_}) ){
	     $asg_id{$_} = 1;
	     push @uniq, $_;
     }
  }
  return @uniq;
}
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
