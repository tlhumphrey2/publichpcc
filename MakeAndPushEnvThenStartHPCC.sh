#!/bin/bash -e
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $ThisDir/cfg_BestHPCC.sh

# 1) get new cluster configuration, 
# 2) make env file and distribute, and
# 3) start cluster
# 1. Get new cluster configuration
$ThisDir/setupCfgFileVariables.pl -clustercomponent Master -stackname $stackname -region $region -pem $pem

# 2. Make new environment file and distribute it
$ThisDir/final_configureHPCC.sh &> final_configureHPCC.log

# 3. Start cluster
$ThisDir/startHPCCOnAllInstances.pl
