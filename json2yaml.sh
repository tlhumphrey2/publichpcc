#!/bin/bash -e
/usr/bin/python2.7 -c 'import sys, yaml, json; j=json.loads(sys.stdin.read()); print yaml.safe_dump(j)'
