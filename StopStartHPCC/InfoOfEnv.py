from __future__ import print_function
# NOTE: This routine needs to be executed on the Master so environment.xml can be changed.
import sys
import xml.etree.ElementTree as ET

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
  
def NodeIdAndIp(root, DesiredCluster):
  nodeID = DesiredCluster.get('computer')
  Computer = HardwareComputer(root, nodeID)
  nodeIP = None
  if Computer is None:
    print('In NodeIdAndIp. Could not find nodeIP in Hardware for nodeID="%s".' % str(nodeID), file=sys.stderr)
    NodeIP = None
  else:
    nodeIP = Computer.get('netAddress')
  return [nodeID, nodeIP]
  
def getNodeIdAndIpOfCluster(root, ClusterType):
  ProcessName = 'ThorSlaveProcess' if ClusterType == 'ThorCluster' else 'RoxieServerProcess'
  nodeIdIp = []
  for s in root.find('Software'):
    component_name = s.tag
    if component_name == ClusterType:
      for element in s:
        if element.tag == ProcessName:
          nodeIdIp.append(NodeIdAndIp(root, element))
  for node in nodeIdIp:
    print('In getNodeIdAndIpOfCluster. node of nodeIdIp="%s".' % str(node), file=sys.stderr)
  
  if len(nodeIdIp) == 0:
    node2remove = [None, None]
    node2cpfiles = [None, None]
  elif len(nodeIdIp) >= 2:
    node2remove = nodeIdIp[-1]
    node2cpfiles = nodeIdIp[0]
  else:
    node2remove = nodeIdIp[-1]
    node2cpfiles = [None,None]
  return node2remove, node2cpfiles
  
def countClusters(root):
  ClusterTypes = ['ThorCluster','RoxieCluster']
  count = 0
  for s in root.find('Software'):
    component_name = s.tag
    if component_name in ClusterTypes:
      count = count + 1
  return count
    
def removeTopologyReferences(tree, ClusterType):
  desired_name = 'thor' if ClusterType == 'ThorCluster' else 'roxie'

  root = tree.getroot()
  software = root.find('Software')
  s = software.find('Topology')
  tname = s.tag
  print('Entering removeTopologyReferences. ClusterType="%s", tname="%s".' % (ClusterType,tname), file=sys.stderr)
  nTolologyChildren = len(s.getchildren())
  print('In removeTopologyReferences. nTolologyChildren="%s".' % (nTolologyChildren), file=sys.stderr)
  for child in s.findall('Cluster'):
    cname = child.tag
    print('In removeTopologyReferences. ClusterType="%s", tname="%s", cname="%s".' % (ClusterType,tname,cname), file=sys.stderr)
    if cname == 'Cluster':
      name = child.get('name')
      print('In removeTopologyReferences. ClusterType="%s", tname="%s", name="%s".' % (ClusterType,tname,name), file=sys.stderr)
      if (name == desired_name) or (name == 'thor_roxie'):
        s.remove(child)
        print('In removeTopologyReferences. Of "%s", removed Cluster whose name="%s".' % (tname, name), file=sys.stderr)
  return tree

def removeCluster(tree, ClusterType):
  root = tree.getroot()
  s = root.find('Software')
  sname = s.tag
  print('Entering removeCluster. ClusterType="%s", sname="%s".' % (ClusterType,sname), file=sys.stderr)
  for child in s:
    c = child.tag
    if c == ClusterType:
      s.remove(child)
      tree = removeTopologyReferences(tree,ClusterType)
      print('In removeCluster. ClusterType="%s" was removed.' % ClusterType, file=sys.stderr)
  return tree

def removeElementsContainingNodeId(tree, ClusterType, nodeID):
  root = tree.getroot()
  print('Entering removeElementsContainingNodeId. ClusterType="%s", nodeID="%s"' % (ClusterType,nodeID), file=sys.stderr)

  # Find Computer in Hardware
  s = root.find('Hardware')
  sname = s.tag
  for child in s:
    if child.tag == 'Computer':
      name = child.get('name')
      if ( name == nodeID ):
        s.remove(child)
        print('In removeElementsContainingNodeId. From "%s", removed computer with nodeID="%s"' % (sname,nodeID), file=sys.stderr)
        break

  # Find in Software all computer whose node is nodeID and remove
  Software = root.find('Software')
  for s in Software:
    sname = s.tag
    if len(s) > 0:
      for child in s:
        computer = child.get('computer')
        print('In removeElementsContainingNodeId. s.tag="%s", child.tag="%s", computer="%s", nodeID="%s"' % (sname,child.tag,computer,nodeID), file=sys.stderr)
        if ( computer == nodeID ):
           s.remove(child)
           print('In removeElementsContainingNodeId. From "%s", removed computer with nodeID="%s"' % (child.tag,nodeID), file=sys.stderr)
        computer = None
  return tree

def removeInstanceFromEnv(ClusterType, FilePartsExists, envfile='/etc/HPCCSystems/environment.xml'):
  print('Entering removeInstanceFromEnv. envfile="%s", ClusterType="%s", FilePartsExists="%s"' % (envfile, ClusterType, str(FilePartsExists)), file=sys.stderr)
  tree = ET.parse(envfile)
  root = tree.getroot()

  node2remove, node2cpfiles = getNodeIdAndIpOfCluster(root, ClusterType)
  # Couldn't find nodes to remove
  if node2remove[1] is None:
    return node2remove, node2cpfiles
    
  nodeID = node2remove[0]
  nodeIP = node2remove[1]
  print('In removeInstanceFromEnv. After call to getNodeIdAndIpOfCluster. node2remove="%s", node2cpfiles="%s", nodeID="%s"' % (str(node2remove), str(node2cpfiles), nodeID), file=sys.stderr)
  if (node2cpfiles[0] is None): # There isn't another ClusterType instance where file parts can be removed
    if not FilePartsExists:  # If there aren't file parts then we remove the cluster from the environment.xml file
       tree = removeCluster(tree, ClusterType)
    else: # if there isn't a cluster instance to move file parts and there are file parts then we have an error condition.
       print('In removeInstanceFromEnv.  Since there are file parts on the instance to remove, "%s", but no nodes to copy file parts to, we cannot modify the environment.xml file, "%s". So we EXIT.' % (nodeIP, envfile), file=sys.stderr)
       return node2remove, [None, None]
  tree = removeElementsContainingNodeId(tree, ClusterType, nodeID) # from environment.xml, remove elements containing instance being removed.
  print('In removeInstanceFromEnv. write %s' % envfile, file=sys.stderr)
  #out_envfile = envfile+'-out'
  out_envfile = envfile
  tree.write(out_envfile)
  print('Leaving removeInstanceFromEnv. node2remove="%s"' % str(node2remove), file=sys.stderr)
  print('Leaving removeInstanceFromEnv. node2cpfiles="%s"' % str(node2cpfiles), file=sys.stderr)
  return node2remove, node2cpfiles
