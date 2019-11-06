#!/usr/bin/perl
$ThisDir=($0=~/^(.*)\//)? $1 : ".";
$stackname = shift @ARGV;
$nodetype = shift @ARGV;

sub getComponentsByLaunchTime{
my ($stackname, $nodetype)=@_;
$_ = `egrep "^    PrivateIpAddress:|^    LaunchTime:|^    - {Key: Name, Value: $stackname--" $stackname-instance-descriptions.yaml`;
@in = split(/\n/,$_);
$line = '';
$i=1;
foreach (@in){
  s/^ +//;
  s/\{.+--(.+)\}/$1/g;
  if ( ($i % 3) == 0 ){
    $line .= ' '.$_;
    push @line, $line;
    $line = '';
    
  }
  else{
    $line .= ' '.$_;
  }

  $i++;
}

@line = sort(@line);
@line = grep(/$nodetype/,@line);
@line = grep(s/^.+PrivateIpAddress: (\d+\.\d+.\d+.\d+) - $nodetype\s*$/$1/,@line);
return @line;
}

sub makeComponentProcessLines{
my ( $nodetype, @IPs )=@_;
 @IPs = grep(! /^\s*$/,@IPs);

 my $thor_process_template = '   <ThorSlaveProcess computer="<node_id>" name="s<num>"/>'; 
 my $roxie_process_template = '   <RoxieServerProcess computer="<node_id>" name="<node_id>" netAddress="<ip>"/>'; 
 my @process_line = ();
 my $num=1;
 foreach (@IPs){
   my $ip = $_;
   s/^\d+\.\d+.\d+.(\d+)$/$1/;
   my $pline = ($nodetype eq 'Slave')? $thor_process_template : $roxie_process_template ;
   my $node_id = sprintf "node%06d",$_;
   $pline =~ s/<node_id>/$node_id/g;
   $pline =~ s/<num>/$num/g;
   $pline =~ s/<ip>/$ip/g;
   push @process_line, $pline;
   $num++;
 }
return @process_line;
}

sub replaceComponentProcessLines{
my ( $nodetype, @process_line )=@_;
  @process_line = grep(! /^\s*$/,@process_line);
  local $_ = `cat /etc/HPCCSystems/environment.xml`;
  my @line = split(/\n/,$_);
  my $slave_process = '<ThorSlaveProcess';
  my $roxie_process = '<RoxieServerProcess';
  my $pid  = ($nodetype eq 'Slave')? $slave_process : $roxie_process ;
  my @new = ();
  my $found_processes = 0;
  for ( my $i=0; $i < scalar(@line); ){
    $_ = $line[$i];
    if ( /$pid/ ){
      $found_processes = 1;
      do{
        push @new, $_;
        $i++;
        $_ = $line[$i];
      } while( /$pid/ );
    }
    if ( $found_processes ){
      push @new, @line[ $i .. $#line ];
      last;
    }
    else{
      push @new, $_;
    }
    $i++;
  }
return join("\n",@new);
}

sub orderComponentProcessLinesByLaunchTime{
my ($stackname, $nodetype)=@_;

  my @IPs = getComponentsByLaunchTime($stackname, $nodetype);
  print "In fixComponentProcessLines. ",join("\nIn fixComponentProcessLines. ",@IPs),"\n";

  my @process_line = makeComponentProcessLines( $nodetype, @IPs );
  print "\n============================ Process Lines ============================\n";
  print "In fixComponentProcessLines. ",join("\nIn fixComponentProcessLines. ",@process_line),"\n";

  my $new_environment = replaceComponentProcessLines( $nodetype, @process_line );
  open(OUT,">$ThisDir/new_environment.xml") || die "Can't open for output: \"$ThisDir/new_environment.xml\"\n";
  print OUT $new_environment;
  close(OUT);
  print "In fixComponentProcessLines. new_environment.xml file=\"$ThisDir/new_environment.xml\"\n";
return "$ThisDir/new_environment.xml";
}

$env = orderComponentProcessLinesByLaunchTime($stackname, $nodetype);
print "new environment file is $env\n";


