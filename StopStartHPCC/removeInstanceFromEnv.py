from __future__ import print_function
import sys
import InfoOfEnv as env

if len(sys.argv) is 0:
  print('USAGE ERROR: Must provide 2 arguments: 1) stackname and 2) ClusterType.')
  exit(1)
else:
  ClusterType = sys.argv[1]
  FilePartsExists0 = sys.argv[2]

FilePartsExists = True if FilePartsExists0 is "1" else False
print('In removeInstanceFromEnv.pl. FilePartsExists = "%s"' % str(FilePartsExists), file=sys.stderr)

envfile = '/etc/HPCCSystems/environment.xml'
#envfile = './test-add-drop-cluster-instances-7-environment.xml'
#envfile = './2-test-add-drop-cluster-instances-7-environment.xml'
#envfile = './3-test-add-drop-cluster-instances-7-environment.xml'

node2remove, node2cpfiles = env.removeInstanceFromEnv(ClusterType, FilePartsExists, envfile)
print('node2remove=%s, node2cpfiles=%s' % (str(node2remove),str(node2cpfiles)))
