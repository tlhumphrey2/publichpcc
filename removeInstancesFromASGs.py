#!/usr/bin/python
import os
import subprocess
import argparse
import sys
actual_stdout = sys.stdout
sys.stdout = sys.stderr
import InfoOfEnv as env
import uuid
import re
ThisDir = os.path.dirname(os.path.realpath(__file__))

'''
USAGE EXAMPLE:
removeInstancesFromASGs.py -r us-west-1 -s mhpcc-us-west-1-6vz-171 -i i-0a038a1bb793fd8a3,i-0b557250e7f16c845
'''

def my_print(text2print,sysout=sys.stderr):
   sys.stdout = sysout
   print(text2print)

def execShellCommand(cmd):
   my_print('Entering execShellCommand. cmd="%s"' % cmd, sys.stderr)
   process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
   out, err = process.communicate()
   my_print('In execShellCommand. out="%s", err="%s".' % (out,err), sys.stderr)
   results = out
   if re.search(r'^\s*[^\s]',err):
     results += ': '+err
   return results

def removeOneInstanceFromASG(instance_id, region):
    InstanceRemoved = False
    result = None
    return_result = None
    cnt = 10
    while not InstanceRemoved and (cnt > 0):
      cnt -= 1
      cmd = 'aws autoscaling terminate-instance-in-auto-scaling-group --instance-id %s --should-decrement-desired-capacity --region %s' % (instance_id, region)
      result = execShellCommand(cmd)
      if 'Instance Id not found' in result:
          return_result = '%s was removed from its ASG and is being terminated.\n' % instance_id
          InstanceRemoved = True
      else:
          return_result = result
          InstanceRemoved = False
      my_print('In removeOneInstanceFromASG. result="%s"' % result, sys.stderr)
    return return_result

def removeInstancesFromASG(instance_ids, stackname, region):
  my_print('DEBUG: Entering removeInstancesFromASG. Input parameters are: (%s, %s, %s)' % (str(instance_ids), stackname, region), sys.stderr)

  # Remove instances from ASG
  results = []
  for instance_id in instance_ids:
    result = removeOneInstanceFromASG(instance_id, region)
    results.append(result)
  rc = 'Results of one or more "aws autoscaling terminate-instance-in-auto-scaling-group" where input parameters where: (%s, %s): %s' % (str(instance_ids), region, results)
  return rc

parser = argparse.ArgumentParser(description='Remove 1 Node to Cluster')
parser.add_argument("-i", "--instance_ids", help="Instance IDs to be removed from their ASGs and terminated.", type=str)
parser.add_argument("-r", "--region", help="region", type=str)
parser.add_argument("-s", "--stackname", help="stackname", type=str)
args = parser.parse_args()
instance_ids = args.instance_ids.split(',')
region = args.region
stackname = args.stackname
pem = stackname+'.pem'

rc = removeInstancesFromASG(instance_ids, stackname, region)

print('rc="%s".' % rc)
