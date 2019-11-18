#!/bin/bash
mkdir install-python34; cd install-python34
wget https://www.python.org/ftp/python/3.4.1/Python-3.4.1.tgz
tar -xvzf Python-3.4.1.tgz
# Enter the directory:
cd Python-3.4.1
# Run the configure:
./configure --prefix=/usr/local --enable-shared
# compile and install it:
make
make altinstall
sudo rm -v /etc/alternatives/python
sudo ln -s /usr/local/bin/python3.4 /etc/alternatives/python
# Checking Python version:
python -V

