#!/bin/bash
allvars=(EBSVolumesMaster InstallCassandra KeyPair NumberOfChannelsPerSlave Region ScriptsS3BucketFolder SSHUserName StackName)
echo ${allvars[0]}
echo ${allvars[1]}
echo ${allvars[2]}
echo ${allvars[3]}
echo ${allvars[4]}
echo ${allvars[5]}
echo ${allvars[6]}
echo ${allvars[7]}
echo
echo
for t in ${allvars[@]}; do
 echo $t
done
echo
echo
for i in ${!allvars[@]};do
  echo --${allvars[$i]}
done
