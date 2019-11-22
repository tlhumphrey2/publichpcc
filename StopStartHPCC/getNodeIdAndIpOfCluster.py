import sys
import xml.etree.ElementTree as ET
import InfoOfEnv as env

if len(sys.argv) is 0:
  print('USAGE ERROR: Must provide 2 arguments: 1) stackname and 2) ClusterType.')
  exit(1)
else:
  ClusterType = sys.argv[1]

envfile = '/etc/HPCCSystems/environment.xml'
#envfile = './test-add-drop-cluster-instances-7-environment.xml'
tree = ET.parse(envfile)
root = tree.getroot()

node2remove, node2cpfiles = env.getNodeIdAndIpOfCluster(root, ClusterType)
print('node2remove=%s, node2cpfiles=%s' % (node2remove, node2cpfiles))
