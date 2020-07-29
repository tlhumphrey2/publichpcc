#!/usr/bin/python
import os
import argparse
import sys
import InfoOfEnv as env

'''
USAGE EXAMPLE:
replaceClusterEnvParameters.py -c ThorCluster -e ~/yuting-environment.xml -p "{'channelsPerSlave': 5,'slavesPerNode': 9}"
'''

def pushEnvToAllInstances():
  cmd = 'sudo /opt/HPCCSystems/sbin/hpcc-push.sh -s /etc/HPCCSystems/environment.xml -t /etc/HPCCSystems/environment.xml' 
  result = os.popen(cmd).read()
  return result

parser = argparse.ArgumentParser(description='Output number of nodes in either Thor or Roxie Cluster')
parser.add_argument("-c", "--ClusterType", help="Type of cluster to remove node(either ThorCluster or RoxieCluster)", type=str)
parser.add_argument("-e", "--envfile", help="Path to environment which nodes will be removed", type=str)
parser.add_argument("-p", "--param", help="Parameter of ClusterType whose value is replaced", type=str)
args = parser.parse_args()

ClusterType = args.ClusterType
envfile = args.envfile
param = eval(args.param)
print('ClusterType="%s", envfile="%s", param="%s".' % (ClusterType, envfile, str(param)))

# Change environment.xml file
env.ReplaceParameterOfCluster(envfile, ClusterType, param)

# Push to all cluster instances
pushEnvToAllInstances()
