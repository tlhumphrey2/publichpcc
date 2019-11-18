#!/bin/bash
n=$1
sed  "s/slavesPerNode=\"2\"/slavesPerNode=\"$n\"/" spn-02-environment.xml > t;mv t spn-$n-environment.xml
echo "spn-$n-environment.xml"
egrep slavesPerNode spn-$n-environment.xml
