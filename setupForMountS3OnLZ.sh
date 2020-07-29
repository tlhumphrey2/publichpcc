#!/bin/bash
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PATH=${PATH}:/usr/local/bin

# Need both python3.6 and pip3.6 for this script to install everything.
# So we install both here.
$ThisDir/install-python36.sh
$ThisDir/install-pip36.sh

echo sudo yum install ninja-build -y
sudo yum install ninja-build -y

echo sudo pip3 install meson
sudo pip3 install meson

#------------------

OS_VERSION=`awk -F= '/^NAME/{print $2}' /etc/os-release`
OS_UBUNTU=`echo "${OS_VERSION}" | grep -i ubuntu`
OS_AMAZON=`echo "${OS_VERSION}" | grep -i amazon`
OS_CENTOS=`echo "${OS_VERSION}" | grep -i centos`
OS_RHEL=`echo "${OS_VERSION}" | grep -i centos`

if [ -n "${OS_UBUNTU}" ]; then
    PKG_MGR=1 # apt-get
    APT_GET=`which apt-get`
    if [ -z "${APT_GET}" ]; then
        echo "Error: apt-get binary not found in PATH"
        exit
    fi
elif [ -n "${OS_AMAZON}" ] || [ -n "${OS_CENTOS}" ] || [ -n "${OS_RHEL}" ]; then
    PKG_MGR=2 # yum
    YUM=`which yum`
    if [ -z "${YUM}" ]; then
        echo "Error: yum binary not found in PATH"
        exit
    fi
else
    echo "Error: Unknown distro; cannot determine package manager"
    exit
fi

#------------------

WGET=`which wget`

if [ -z "${WGET}" ]; then
    echo "Error: wget binary not found in PATH"
    exit
fi

#------------------

TAR=`which tar`

if [ -z "${TAR}" ]; then
    echo "Error: tar binary not found in PATH"
    exit
fi

#------------------

UNZIP=`which unzip`

if [ -z "${UNZIP}" ]; then
    echo "Error: unzip binary not found in PATH"
    exit
fi

#------------------

# Make sure we have dependencies
if [ ${PKG_MGR} -eq 1 ]; then
    sudo ${APT_GET} install -y meson
elif [ ${PKG_MGR} -eq 2 ]; then
    sudo ${YUM} install -y meson.noarch ninja-build.x86_64
fi

#------------------

MESON=`which meson`

if [ -z "${MESON}" ]; then
    echo "Error: meson binary not found in PATH"
    exit
fi

#------------------

NINJA=`which ninja`

if [ -z "${NINJA}" ]; then
    NINJA=`which ninja-build`
    if [ -z "${NINJA}" ]; then
        echo "Error: ninja binary not found in PATH"
        exit
    fi
fi

#------------------

CURRENT_DIR=`pwd`
SOURCE_DIR=${CURRENT_DIR}/src

if [ ! -d "${SOURCE_DIR}" ]; then
    mkdir -p "${SOURCE_DIR}"
fi

echo "Building in ${SOURCE_DIR}"

#===============================================================================
# libfuse
#===============================================================================

echo
echo "#-------------------------------------------------------------------------------"
echo "# Version 2 of libfuse"
echo "#-------------------------------------------------------------------------------"
echo

# Make sure we have dependencies for the older version
if [ ${PKG_MGR} -eq 2 ]; then
    sudo ${YUM} install -y gettext-devel.x86_64
fi

cd "${SOURCE_DIR}"

# Remove old artifacts
rm -rf fuse-2.9.9.tar.gz libfuse-fuse-2.9.9

# Get the source archive and expand it
${WGET} https://github.com/libfuse/libfuse/archive/fuse-2.9.9.tar.gz
${TAR} -xzf fuse-2.9.9.tar.gz
# Enter the source directory
cd libfuse-fuse-2.9.9

# Create the configuration artifacts
./makeconf.sh

# Build and install
./configure
make && sudo make install

echo
echo "#-------------------------------------------------------------------------------"
echo "# Version 3 of libfuse"
echo "#-------------------------------------------------------------------------------"
echo

cd "${SOURCE_DIR}"

# Remove old artifacts
rm -rf fuse-3.4.2.tar.gz libfuse-fuse-3.4.2

# Get the source archive and expand it
${WGET} https://github.com/libfuse/libfuse/archive/fuse-3.4.2.tar.gz
${TAR} -xzf fuse-3.4.2.tar.gz
# Enter the source directory
cd libfuse-fuse-3.4.2/

# Create a build directory
mkdir build
cd build

# Create the configuration artifacts
${MESON} ..

# Explicitly cite the path of the fuse.c pkgconfig directory
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig

# Build and install
${NINJA}
sudo ${NINJA} install

echo
echo "#-------------------------------------------------------------------------------"
echo "# sshfs"
echo "#-------------------------------------------------------------------------------"
echo

# Make sure we have dependencies
if [ ${PKG_MGR} -eq 2 ]; then
    sudo ${YUM} install -y glib2-devel.x86_64
fi

cd "${SOURCE_DIR}"

# Remove old artifacts
rm -rf sshfs-3.5.1.tar.gz sshfs-sshfs-3.5.1

# Get the source archive and expand it
${WGET} https://github.com/libfuse/sshfs/archive/sshfs-3.5.1.tar.gz
${TAR} -xzf sshfs-3.5.1.tar.gz

# Enter the source directory
cd sshfs-sshfs-3.5.1/

# Create a build directory
mkdir build
cd build

# Create the configuration artifacts
${MESON} ..

# Explicitly cite the path of the fuse.c pkgconfig directory
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig

# Add an rpath
if [ -n "${OS_AMAZON}" ] || [ -n "${OS_CENTOS}" ] || [ -n "${OS_RHEL}" ]; then
    sed -i -e 's|--end-group|--end-group -Wl,-rpath /usr/local/lib64|' build.ninja
else
    sed -i -e 's|--end-group|--end-group -Wl,-rpath /usr/local/lib/x86_64-linux-gnu|' build.ninja
fi

# Build and install
${NINJA}
sudo ${NINJA} install

# The installed binary in /usr/local/bin won't link to libfuse, but the local
# version is okay; copy it
sudo cp sshfs /usr/local/bin/

echo
echo "#-------------------------------------------------------------------------------"
echo "# s3fs"
echo "#-------------------------------------------------------------------------------"
echo

cd "${SOURCE_DIR}"

# Make sure we have dependencies
if [ ${PKG_MGR} -eq 1 ]; then
    sudo ${APT_GET} install -y libcurl3 libxml2-dev libssl-dev
elif [ ${PKG_MGR} -eq 2 ]; then
    sudo ${YUM} install -y libcurl-devel.x86_64 libxml2-devel openssl-devel.x86_64
fi

# Remove old artifacts
rm -rf master.zip s3fs-fuse-master

# Get the source archive and expand it
${WGET} https://github.com/s3fs-fuse/s3fs-fuse/archive/master.zip
${UNZIP} master.zip

# Enter the source directory
cd s3fs-fuse-master/

# Create the configuration artifacts
./autogen.sh

# Explicitly cite the path of the fuse.c pkgconfig directory
if [ -n "${OS_AMAZON}" ] || [ -n "${OS_CENTOS}" ] || [ -n "${OS_RHEL}" ]; then
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib64/pkgconfig
else
    export PKG_CONFIG_PATH=/usr/local/lib/x86_64-linux-gnu/pkgconfig
fi

# Build and install
./configure

# Add an rpath
if [ -n "${OS_AMAZON}" ] || [ -n "${OS_CENTOS}" ] || [ -n "${OS_RHEL}" ]; then
    sed -i -e 's|$(AM_V_CXXLD)$(CXXLINK) $(s3fs_OBJECTS) $(s3fs_LDADD) $(LIBS)|$(AM_V_CXXLD)$(CXXLINK) $(s3fs_OBJECTS) $(s3fs_LDADD) $(LIBS) -Wl,-rpath /usr/local/lib|' src/Makefile
fi

make && sudo make install

echo
echo "#-------------------------------------------------------------------------------"
echo "# archive"
echo "#-------------------------------------------------------------------------------"
echo

cd "${SOURCE_DIR}"

# Make sure we have dependencies
if [ ${PKG_MGR} -eq 1 ]; then
    sudo ${APT_GET} install -y libarchive-dev
elif [ ${PKG_MGR} -eq 2 ]; then
    sudo ${YUM} install -y libarchive-devel.x86_64
fi

# Remove old artifacts
rm -rf archivemount-0.8.12.tar.gz archivemount-0.8.12

# Get the source archive and expand it
${WGET} https://www.cybernoia.de/software/archivemount/archivemount-0.8.12.tar.gz
${TAR} -xzf archivemount-0.8.12.tar.gz

# Enter the source directory
cd archivemount-0.8.12

# Fix configure.ac
sed -i '5 a AM_PROG_CC_C_O' configure.ac

# Create the configuration artifacts
autoreconf -i

# Explicitly cite the path of the fuse.c pkgconfig directory
if [ -n "${OS_AMAZON}" ] || [ -n "${OS_CENTOS}" ] || [ -n "${OS_RHEL}" ]; then
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
else
    export PKG_CONFIG_PATH=/usr/local/lib/x86_64-linux-gnu/pkgconfig
fi

# Build and install
./configure

# Add an rpath
if [ -n "${OS_AMAZON}" ] || [ -n "${OS_CENTOS}" ] || [ -n "${OS_RHEL}" ]; then
    sed -i -e 's|archivemount_LDADD = $(ARCHIVE_LIBS) $(FUSE_LIBS)|archivemount_LDADD = $(ARCHIVE_LIBS) $(FUSE_LIBS) -Wl,-rpath /usr/local/lib|' Makefile
fi

make && sudo make install

echo TLH sudo yum install mailcap -y
sudo yum install mailcap -y

echo
echo "#-------------------------------------------------------------------------------"
echo "# install lzmount"
echo "#-------------------------------------------------------------------------------"
echo

cd "${CURRENT_DIR}"
echo TLH sudo cp -v $ThisDir/lzmount /usr/local/bin/
sudo cp -v $ThisDir/lzmount /usr/local/bin/
echo TLH sudo cp -v $ThisDir/exec_lzmount /home/hpcc
sudo cp -v $ThisDir/exec_lzmount /home/hpcc
echo TLH sudo chown hpcc:hpcc /home/hpcc/exec_lzmount
sudo chown hpcc:hpcc /home/hpcc/exec_lzmount

