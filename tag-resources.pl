#!/usr/bin/perl
=pod

# EXAMPLE OF HOW TO USE tag-resources.pl.
tag-resources.pl test-EasyFastHPCCoAWS-with-platform7-table.csv
OR
stackname=Ashoka;instance_id=i-6ec0895f;region=us-east-1
tag-resources.pl \
   -resource_id $instance_id \
   -region $region \
   -market research \
   -product research \
   -application hpccsystems \
   -project $stackname \
   -service instance \
   -lifecycle dev \
   -owner_email "timothy.humphrey@lexisnexisrisk.com" \
   -support_email "timothy.humphrey@lexisnexisrisk.com"

EXAMPLE OF INPUT TABLE
resource_id,region,  market,  product, application, project, service, lifecycle, owner_email, support_email
i-06abf5b5e88e3ec81,us-east-2,research,research,research,test-1,ec2,dev,timothy.humphrey@lexisnexisrisk.com,timothy.humphrey@lexisnexisrisk.com
i-0b4359cf57c8b3982,us-east-2,research,research,research,test-1,ec2,dev,timothy.humphrey@lexisnexisrisk.com,timothy.humphrey@lexisnexisrisk.com
vol-064063660d76ac16b,us-east-2,research,research,research,test-1,ebs,dev,timothy.humphrey@lexisnexisrisk.com,timothy.humphrey@lexisnexisrisk.com
vol-01762b86fbcff5772,us-east-2,research,research,research,test-1,ebs,dev,timothy.humphrey@lexisnexisrisk.com,timothy.humphrey@lexisnexisrisk.com
eipalloc-0ef9c68db21d1b990,us-east-2,research,research,research,test-1,eip,dev,timothy.humphrey@lexisnexisrisk.com,timothy.humphrey@lexisnexisrisk.com

In the above example table of resources and tags there are 2 instances, 2 volumes, and 1 EIP.

NOTES ABOUT INPUT:
1. Must have the column headers as the first line of the file.
2. Column headers after 'resource_id' and 'region' must be the names of tags.
3. Each column header must be followed by a comma (spaces after comma are optional).
4. Each column entry after column header line must be followed by a comma (spaces after comma are optional).
5. If a tag does not have a value there must still be a comma after the null value.
6. Tags with blank or no values do not tag a resource.
=cut

%tag_value=();
@tag_value=();
@column_header=();
@tag=();
#================== Get Arguments ================================
require "newgetopt.pl";
if ( ! &NGetOpt(
                "resource_id=s", "region=s",  "market=s",  "product=s",
                "application=s", "project=s", "service=s", "lifecycle=s", 
                "owner_email=s", "support_email=s"
               )
   )      # Add Options as necessary
{
  print STDERR "\n[$0] -- ERROR -- Invalid/Missing options...\n\n";
  print  "\n[$0] -- ERROR -- Invalid/Missing options...\n\n" if $debug;
  exit(1);
}
$resource_id=$opt_resource_id;
$region=$opt_region;
$market=$opt_market;
$product=$opt_product;
$application=$opt_application;
$project=$opt_project;
$service=$opt_service;
$lifecycle=$opt_lifecycle;
$owner_email=$opt_owner_email;
$support_email=$opt_support_email;
if ($resource_id!~/^s*$/){
  if (
      ($region!~/^s*$/) &&
      ($market!~/^s*$/) &&
      ($product!~/^s*$/) &&
      ($application!~/^s*$/) &&
      ($project!~/^s*$/) &&
      ($service!~/^s*$/) &&
      ($lifecycle!~/^s*$/) &&
      ($owner_email!~/^s*$/) &&
      ($support_email!~/^s*$/)
     ){
   @tag=('market', 'product', 'application', 'project', 'service', 'lifecycle', 'owner_email', 'support_email');
   foreach (@tag){
     eval("\$v=\$$_");
     push @tag_value, $v;
#print "DEBUG: v=\"$v\", \$tag_value\[$#tag_value\]=\"$tag_value[$#tag_value]\"\n";
   }
   $tag_value{"$region,$resource_id"}=\@tag_value;
#print "DEBUG: region=\"$region\", resource_id=\"$resource_id\"\n";
   goto "TAGRESOURCES";
  }
  else{
    die "The argument, resource_id, is defined as \"$resource_id\", but not all other possible arguments are defined.\n";
  }
}
#================== END Get Arguments ================================

$line_no=1;

# Get tags and tag values as well as resource ids and regions from inputted cvs table
while(<>){
  my ($resource_id, $region);
  my @tag_value=();
  my @value=();
  chomp;
  s/\r//g;
  if ( $line_no == 1 ){
    # Get column headers
    @column_header=split(/\s*,\s*/,$_);
    @tag=@column_header[ 2..$#column_header ];
#print "DEBUG: line_no=\"$line_no\", \@tag=(",join(", ",@tag),")\n";  
  }
  else{
    # Get values of all tags
    @value=split(/\s*,\s*/,$_);
    $resource_id=$value[0];
    $region=$value[1];
    @tag_value=@value[ 2..$#value ];
    $tag_value{"$region,$resource_id"}=\@tag_value; 
#print "DEBUG: line_no=\"$line_no\", \@tag_value=(",join(", ",@tag_value),")\n";  
  }
  $line_no++;
}

TAGRESOURCES:
# Tag resources
#print "DEBUG: TAGRESOURCES\n";
my @key=sort keys %tag_value;
#print "DEBUG: Resources:\n";
foreach (@key){
#print "DEBUG: \$_=\"$_\"\n";
  my ($region, $resource_id)=split(/,/,$_);
#print "DEBUG: region=\"$region\", resource_id=\"$resource_id\"\n";
  my $tags=mkTagsAndTagValues(\@tag,$tag_value{$_});
  #print "DEBUG: aws ec2 create-tags --region $region --resources $resource_id --tags $tags\n";
  `aws ec2 create-tags --region $region --resources $resource_id --tags $tags &> create-tag-output.txt`;
  my $output=`cat create-tag-output.txt`;
  print "\"aws ec2 create-tags --region $region --resources $resource_id:\" rc=\"$output\"\n";
  $tags='';
}
#=============================================
sub mkTagsAndTagValues{
my ($tag_ref, $tag_value_ref)=@_;
  my @TagAndValue=();
  my @tag=@$tag_ref;
  my @tag_value=@$tag_value_ref;
#print "DEBUG: In mkTagsAndTagValues. num tags=",scalar(@tag),", num tag_values=",scalar(@tag_value),"\n";
  if ( scalar(@tag)!=scalar(@tag_value) ){
    print STDERR "NUMBER OF TAGS DOES NOT MATCH NUMBER OF TAG VALUES (",scalar(@tag),",",scalar(@tag_value),")\n";
    print STDERR "      \@tag=(",join(", ",@tag),")\n\@tag_value=(",join(", ",@tag_value),")\n";
    exit 1;
  }

  for( my $i=0; $i < scalar(@tag); $i++){
    my $key=$tag[$i];
    my $value=$tag_value[$i];
    push @TagAndValue, "Key=$key,Value=$value" if $value !~ /^\s*$/;
  }

  my $tags=join(" ",@TagAndValue);
return $tags;
}
#=============================================
sub ptr{
 my $p;
 return $p;
}
