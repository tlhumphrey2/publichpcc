#!/usr/bin/python
import os
import argparse
import sys
import InfoOfEnv as env
import uuid
import re
ThisDir = os.path.dirname(os.path.realpath(__file__))

'''
USAGE EXAMPLE:
sudo `pwd`/removeInstancesFromEnv.py -n 2:2 -e /etc/HPCCSystems/environment.xml -r $region -s $stackname &> removeInstancesFromEnv.log

USAGE EXAMPLE FROM INSTANCE OTHER THAN MASTER
ssh -o stricthostkeychecking=no -i $pem -t -t ec2-user@$mip "sudo ./removeInstancesFromEnv.py -n 1:2 -e /etc/HPCCSystems/environment.xml -r $region -s $stackname &> removeInstancesFromEnv2.log"
NOTE: In above, "-n 2:1" means remove 2 Thor slaves and 1 Roxie
'''

parser = argparse.ArgumentParser(description='Remove 1 Node to Cluster')
parser.add_argument("-e", "--envfile", help="Path to environment which nodes will be removed", type=str)
parser.add_argument("-n", "--Number2Remove", help="Number of instances to remove", type=str)
parser.add_argument("-r", "--region", help="region", type=str)
parser.add_argument("-s", "--stackname", help="stackname", type=str)
args = parser.parse_args()
envfile = args.envfile
Number2Remove = args.Number2Remove
region = args.region
stackname = args.stackname
pem = stackname+'.pem'

def execShellCommand(cmd):
   print('Entering execShellCommand. cmd="%s"' % cmd)
   stream = os.popen('%s' % cmd)
   result = stream.read()
   print('In execShellCommand. result="%s"' % result)
   return result

def getInstanceIds(stackname, region, InstanceIps):
  print('DEBUG: Entering getInstanceIds. Input parameters are: (%s)' % str(InstanceIps))
  InstanceIpsString = ' '.join(InstanceIps)
  cmd = '%s/getClusterInstanceIds.pl %s %s %s' % (ThisDir,region,stackname,InstanceIpsString)
  result = execShellCommand(cmd)
  instance_ids = result.split('\n')
  instance_ids = filter(None,instance_ids)
  print('DEBUG: instance_ids="%s"' % instance_ids)
  return instance_ids
  
def rmInstancesFromASG(instance_ids, region):
  print('DEBUG: Entering rmInstancesFromASG. Input parameters are: (%s, %s)' % (str(instance_ids), region))
  results = []
  for instance_id in instance_ids:
    cmd = 'aws autoscaling terminate-instance-in-auto-scaling-group --instance-id %s --should-decrement-desired-capacity --region %s' % (instance_id, region)
    result = execShellCommand(cmd)
    results.append(result)
  return results

def removeInstancesFromASG(InstanceIps, stackname, region):
  print('DEBUG: Entering removeInstancesFromASG. Input parameters are: (%s, %s, %s)' % (str(InstanceIps), stackname, region))

  # Get instance ids given InstanceIps
  instance_ids = getInstanceIds(stackname, region, InstanceIps)

  # Remove instances from ASG
  rc = rmInstancesFromASG(instance_ids, region)
  rc = 'Return code from "rmInstancesFromASG where input parameters where: (%s, %s): %s' % (str(instance_ids), region, rc)
  return rc

def restartCluster():
  cmd = '%s/startHPCCOnAllInstances.pl restart' % (ThisDir)
  result = execShellCommand(cmd)
  return result

def pushEnvToAllInstances():
  cmd = '/opt/HPCCSystems/sbin/hpcc-push.sh -s /etc/HPCCSystems/environment.xml -t /etc/HPCCSystems/environment.xml' 
  result = execShellCommand(cmd)
  return result

def resumeASGTasks():
  cmd = '%s/StopStartHPCC/resumeASGProcesses.pl' % ThisDir 
  result = execShellCommand(cmd)
  return result

def suspendASGTasks():
  cmd = '%s/StopStartHPCC/suspendASGProcesses.pl' % ThisDir 
  result = execShellCommand(cmd)
  return result

def doFilePartsExists(envfile, ClusterType, InstanceIps=None):
  pattern = re.compile("file parts exist")
  if InstanceIps is None:
    InstanceIps = env.getAllInstanceIPs(envfile, ClusterType)
  FilePartsExists = False
  for ip in InstanceIps:
    subdir = 'thor' if ClusterType == 'ThorCluster' else 'roxie'
    cmd0 = ThisDir+'/doFilePartExists.pl '+subdir
    cmd = 'ssh -i %s ec2-user@%s "%s"' % (pem,ip,cmd0)
    result = execShellCommand(cmd)
    if result == 'file parts exist':
      FilePartsExists = True

    print('DEBUG: ip="%s", ClusterType="%s", subdir="%s", cmd="%s", result="%s"' % (ip,ClusterType,subdir,cmd,str(result)))
    if FilePartsExists:
       break
  return FilePartsExists

def cpFileParts(ClusterType, fromIp, toIp):
   subdir = 'thor' if ClusterType == 'ThorCluster' else 'roxie'
   # Copy file parts on fromIp
   FileStoDir = '%s/FilesFrom-%s' % (ThisDir,fromIp)
   print('copy file parts on %s to %s on %s.' % (fromIp,FileStoDir,toIp))
   from_cmd = 'mkdir %s;sudo scp -o stricthostkeychecking=no -r -i %s ec2-user@%s:/var/lib/HPCCSystems/hpcc-data/%s/* %s; ls -lR %s' % (FileStoDir,pem,fromIp,subdir,FileStoDir,FileStoDir)
   execShellCommand(from_cmd)

   # Make subdirectory in /home/ec2-user of toIp
   print('Make subdirectory, %s, on %s' % (FileStoDir, toIp))
   mkdir_cmd = 'ssh -o stricthostkeychecking=no -i %s ec2-user@%s "mkdir %s"' % (pem,toIp,FileStoDir)
   execShellCommand(mkdir_cmd)
   # Copy file parts to FileStoDir of toIp
   print('Copy file parts in %s to the same directory on %s.' % (FileStoDir, toIp))
   to_cmd = 'sudo scp -o stricthostkeychecking=no -r -i %s %s/* ec2-user@%s:%s' % (pem,FileStoDir,toIp,FileStoDir)
   execShellCommand(to_cmd)
   # On toIp, copy contents of FileStoDir to /var/lib/HPCCSystems/hpcc-data/subdir
   print('On %s, copy contents of %s to /var/lib/HPCCSystems/hpcc-data/%s' % (toIp, FileStoDir, subdir))
   mkdir_cmd = 'ssh -o stricthostkeychecking=no -i %s -t -t ec2-user@%s "sudo cp -vr %s/* /var/lib/HPCCSystems/hpcc-data/%s"' % (pem,toIp,FileStoDir,subdir)
   execShellCommand(mkdir_cmd)
   # On toIp, change ownership (to hpcc) and permissions (to 644) of contents of /var/lib/HPCCSystems/hpcc-data/subdir
   print('On %s, change ownership (to hpcc) and permissions (to 644) of contents of /var/lib/HPCCSystems/hpcc-data/%s' % (toIp, subdir))
   owner_cmd = 'ssh -o stricthostkeychecking=no -i %s -t -t ec2-user@%s "sudo chown -R hpcc:hpcc /var/lib/HPCCSystems/hpcc-data/%s/*;sudo chmod -R 664 /var/lib/HPCCSystems/hpcc-data/%s/*"' % (pem,toIp,subdir,subdir)
   execShellCommand(owner_cmd)

# NOTE: Number2Remove must be in the form "N:M" where N and M are positive integers.
# N is the number of Thor slave instances to remove. M is the number of Roxie instances to remove.
ThorNodes2Remove , RoxieNodes2Remove = args.Number2Remove.split(':')
Instances2Remove = {}
Instances2Remove['ThorCluster'] = int(ThorNodes2Remove)
Instances2Remove['RoxieCluster'] = int(RoxieNodes2Remove)

save_filename = None
ErrorOccurred = False
ClusterTypes = ['ThorCluster', 'RoxieCluster']
Nodes2Remove = {}
Node2CPFiles = {}
FilePartsExists = {}
for ClusterType in ClusterTypes:
  # 1st. Remove instances from environment.xml file and get information about instances removed and
  #  where their file parts should be moved
  Nodes2Remove[ClusterType] = [None, None]
  Node2CPFiles[ClusterType] = [None, None]
  if (not ErrorOccurred) and (Instances2Remove[ClusterType] > 0):
    FilePartsExists[ClusterType] = doFilePartsExists(envfile, ClusterType)
    ErrorOccurred, nodes2remove, node2cpfiles, save_filename = env.removeInstancesOfOneClusterTypeFromEnv(args.envfile, ClusterType, Instances2Remove[ClusterType], FilePartsExists[ClusterType])
    print('Remove %s Instances: ErrorOccurred="%s", nodes2remove="%s", node2cpfiles="%s", save_filename="%s".' % (ClusterType,str(ErrorOccurred),str(nodes2remove),str(node2cpfiles),save_filename))
    if not ErrorOccurred:
      Nodes2Remove[ClusterType] = nodes2remove
      Node2CPFiles[ClusterType] = node2cpfiles
      print('Nodes2Remove[%s]="%s", Node2CPFiles[%s]"%s".' % (ClusterType,str(Nodes2Remove[ClusterType]),ClusterType,str(Node2CPFiles[ClusterType])))

# If we got not errors while removing instances from environment.xml (above code) then copy file parts and remove instances
if not ErrorOccurred:
  print('Before checking for instances to be removed and file parts to be moved. ClusterType="%s"' % ClusterTypes)
  InstanceIps = []
  for ClusterType in ClusterTypes:
    print('Before checking for instances to be removed: Nodes2Remove[%s]="%s"' % (ClusterType,Nodes2Remove[ClusterType]))
    if 'None' not in str(Nodes2Remove[ClusterType]):
      # 2nd. Get Ips of instances to be removed.
      for NodeId, NodeIp in Nodes2Remove[ClusterType]:
        InstanceIps.append(NodeIp)
      for fromIp in InstanceIps:
        # if there are file parts then copy them to Node2CPFiles
        if doFilePartsExists(envfile, ClusterType, [fromIp]):
          node2cpfiles = Node2CPFiles[ClusterType]
          toIp = node2cpfiles[1]
          cpFileParts(ClusterType,fromIp, toIp)
  print('Push environment.xml to all cluster instances.')
  rc = pushEnvToAllInstances()
  print('Return Code from pushEnvToAllInstances is "%s".' % rc)
  print('Restart cluster.')
  rc = restartCluster()
  print('Return Code from startCluster is "%s".' % rc)
  print('Remove instances from their ASGs and terminate them.')
  for ClusterType in ClusterTypes:
    rc = removeInstancesFromASG(InstanceIps, stackname, region)
    print('Return Code from removeInstancesFromASG is "%s".' % rc)
