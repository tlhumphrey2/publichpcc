#!/usr/bin/perl
=pod
mkTagSet.pl "Key=market,Value=hpccsystems Key=product,Value=hpccsystems Key=application,Value=hpccsystems Key=service,Value=s3bucket Key=lifecycle,Value=dev Key=owner_email,Value='timothy.humphrey@lexisnexisrisk.com' Key=support_email,Value='timothy.humphrey@lexisnexisrisk.com'"

=cut
$_=shift @ARGV;
s/^\s+//;
s/\s+$//;
@kv=split(/\s+/,$_);
$_='{'.join('},{',@kv).'}';
print "$_\n";
