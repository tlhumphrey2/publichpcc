#!/usr/bin/perl
$ThisDir = ($0=~/^(.*)\//)? $1 : "."; $ThisDir = `cd $ThisDir;pwd`; chomp $ThisDir;
require "$ThisDir/common.pl";

=pod
WHAT THIS SCRIPT DOES:
1. Gets the input arguments: sshuser, stackname, destination email address, and private key file (as outputted by "aws ec2 create-key-pair")
2. Make s3 bucket whose name is $stackname (all lower case).
3. Create keypair named $stackname, using create-key-pair, and put private key in $stackname.pem.
4. Make EIP for the Master and Bastion instances and associate bastion EIP with bastion.
5. Converts both the destination email address and private key to the form needed for emailing puts both in files.
6. Checks to see if the destination email has been verified. If it hasn't it asked for it to be verified and waits for it to be verified.
7. Send an email to the destination email address which contains the private key.
=cut

#---------------------------------------------------------------------------
print "In $0. 1. Gets the input arguments: sshuser, stackname, destination email address, and region.\n";
$sshuser=shift @ARGV;
$stackname=shift @ARGV;
$destination_email=shift @ARGV;
$region=shift @ARGV;
print "Input args: sshuser=\"$sshuser\", stackname=\"$stackname\", destination_email=\"$destination_email\", region=\"$region\"\n";

# Template for email form
$template_email_json=<<EOFF1;
{
  "Subject": {
    "Data": "<stackname> private key",
    "Charset": "UTF-8"
  },
  "Body": {
    "Text": {
    "Data": "Master's EIP=<eip>\\n<private_key>",
      "Charset": "UTF-8"
    }
  }
}
EOFF1

# Template for destination email
$template_destination_email=<<EOFF2;
{
  "ToAddresses": ["<destination_email>"]
}
EOFF2

#---------------------------------------------------------------------------
# 2. Make s3 bucket whose name is $stackname (all lower case).
my $s3bucket=$stackname; $s3bucket =~ s/([A-Z]+)/\L$1/g;
print "In $0: aws s3 mb s3://$s3bucket\n";
my $rc=`aws s3 mb s3://$s3bucket 2>&1`;
print "Make Bucket rc=\"$rc\"\n";
print "In $0: aws s3api put-bucket-encryption --bucket $s3bucket --server-side-encryption-configuration '{\"Rules\": [{\"ApplyServerSideEncryptionByDefault\": {\"SSEAlgorithm\": \"AES256\"}}]}'\n";
my $rc=`aws s3api put-bucket-encryption --bucket $s3bucket --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' 2>&1`;
print "put-bucket-encryption rc=\"$rc\"\n";

# Also, put destination_email in a file and put the file is the s3bucket, $s3bucket
my $d=$destination_email; $d =~ s/\@/\\\@/;
print "Put $destination_email in the /home/$sshuser/destination_email and place file is s3bucket, $s3bucket\n";
putInFileAndStoreInS3Bucket("/home/$sshuser/destination_email", $d, $s3bucket );
#---------------------------------------------------------------------------
print "In $0. 3. Create keypair named $stackname, using create-key-pair, and put private key in $stackname.pem.\n";
print "aws ec2 create-key-pair --region $region --key-name $stackname --output text\n";
$_=`aws ec2 create-key-pair --region $region --key-name $stackname --output text`;
print "create-key-pair rc=\"$_\"\n";
print "Extract private key from rc of create-key-pair.\n";
$private_key=extractPrivateKey($_);

print "Put private_key in the /home/$sshuser/$stackname.pem and place file is s3bucket, $s3bucket\n";
putInFileAndStoreInS3Bucket("/home/$sshuser/$stackname.pem", $private_key, $s3bucket );

print "chown $sshuser:$sshuser /home/$sshuser/$stackname.pem\n";
$_=`chown $sshuser:$sshuser /home/$sshuser/$stackname.pem`;
print "chown rc=\"$_\"\n";

print "chmod 400 /home/$sshuser/$stackname.pem\n";
$_=`chmod 400 /home/$sshuser/$stackname.pem`;
print "chmod 400 rc=\"$_\"\n";
$_=`chown $sshuser:$sshuser /home/$sshuser/$stackname.pem`;
print "chown $sshuser:$sshuser $stackname.pem rc=\"$_\"\n";

#---------------------------------------------------------------------------
print "In $0. 4a. Make EIP for Master instance and bastion. Put both in s3 bucket, $stackname.\n";
my ($EIP, $EIPAllocationId) = makeEIP($region,$stackname,$s3bucket);
my ($bastionEIP, $bastionEIPAllocationId) = makeEIP($region,$stackname,$s3bucket,'bastion_');

print "In $0. 4b. Associate $bastionEIP with bastion.\n";
$BastionInstanceId = `curl http://169.254.169.254/latest/meta-data/instance-id`; chomp $BastionInstanceId;
print "aws ec2 associate-address --instance-id $BastionInstanceId --allocation-id $bastionEIPAllocationId --region $region";
$rc=`aws ec2 associate-address --instance-id $BastionInstanceId --allocation-id $bastionEIPAllocationId --region $region`;
print "In $0. associate-address rc=\"$rc\"\n";
#---------------------------------------------------------------------------
print "In $0. 5. Converts both the destination email address and private key to the form needed for emailing puts both in files.\n";
# Convert private key to form needed for sending email.
$_=$template_email_json;
s/<stackname>/$stackname/s;
my $p=$private_key; $p=~s/\n/\\n/g;
print "private_key converted to one line: \"$_\"\n";
s/<eip>/$EIP/s;
s/<private_key>/$p/s;
print "put2file(\"/home/$sshuser/private-key-email.json\",\$_)\n";
put2file("/home/$sshuser/private-key-email.json",$_);

# Convert destination email to form needed for sending email.
$_=$template_destination_email;
s/<destination_email>/$destination_email/s;
print "put2file(\"/home/$sshuser/destination_email.json\",\$_)\n";
put2file("/home/$sshuser/destination_email.json",$_);

#---------------------------------------------------------------------------
print "In $0. 6. Checks to see if the destination email has been verified. If it hasn't it asked for it to be verified and waits for it to be verified.\n";
print "aws ses get-identity-verification-attributes --identities \"$destination_email\" --region us-east-1\n";
$_=`aws ses get-identity-verification-attributes --identities "$destination_email" --region us-east-1`;
print "aws ses get-identity-verification-attributes. rc=\"$_\"\n";
$verification_status=(/"VerificationStatus": "(.+)"/s)? $1 : '' ;
while ( $verification_status ne 'Success' ){
  print "The email, $destination_email, has NOT been verified.\n";
  if ( $verification_status eq ''){
    my $rc=`aws ses verify-email-identity --email-address $destination_email --region us-east-1`;
    print "aws ses verify-email-identity rc=\"$rc\"\n";
  }
  sleep 10;
  $_=`aws ses get-identity-verification-attributes --identities "$destination_email" --region us-east-1`;
  print "aws ses get-identity-verification-attributes. rc=\"$_\"\n";
  $verification_status=(/"VerificationStatus": "(.+)"/s)? $1 : '' ;
}
if ($verification_status eq 'Success'){
  print "The email, $destination_email, has been verified.\n";
}

# Do not send email if HPCC Managed Service is launching this cluster
#if ( $stackname !~ /^mhpcc-/ ){
#---------------------------------------------------------------------------
print "In $0. 7. Send an email to the destination email address which contains the private key.\n";
print "aws ses send-email --from $destination_email --destination file:///home/$sshuser/destination_email.json --message file:///home/$sshuser/private-key-email.json --region us-east-1\n";
$rc=`aws ses send-email --from $destination_email --destination file:///home/$sshuser/destination_email.json --message file:///home/$sshuser/private-key-email.json --region us-east-1`;
print "aws ses send-email rc=\"$rc\"\n";
#---------------------------------------------------------
#}
sub extractPrivateKey{
my ($rc)=@_;
local $_=$rc;
s/^.*?(\-\-\-\-\-BEGIN RSA PRIVATE KEY\-\-\-\-\-.+\-\-\-\-\-END RSA PRIVATE KEY\-\-\-\-\-).*$/$1/s;
print "Leaving extractPrivateKey. \"$_\"\n";
return $_;
}
