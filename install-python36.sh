#!/bin/bash
echo sudo yum update -y
sudo yum update -y
echo sudo rm -v /usr/bin/python3
sudo rm -v /usr/bin/python3
echo sudo yum install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel -y
sudo yum install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel -y
echo mkdir install-python36; cd install-python36
mkdir install-python36; cd install-python36
echo wget https://www.python.org/ftp/python/3.6.1/Python-3.6.1.tgz
wget https://www.python.org/ftp/python/3.6.1/Python-3.6.1.tgz
echo tar -xvzf Python-3.6.1.tgz
tar -xvzf Python-3.6.1.tgz
# Enter the directory:
echo cd Python-3.6.1
cd Python-3.6.1
# Make python3.6
# Run the configure:
echo ./configure --prefix=/usr/local
./configure --prefix=/usr/local
# compile and install it:
echo sudo make
sudo make
echo sudo make altinstall
sudo make altinstall

# Make python3.6 shared object file
# Run the configure:
echo ./configure --enable-shared --prefix=/usr/lib64
./configure --enable-shared --prefix=/usr/lib64
# compile and install it:
echo sudo make
sudo make
echo sudo make altinstall
sudo make altinstall
echo sudo ln -s /usr/lib64/lib/libpython3.6m.so.1.0 /usr/lib64/libpython3.6m.so.1.0
sudo ln -s /usr/lib64/lib/libpython3.6m.so.1.0 /usr/lib64/libpython3.6m.so.1.0
echo sudo ln -s /usr/local/bin/python3.6 /usr/bin/python3.6
sudo ln -s /usr/local/bin/python3.6 /usr/bin/python3.6
echo sudo ln -s /usr/local/bin/python3.6 /usr/bin/python3
sudo ln -s /usr/local/bin/python3.6 /usr/bin/python3
# Checking Python version:
python3.6 -V

