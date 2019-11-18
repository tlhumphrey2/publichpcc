#!/bin/bash
python3.5 -c 'import sys;sys.path.append("/usr/lib64/python3.5/site-packages");sys.path.append("/usr/lib/python3.5/site-packages");help("modules")' 2> /dev/null|perl -e 'undef $/;$_=<>;foreach my $m (numpy,scipy,statsmodels,sklearn,networkx,wheel,cryptography,tensorflow){ if (/\b$m\b/){print "INSTALLED $m\n"}else{print "NOT INSTALLED $m\n"}}'

