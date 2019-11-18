#!/bin/bash
mkdir install-python27; cd install-python27
wget http://www.python.org/ftp/python/2.7.8/Python-2.7.8.tar.xz
xz -d Python-2.7.8.tar.xz
tar -xvf Python-2.7.8.tar
# Enter the directory:
cd Python-2.7.8
# Run the configure:
./configure --prefix=/usr/local
# compile and install it:
make
make altinstall
sudo rm -v /etc/alternatives/python
sudo ln -s /usr/local/bin/python2.7 /etc/alternatives/python
# Checking Python version:
python -V

