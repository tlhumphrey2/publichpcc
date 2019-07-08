#!/bin/bash
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

HPCCPlatform=$1
# E.G. HPCCPlatform=http://wpc.423A.rhocdn.net/00423A/releases/CE-Candidate-6.2.6/bin/platform/hpccsystems-platform-community_6.2.6-1.el6.x86_64.rpm

#install hpcc
echo "install hpcc"
mkdir hpcc
cd hpcc
echo "wget $HPCCPlatform"
wget $HPCCPlatform

echo "yum install $HPCCPlatform -y"
yum install $HPCCPlatform -y
