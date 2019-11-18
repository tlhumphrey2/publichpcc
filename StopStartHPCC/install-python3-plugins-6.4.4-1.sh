mkdir hpcc;cd hpcc;
plugin=http://wpc.423A.edgecastcdn.net/00423A/releases/CE-Candidate-6.4.4/bin/plugins/hpccsystems-plugin-py3embed_6.4.4-1.el7.x86_64.rpm
wget="wget $plugin"
sudo $wget
install="yum install $plugin -y"
sudo $install

