#!/usr/bin/perl
#$ThisDir=($0 =~ /^(.+)[\\\/]/)? $1 : "." ;
require "$ThisDir/ClusterInitVariables.pl";

=pod
perl mkKillActiveProcesses.pl check-ps.log
ip-10-0-0-127
  PID TTY          TIME CMD
30657 ?        00:00:00 init_dafilesrv
30711 ?        00:00:00 dafilesrv
Connection to 10.0.0.127 closed.
ip-10-0-0-245
  PID TTY          TIME CMD
 6661 ?        00:00:00 init_dafilesrv
 6715 ?        00:00:00 dafilesrv
Connection to 10.0.0.245 closed.
ip-10-0-0-130
  PID TTY          TIME CMD
 6666 ?        00:00:00 init_dafilesrv
 6720 ?        00:00:00 dafilesrv
Connection to 10.0.0.130 closed.
ip-10-0-0-138
  PID TTY          TIME CMD
 6664 ?        00:00:00 init_dafilesrv
 6718 ?        00:00:00 dafilesrv
Connection to 10.0.0.138 closed.
ip-10-0-0-54
  PID TTY          TIME CMD
22840 ?        00:00:00 init_dafilesrv
22894 ?        00:00:00 dafilesrv
Connection to 10.0.0.54 closed.
ip-10-0-0-129
  PID TTY          TIME CMD
Connection to 10.0.0.129 closed.
=cut
while(<>){
  chomp;
  if ( /^\s*(\d+)/ ){
    push @pid,$1;
  }
  elsif ( /Connection\s+to\s+(\d+(?:\.\d+){3})\s+closed/ ){
    my $ip=$1;
    my $pids=join(" ",@pid);
    if ( scalar(@pid)>0 ){
       print "ssh -i mlteam-keys-us-west-1.pem -t $sshuser\@$ip \"sudo kill -9 $pids\"\n";
       system("ssh -i mlteam-keys-us-west-1.pem -t $sshuser\@$ip \"sudo kill -9 $pids\"");
    }
    @pid=();
  }
}
