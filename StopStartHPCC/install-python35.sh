#!/bin/bash
yum install zlib-devel -y
mkdir install-python35; cd install-python35
wget https://www.python.org/ftp/python/3.5.1/Python-3.5.1.tgz
tar -xvzf Python-3.5.1.tgz
# Enter the directory:
cd Python-3.5.1
# Run the configure:
./configure --prefix=/usr/local
# compile and install it:
make
make altinstall
sudo rm -v /etc/alternatives/python
sudo ln -s /usr/local/bin/python3.5 /etc/alternatives/python
# Checking Python version:
python -V

