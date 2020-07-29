#!/bin/bash
sudo vi /etc/yum/pluginconf.d/priorities.conf<<EOFF
:g/enabled *= *1/s//enabled = 0/
ZZ
EOFF
echo sudo yum update -y
sudo yum update -y
echo sudo rm -v /usr/bin/python3
sudo rm -v /usr/bin/python3
sudo yum install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel -y
if [ -e /install-python36/Python-3.6.1 ];then
 echo cd /install-python36/Python-3.6.1
 cd /install-python36/Python-3.6.1
 echo sudo ./configure --enable-shared --prefix=/usr/lib64
 sudo ./configure --enable-shared --prefix=/usr/lib64
 echo sudo make
 sudo make
 echo sudo make install
 sudo make install
else
 echo sudo /home/ec2-user/install-python36.sh
 sudo /home/ec2-user/install-python36.sh
fi
cd
echo sudo rm -v /usr/bin/pip3
sudo rm -v /usr/bin/pip3
echo sudo ln -s /usr/local/bin/pip3.6 /usr/bin/pip3
sudo ln -s /usr/local/bin/pip3.6 /usr/bin/pip3
#echo sudo pip3 install tensorflow
#sudo /usr/bin/pip3 install tensorflow
echo sudo pip3 install tensorflow-gpu
sudo /usr/bin/pip3 install tensorflow-gpu
echo "python3 -c 'import tensorflow as tf; print(tf.__version__)' 2> /dev/null"
python3 -c 'import tensorflow as tf; print(tf.__version__)' 2> /dev/null
echo sudo add-LD_PRELOAD-for-python36-to-hpcc_setenv.sh
sudo /home/ec2-user/add-LD_PRELOAD-for-python36-to-hpcc_setenv.sh
