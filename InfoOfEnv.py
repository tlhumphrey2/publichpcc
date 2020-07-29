import os
import sys
import xml.etree.ElementTree as ET
import uuid
import os
ThisDir = os.path.dirname(os.path.realpath(__file__))

def my_print(text2print,sysout=sys.stderr):
   sys.stdout = sysout
   print(text2print)

def HardwareComputer(root, nodeID):
  s = root.find('Hardware')
  sname = s.tag
  Computer = None
  for child in s:
     if child.tag == 'Computer':
       name = child.get('name')
       if ( name == nodeID ):
         Computer = child
  return Computer

def NodeIdAndIp(root, element):
  nodeID = element.get('computer')
  Computer = HardwareComputer(root, nodeID)
  nodeIP = Computer.get('netAddress')
  return [nodeID, nodeIP]


def getNumberOfNodes(envfile, ClusterType):
  tree = ET.parse(envfile)
  root = tree.getroot()

  ProcessName = 'ThorSlaveProcess' if ClusterType == 'ThorCluster' else 'RoxieServerProcess'
  nNodes = 0
  for s in root.find('Software'):
    component_name = s.tag
    if component_name == ClusterType:
      for element in s:
        if element.tag == ProcessName:
          nNodes += 1
  return nNodes

def ReplaceParameterOfCluster(envfile, ClusterType, param):
  tree = ET.parse(envfile)
  root = tree.getroot()

  ProcessName = 'ThorSlaveProcess' if ClusterType == 'ThorCluster' else 'RoxieServerProcess'
  for s in root.find('Software'):
    component_name = s.tag
    if component_name == ClusterType:
      for key,val in s.attrib.items():
	if key in param.keys():
	  s.attrib[key] = str(param[key])
          my_print('DEBUG: in ReplaceParameterOfCluster. %s: %s=%s' % (ClusterType,key,s.attrib[key]))

  my_print('DEBUG: in ReplaceParameterOfCluster. Saving changes')
  tree.write(envfile)

def ListParametersOfCluster(envfile, ClusterType):
  tree = ET.parse(envfile)
  root = tree.getroot()

  ProcessName = 'ThorSlaveProcess' if ClusterType == 'ThorCluster' else 'RoxieServerProcess'
  for s in root.find('Software'):
    component_name = s.tag
    if component_name == ClusterType:
      my_print('%s: %s' % (s.tag, str(s.attrib)))
      for key,val in s.attrib.items():
        my_print('%s: %s=%s' % (ClusterType,key,val))

def getAllInstanceIPs(envfile, ClusterType):
  tree = ET.parse(envfile)
  root = tree.getroot()

  ProcessName = 'ThorSlaveProcess' if ClusterType == 'ThorCluster' else 'RoxieServerProcess'
  nodeIdIp = []
  for s in root.find('Software'):
    component_name = s.tag
    if component_name == ClusterType:
      for element in s:
        if element.tag == ProcessName:
          nodeIdIp.append(NodeIdAndIp(root, element))
  my_print('DEBUG: In getAllInstanceIPs. nodeIdIp="%s"' % str(nodeIdIp))  

  nodeIp = []
  for id, ip in nodeIdIp:
    nodeIp.append(ip)
  return nodeIp

def getNodeIdAndIpOfCluster(root, ClusterType):
  ProcessName = 'ThorSlaveProcess' if ClusterType == 'ThorCluster' else 'RoxieServerProcess'
  nodeIdIp = []
  for s in root.find('Software'):
    component_name = s.tag
    if component_name == ClusterType:
      for element in s:
        if element.tag == ProcessName:
          nodeIdIp.append(NodeIdAndIp(root, element))
  my_print('DEBUG: In getNodeIdAndIpOfCluster. nodeIdIp="%s"' % str(nodeIdIp))  

  if len(nodeIdIp) == 0:
    node2remove = [None, None]
    node2cpfiles = [None, None]
  elif len(nodeIdIp) >= 2:
    node2remove = nodeIdIp[-1]
    node2cpfiles = nodeIdIp[-2] if ClusterType == 'ThorCluster' else nodeIdIp[0]
  else:
    node2remove = nodeIdIp[-1]
    node2cpfiles = [None,None]
  my_print('DEBUG: Leaving getNodeIdAndIpOfCluster. node2remove="%s", node2cpfiles="%s"' % (str(node2remove), str(node2cpfiles)))  
  return node2remove, node2cpfiles
    
def removeTopologyReferences(tree, ClusterType):
  desired_name = 'thor' if ClusterType == 'ThorCluster' else 'roxie'

  root = tree.getroot()
  software = root.find('Software')
  s = software.find('Topology')
  tname = s.tag
  my_print('DEBUG: Entering removeTopologyReferences. ClusterType="%s", tname="%s".' % (ClusterType,tname))
  nTolologyChildren = len(s.getchildren())
  my_print('DEBUG: In removeTopologyReferences. nTolologyChildren="%s".' % (nTolologyChildren))
  for child in s.findall('Cluster'):
    cname = child.tag
    my_print('DEBUG: In removeTopologyReferences. ClusterType="%s", tname="%s", cname="%s".' % (ClusterType,tname,cname))
    if cname == 'Cluster':
      name = child.get('name')
      my_print('DEBUG: In removeTopologyReferences. ClusterType="%s", tname="%s", name="%s".' % (ClusterType,tname,name))
      if (name == desired_name) or (name == 'thor_roxie'):
        s.remove(child)
        my_print('DEBUG: In removeTopologyReferences. Of "%s", removed Cluster whose name="%s".' % (tname, name))
  return tree

def removeCluster(tree, ClusterType):
  root = tree.getroot()
  s = root.find('Software')
  sname = s.tag
  my_print('DEBUG: Entering removeCluster. ClusterType="%s", sname="%s".' % (ClusterType,sname))
  for child in s:
    c = child.tag
    if c == ClusterType:
      s.remove(child)
      tree = removeTopologyReferences(tree,ClusterType)
      my_print('DEBUG: In removeCluster. ClusterType="%s" was removed.' % ClusterType)
  return tree

def removeElementsContainingNodeId(tree, ClusterType, nodeID):
  root = tree.getroot()
  my_print('DEBUG: Entering removeElementsContainingNodeId. ClusterType="%s", nodeID="%s"' % (ClusterType,nodeID))

  # Find Computer in Hardware
  s = root.find('Hardware')
  sname = s.tag
  for child in s:
    if child.tag == 'Computer':
      name = child.get('name')
      if ( name == nodeID ):
        s.remove(child)
        my_print('DEBUG: In removeElementsContainingNodeId. From "%s", removed computer with nodeID="%s"' % (sname,nodeID))
        break

  # Find in Software all computer whose node is nodeID and remove
  Software = root.find('Software')
  for s in Software:
    sname = s.tag
    if len(s) > 0:
      for child in s:
        computer = child.get('computer')
        my_print('DEBUG: In removeElementsContainingNodeId. s.tag="%s", child.tag="%s", computer="%s", nodeID="%s"' % (sname,child.tag,computer,nodeID))
        if ( computer == nodeID ):
           s.remove(child)
           my_print('DEBUG: In removeElementsContainingNodeId. From "%s", removed computer with nodeID="%s"' % (child.tag,nodeID))
        computer = None
  return tree

def removeInstanceFromEnv(ClusterType, FilePartsExists, envfile='/etc/HPCCSystems/environment.xml'):
  my_print('DEBUG: Entering removeInstanceFromEnv. envfile="%s", ClusterType="%s", FilePartsExists="%s"' % (envfile, ClusterType, str(FilePartsExists)))
  tree = ET.parse(envfile)
  root = tree.getroot()

  node2remove, node2cpfiles = getNodeIdAndIpOfCluster(root, ClusterType)
  # Couldn't find nodes to remove
  if node2remove[0] is None:
    my_print('DEBUG: Leaving removeInstanceFromEnv. Could not find nodes to remove. node2remove="%s", node2cpfiles="%s", out_envfile="None"' % (str(node2remove),str(node2cpfiles)))
    error_message = 'Error Condition. Could not find nodes to remove. node2remove="%s", node2cpfiles="%s"' % (str(node2remove),str(node2cpfiles))
    return [None,None], [None,None], None, error_message
    
  nodeID = node2remove[0]
  nodeIP = node2remove[1]
  my_print('DEBUG: In removeInstanceFromEnv. After call to getNodeIdAndIpOfCluster. node2remove="%s", node2cpfiles="%s", nodeID="%s"' % (str(node2remove), str(node2cpfiles), nodeID))
  if (node2cpfiles[0] is None): # This is True if there isn't another ClusterType instance where file parts can be removed
    my_print('DEBUG: In removeInstanceFromEnv. No node to copy to: node2cpfiles[0]="%s"' % (str(node2cpfiles[0])))
    if not FilePartsExists:  # If there aren't file parts then we remove the cluster from the environment.xml file
       tree = removeCluster(tree, ClusterType)
    else: # if there isn't a cluster instance to move file parts and there are file parts then we have an error condition.
       my_print('DEBUG: Leaving removeInstanceFromEnv.  Not modifying environment.xml, since there are file parts on the instance to remove, "%s", but no nodes to copy file parts to (%s). So we EXIT.' % (nodeIP, envfile))
       error_message = 'DEBUG: Leaving removeInstanceFromEnv.  Not modifying environment.xml, since there are file parts on the instance to remove, "%s", but no nodes to copy file parts to (%s). So we EXIT.' % (nodeIP, envfile)
       return node2remove, [None, None], None, error_message
  tree = removeElementsContainingNodeId(tree, ClusterType, nodeID) # from environment.xml, remove elements containing instance being removed.
  my_print('DEBUG: In removeInstanceFromEnv. write %s' % envfile)

  basename = os.path.basename(envfile)
  out_envfile = ThisDir+'/'+basename+'-out-'+str(uuid.uuid4().hex)
  tree.write(out_envfile)
  my_print('DEBUG: Leaving removeInstanceFromEnv. node2remove="%s", node2cpfiles="%s", out_envfile="%s"' % (str(node2remove),str(node2cpfiles),str(out_envfile)))
  return node2remove, node2cpfiles, out_envfile, ''
  
def saveEnv(envfile,ThisDir,save_filename=None):
  # Save environment file in case we need to restore it
  basename = os.path.basename(envfile)
  if save_filename is None:
    save_filename = ThisDir+'/'+basename+'-saved-'+str(uuid.uuid4().hex)
    cmd = 'cp %s %s' % (envfile, save_filename)
    rc = os.system(cmd+' 2>&1')
    my_print('RC of bash command, "%s", is "%s"' % (cmd, rc))

def removeInstancesOfOneClusterTypeFromEnv(envfile, ClusterType, Number2Remove, FilePartsExists, save_filename=None):
  nInstances = getNumberOfNodes(envfile, ClusterType)
  my_print('nInstances="%d"' % nInstances)

  nodes2remove = []
  node2cpfiles = []
  
  ErrorOccurred = False
  if ((not FilePartsExists) and (Number2Remove > nInstances)):
    ErrorOccurred = True
    error_message = 'Error Condition: Number of instances to remove (%d) is greater than the number of %s instances (%d). So, NO INSTANCES REMOVED.' % (Number2Remove, ClusterType, nInstances)
    my_print(error_message)
  elif (FilePartsExists and (Number2Remove >= nInstances)):
    ErrorOccurred = True
    error_message = 'Error Condition: Number of instances to remove (%d) is greater than or equal to the number of %s instances (%d). And, file parts exist on instances that would be removed. So, NO INSTANCES REMOVED.' % (Number2Remove, ClusterType, nInstances)
    my_print(error_message)

  if ErrorOccurred:
    return ErrorOccurred, error_message, nodes2remove, node2cpfiles, None

  saveEnv(envfile,ThisDir,save_filename)

  error_message = ''
  for count in range(0,Number2Remove):
    node2remove, node2cpfiles, out_envfile, error_message = removeInstanceFromEnv(ClusterType, FilePartsExists, envfile)
    my_print('node2remove="%s", node2cpfiles="%s", out_envfile="%s"' % (str(node2remove),str(node2cpfiles),out_envfile))
    # if out_envfile is not None this means removeInstanceFromEnv was successful at finding removing "node2remove"
    #  from the environment file and finding "node2cpfiles" if FilePartsExists = True
    if 'Error' not in error_message:
      new_envfile = envfile
      cmd = 'cp %s %s' % (out_envfile, new_envfile)
      rc = os.system(cmd+' 2>&1')
      my_print('RC of bash command, "%s", is "%s"' % (cmd, rc))
      nodes2remove.append(node2remove)
    else: # Error occurred
      ErrorOccurred = True
      if len(nodes2remove) > 0:
        message = 'Error Occurred. "removeInstanceFromEnv" returned NULL out_envfile. So, restore environment file, %s.' % envfile
        my_print(message)
        cmd = 'cp %s %s' % (save_filename, envfile)
        rc = os.system(cmd+' 2>&1')
        my_print('RC of bash command, "%s", is "%s"' % (cmd, rc))
      break

  # Because we checked, above, for cases where Number2Remove was greater than or equal to the number of instances
  #  in the given cluster (ClusterType), if we have an error hear, it is UNEXPECTED.
  return ErrorOccurred, error_message, nodes2remove, node2cpfiles, save_filename
