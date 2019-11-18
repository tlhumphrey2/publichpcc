mkdir hpcc;cd hpcc;
plugin=http://wpc.423A.edgecastcdn.net/00423A/releases/CE-Candidate-6.2.22/bin/plugins/hpccsystems-plugin-pyembed_6.2.22-1.el6.x86_64.rpm
wget="wget $plugin"
sudo $wget
install="yum install $plugin -y"
sudo $install
plugin=http://wpc.423A.edgecastcdn.net/00423A/releases/CE-Candidate-6.2.22/bin/plugins/hpccsystems-plugin-rembed_6.2.22-1.el6.x86_64.rpm
wget="wget $plugin"
sudo $wget
install="yum install $plugin -y"
sudo $install

