#!/usr/bin/python
import os
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
sudo `pwd`/removeInstancesFromEnv.py -n 2:2 -e /etc/HPCCSystems/environment.xml -r $region -s $stackname &> removeInstancesFromEnv.log

USAGE EXAMPLE FROM INSTANCE OTHER THAN MASTER
ssh -o stricthostkeychecking=no -i $pem -t -t ec2-user@$mip "ThisDir=/home/ec2-user;sudo \$ThisDir/removeInstancesFromEnv.py -n 1:2 -e /etc/HPCCSystems/environment.xml -r $region -s $stackname &> \$ThisDir/removeInstancesFromEnv2.log"
NOTE: In above, "-n 1:2" means remove 2 Thor slaves and 1 Roxie
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

def my_print(text2print,sysout=sys.stderr):
   sys.stdout = sysout
   print(text2print)

def execShellCommand(cmd):
   my_print('Entering execShellCommand. cmd="%s"' % cmd, sys.stderr)
   stream = os.popen('%s' % cmd)
   result = stream.read()
   my_print('In execShellCommand. result="%s"' % result, sys.stderr)
   return result

def getInstanceIds(stackname, region, InstanceIps):
  my_print('DEBUG: Entering getInstanceIds. Input parameters are: (%s)' % str(InstanceIps), sys.stderr)
  InstanceIpsString = ' '.join(InstanceIps)
  cmd = '%s/getClusterInstanceIds.pl %s %s %s' % (ThisDir,region,stackname,InstanceIpsString)
  result = execShellCommand(cmd)
  instance_ids = result.split('\n')
  instance_ids = filter(None,instance_ids)
  my_print('DEBUG: instance_ids="%s"' % instance_ids, sys.stderr)
  return instance_ids

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

def removeInstancesFromASG(InstanceIps, stackname, region):
  my_print('DEBUG: Entering removeInstancesFromASG. Input parameters are: (%s, %s, %s)' % (str(InstanceIps), stackname, region), sys.stderr)

  # Get instance ids given InstanceIps
  instance_ids = getInstanceIds(stackname, region, InstanceIps)

  # Remove instances from ASG
  results = []
  for instance_id in instance_ids:
    result = removeOneInstanceFromASG(instance_id, region)
    results.append(result)
  rc = 'Results of one or more "aws autoscaling terminate-instance-in-auto-scaling-group" where input parameters where: (%s, %s): %s' % (str(instance_ids), region, results)
  return rc

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

    my_print('DEBUG: ip="%s", ClusterType="%s", subdir="%s", cmd="%s", result="%s"' % (ip,ClusterType,subdir,cmd,str(result)), sys.stderr)
    if FilePartsExists:
       break
  return FilePartsExists

def cpFileParts(ClusterType, fromIp, toIp):
   subdir = 'thor' if ClusterType == 'ThorCluster' else 'roxie'
   # Copy file parts on fromIp
   FileStoDir = '%s/FilesFrom-%s' % (ThisDir,fromIp)
   my_print('copy file parts on %s to %s on %s.' % (fromIp,FileStoDir,toIp), sys.stderr)
   from_cmd = 'mkdir %s;sudo scp -o stricthostkeychecking=no -r -i %s ec2-user@%s:/var/lib/HPCCSystems/hpcc-data/%s/* %s; ls -lR %s' % (FileStoDir,pem,fromIp,subdir,FileStoDir,FileStoDir)
   execShellCommand(from_cmd)

   # Make subdirectory in /home/ec2-user of toIp
   my_print('Make subdirectory, %s, on %s' % (FileStoDir, toIp), sys.stderr)
   mkdir_cmd = 'ssh -o stricthostkeychecking=no -i %s ec2-user@%s "mkdir %s"' % (pem,toIp,FileStoDir)
   execShellCommand(mkdir_cmd)
   # Copy file parts to FileStoDir of toIp
   my_print('Copy file parts in %s to the same directory on %s.' % (FileStoDir, toIp), sys.stderr)
   to_cmd = 'sudo scp -o stricthostkeychecking=no -r -i %s %s/* ec2-user@%s:%s' % (pem,FileStoDir,toIp,FileStoDir)
   execShellCommand(to_cmd)
   # On toIp, copy contents of FileStoDir to /var/lib/HPCCSystems/hpcc-data/subdir
   my_print('On %s, copy contents of %s to /var/lib/HPCCSystems/hpcc-data/%s' % (toIp, FileStoDir, subdir), sys.stderr)
   mkdir_cmd = 'ssh -o stricthostkeychecking=no -i %s -t -t ec2-user@%s "sudo cp -vr %s/* /var/lib/HPCCSystems/hpcc-data/%s"' % (pem,toIp,FileStoDir,subdir)
   execShellCommand(mkdir_cmd)
   # On toIp, change ownership (to hpcc) and permissions (to 644) of contents of /var/lib/HPCCSystems/hpcc-data/subdir
   my_print('On %s, change ownership (to hpcc) and permissions (to 644) of contents of /var/lib/HPCCSystems/hpcc-data/%s' % (toIp, subdir), sys.stderr)
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
    my_print('In removeInstancesFromEnv.py. After call to "doFilePartsExists".  FilePartsExists[%s]="%s".' % (ClusterType,FilePartsExists[ClusterType]), sys.stderr)
    ErrorOccurred, error_message, nodes2remove, node2cpfiles, save_filename = env.removeInstancesOfOneClusterTypeFromEnv(args.envfile, ClusterType, Instances2Remove[ClusterType], FilePartsExists[ClusterType])
    my_print('In removeInstancesFromEnv.py. After call to "env.removeInstancesOfOneClusterTypeFromEnv". Remove %s Instances: ErrorOccurred="%s", error_message="%s", nodes2remove="%s", node2cpfiles="%s", save_filename="%s".' % (ClusterType,str(ErrorOccurred),error_message,str(nodes2remove),str(node2cpfiles),save_filename), sys.stderr)
    if not ErrorOccurred:
      Nodes2Remove[ClusterType] = nodes2remove
      Node2CPFiles[ClusterType] = node2cpfiles
      my_print('In removeInstancesFromEnv.py. No error seen. Nodes2Remove[%s]="%s", Node2CPFiles[%s]"%s".' % (ClusterType,str(Nodes2Remove[ClusterType]),ClusterType,str(Node2CPFiles[ClusterType])), sys.stderr)

# If we got not errors while removing instances from environment.xml (above code) then copy file parts and remove instances
#  Plus, push environment file to all cluster instances
if ErrorOccurred:
  my_print(error_message, actual_stdout)
else:
  my_print('In removeInstancesFromEnv.py. Before checking for instances to be removed and file parts to be moved. ClusterType="%s"' % ClusterTypes, sys.stderr)
  InstanceIps = []
  for ClusterType in ClusterTypes:
    my_print('In removeInstancesFromEnv.py. Before checking for instances to be removed: Nodes2Remove[%s]="%s"' % (ClusterType,Nodes2Remove[ClusterType]), sys.stderr)
    if 'None' not in str(Nodes2Remove[ClusterType]):
      # 2nd. Get Ips of instances to be removed.
      for NodeId, NodeIp in Nodes2Remove[ClusterType]:
        InstanceIps.append(NodeIp)
      # The following code is commented out because we have a new method for distributing logical files
      '''
      for fromIp in InstanceIps:
        # if there are file parts then copy them to Node2CPFiles
        if doFilePartsExists(envfile, ClusterType, [fromIp]):
          node2cpfiles = Node2CPFiles[ClusterType]
          toIp = node2cpfiles[1]
          cpFileParts(ClusterType,fromIp, toIp)
      '''
  my_print('In removeInstancesFromEnv.py. Push environment.xml to all cluster instances.', sys.stderr)
  rc = pushEnvToAllInstances()
  my_print('In removeInstancesFromEnv.py. Return Code from pushEnvToAllInstances is "%s".' % rc, sys.stderr)
  my_print('In removeInstancesFromEnv.py. Remove instances from their ASGs and terminate them.', sys.stderr)
  for ClusterType in ClusterTypes:
    rc = removeInstancesFromASG(InstanceIps, stackname, region)
    my_print('In removeInstancesFromEnv.py. Return Code from removeInstancesFromASG is "%s".' % rc, sys.stderr)

  # Get IPs
  Ips2Remove = " ".join(InstanceIps)
  cmd = '/home/ec2-user/getStacksInstanceDescriptions.pl %s %s %s' % (region,stackname,Ips2Remove)
  my_print('DEBUG: In add_and_or_remove_nodes. ssh command to do "removeInstancesFromEnv.py" is cmd="%s"' % (cmd), sys.stderr)
  rc = os.popen(cmd).read()
  my_print(rc, actual_stdout)
