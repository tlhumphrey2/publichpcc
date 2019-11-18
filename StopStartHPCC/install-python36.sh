#!/bin/bash
yum install zlib-devel -y
mkdir install-python36; cd install-python36
wget https://www.python.org/ftp/python/3.6.0/Python-3.6.0.tgz
tar -xvzf Python-3.6.0.tgz
# Enter the directory:
cd Python-3.6.0
# Run the configure:
./configure --prefix=/usr/local
# compile and install it:
make
make altinstall
rm -v /etc/alternatives/python
ln -s /usr/local/bin/python3.6 /etc/alternatives/python
# Checking Python version:
python -V

