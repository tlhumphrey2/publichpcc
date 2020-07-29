#!/usr/bin/python
import os
import argparse
import sys
import re
import json
ThisDir = os.path.dirname(os.path.realpath(__file__))

'''
USAGE EXAMPLE:
getClusterNonRootEBSVolumes.py -r us-est-2 -s mhpcc-us-east-2-120

USAGE EXAMPLE FROM INSTANCE OTHER THAN MASTER
ssh -o stricthostkeychecking=no -i $pem -t -t ec2-user@$mip "ThisDir=/home/ec2-user;sudo \$ThisDir/removeInstancesFromEnv.py -n 1:2 -e /etc/HPCCSystems/environment.xml -r $region -s $stackname &> \$ThisDir/removeInstancesFromEnv2.log"
NOTE: In above, "-n 1:2" means remove 2 Thor slaves and 1 Roxie
'''

parser = argparse.ArgumentParser(description='Remove 1 Node to Cluster')
parser.add_argument("-r", "--region", help="region", type=str)
parser.add_argument("-s", "--stackname", help="stackname", type=str)
args = parser.parse_args()
region = args.region
stackname = args.stackname
#print('region="%s", stackname="%s"' % (region, stackname))

def my_print(text2print,sysout=sys.stderr):
   sys.stdout = sysout
   print(text2print)

def execShellCommand(cmd):
   #my_print('Entering execShellCommand. cmd="%s"' % cmd, sys.stderr)
   stream = os.popen('%s' % cmd)
   result = stream.read()
   #my_print('In execShellCommand. result="%s"' % result, sys.stderr)
   return result

def getClusterNonRootEBSVolumes(region, stackname, current_ebs_volumes=''):
  current_ebs_volumes = re.findall(r'vol-[0-9a-z]+', current_ebs_volumes)

  shellcmd = '%s/getClusterNonRootEBSVolumes.pl %s %s' % (ThisDir,region,stackname)
  #my_print('shellcmd="%s"' % shellcmd)
  #cmd = 'ssh -o stricthostkeychecking=no -i %s ec2-user@%s "%s 2>&1"' % (pem,mip,shellcmd)
  volumes_string = execShellCommand(shellcmd)
  ebs_volumes = volumes_string.splitlines()
  if type(current_ebs_volumes) == list:
     current_ebs_volumes.extend(ebs_volumes)
  else:
     current_ebs_volumes = ebs_volumes
  current_ebs_volumes = list(set(current_ebs_volumes))
  current_ebs_volumes = json.dumps(current_ebs_volumes)
  return current_ebs_volumes

current_ebs_volumes = "['vol-07b326ec06f8ceb1f', 'vol-03837cc3b4ad40aca']"
ebs_volumes = getClusterNonRootEBSVolumes(region, stackname, current_ebs_volumes)
my_print(ebs_volumes)

