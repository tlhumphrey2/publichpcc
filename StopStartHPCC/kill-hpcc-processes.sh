#!/bin/bash
kill -9 $(ps -u hpcc|perl -e "while(<>){push @x,\$1 if /^\s*(\\d+)/;};print join(' ',@x),\"\\n\""); 
