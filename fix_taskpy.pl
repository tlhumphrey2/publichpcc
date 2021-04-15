#!/usr/bin/perl
$text2find=<<EOFF1;
        cmd = self.script_file + " " + host.ip.decode('utf-8')
EOFF1

$replacement_text=<<EOFF2;
        try:
            self._ip = host.ip.decode('utf-8')
        except AttributeError as e:
            self._ip = host.ip
        cmd = self.script_file + " " + self._ip
EOFF2
# Change the 1st line into the 4 lines -- starting with 'try:'
$taskpypath="/opt/HPCCSystems/sbin/hpcc/cluster/task.py";
undef $/; # Makes whole file come up with one read.
print "In $0. taskpypath=\"$taskpypath\"\n";
if ( open(IN,"<$taskpypath") ){
   $_=<IN>;
   close(IN);
   print "In $0. Size of task.py BEFORE is ",length($_),".\n";
   if ( s/(\Q$text2find\E)/$replacement_text/s ){
      print "In $0. FOUND text in $taskpypath and replaced it. Text found is \"$1\"\n";
      print "In $0. Size of task.py AFTER is ",length($_),".\n";
      open(OUT,">$taskpypath") || die "Could NOT open file as output: \"$taskpypath\".";
      print OUT $_;
      close(OUT);
   }
   else{
      print "In $0. WARNING: Did not find text in $taskpypath\n";
   }
}
else{
   print "In $0. WARNING: Could not find task.py \"$taskpypath\".\n";
}
print "In $0. DONE.\n";
