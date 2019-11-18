#!/usr/bin/perl
#getConfigurationFile.pl
local $ThisDir=($0=~/^(.*)\//)? $1 : ".";

$cfgfile="$ThisDir/cfg_BestHPCC.sh";
open(CFG,$cfgfile) || die "Can't open for input cfgfile=\"$cfgfile\"\n";
while(<CFG>){
   chomp;
   next if /^#/ || /^\s*$/;
   
   if ( /^(\w+(?:\[\d+\](?:\[\d+\])?)?)=(.*)\s*$/ ){
      my $env_variable=$1;
      my $value=$2;
      $value=$1 if ($value =~ /^"(.*)"$/);
      if ( ! exists($env_variable{$env_variable}) ){
        push @env_variable, $env_variable;
      }
      $env_variable{$env_variable}=$value;
   }
   else{
     print "ERROR: UNEXPECTED PATTERN IN \"$cfgfile\": \"$_\"\n";
   }
}
close(CFG);

foreach my $env_variable (@env_variable){
  my $value=$env_variable{$env_variable};
# print "DEBUG: eval(\$$env_variable=\"$value\")\n";
  eval("\$$env_variable=\"$value\"");
}
1;
