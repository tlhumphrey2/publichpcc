wget ftp://195.220.108.108/linux/epel/7/x86_64/r/R-3.3.1-2.el7.x86_64.rpm
wget ftp://rpmfind.net/linux/epel/7/x86_64/r/R-devel-3.3.1-2.el7.x86_64.rpm
wget ftp://195.220.108.108/linux/epel/7/x86_64/r/R-java-devel-3.3.1-2.el7.x86_64.rpm
wget ftp://rpmfind.net/linux/epel/7/x86_64/r/R-core-devel-3.3.1-2.el7.x86_64.rpm
wget ftp://195.220.108.108/linux/epel/7/x86_64/r/R-core-3.3.1-2.el7.x86_64.rpm
wget ftp://fr2.rpmfind.net/linux/centos/7.2.1511/os/x86_64/Packages/tk-8.5.13-6.el7.x86_64.rpm
wget ftp://fr2.rpmfind.net/linux/centos/7.2.1511/os/x86_64/Packages/tk-devel-8.5.13-6.el7.x86_64.rpm
wget ftp://rpmfind.net/linux/centos/7.2.1511/os/x86_64/Packages/xdg-utils-1.1.0-0.16.20120809git.el7.noarch.rpm
wget ftp://rpmfind.net/linux/epel/7/x86_64/l/libRmath-devel-3.3.1-2.el7.x86_64.rpm
wget ftp://195.220.108.108/linux/epel/7/x86_64/r/R-java-3.3.1-2.el7.x86_64.rpm
wget ftp://rpmfind.net/linux/epel/7/x86_64/l/libRmath-3.3.1-2.el7.x86_64.rpm
wget ftp://195.220.108.108/linux/epel/7/x86_64/t/tre-devel-0.8.0-10.el7.x86_64.rpm
wget ftp://fr2.rpmfind.net/linux/epel/7/x86_64/t/tre-0.8.0-10.el7.x86_64.rpm

sudo yum install R-3.3.1-2.el7.x86_64.rpm R-devel-3.3.1-2.el7.x86_64.rpm R-java-devel-3.3.1-2.el7.x86_64.rpm R-core-devel-3.3.1-2.el7.x86_64.rpm R-core-3.3.1-2.el7.x86_64.rpm tk-8.5.13-6.el7.x86_64.rpm tk-devel-8.5.13-6.el7.x86_64.rpm xdg-utils-1.1.0-0.16.20120809git.el7.noarch.rpm libRmath-devel-3.3.1-2.el7.x86_64.rpm R-java-3.3.1-2.el7.x86_64.rpm libRmath-3.3.1-2.el7.x86_64.rpm tre-devel-0.8.0-10.el7.x86_64.rpm tre-0.8.0-10.el7.x86_64.rpm

wget http://wpc.423a.rhocdn.net/00423A/releases/CE-Candidate-6.0.2/bin/platform/hpccsystems-platform-community_6.0.2-1.el7.x86_64.rpm
wget http://wpc.423a.rhocdn.net/00423A/releases/CE-Candidate-6.0.2/bin/plugins/hpccsystems-plugin-rembed_6.0.2-1.el7.x86_64.rpm

sudo yum install hpccsystems-platform-community_6.0.2-1.el7.x86_64.rpm hpccsystems-plugin-rembed_6.0.2-1.el7.x86_64.rpm

************The Below commands install additional R packages for the FDA project*****************

wget ftp://fr2.rpmfind.net/linux/epel/7/x86_64/R-Rcpp-0.12.6-1.el7.x86_64.rpm
wget ftp://195.220.108.108/linux/epel/7/x86_64/R-RInside-0.2.13-3.el7.x86_64.rpm
wget ftp://mirror.switch.ch/pool/4/mirror/epel/7/x86_64/r/R-Rcpp-devel-0.12.6-1.el7.x86_64.rpm

sudo yum install R-RInside-0.2.13-3.el7.x86_64.rpm R-Rcpp-0.12.6-1.el7.x86_64.rpm lapack lapack-devel R-devel Rcpp-devel R-Rcpp-devel-0.12.6-1.el7.x86_64.rpm

wget ftp://fr2.rpmfind.net/linux/centos/7.2.1511/os/x86_64/Packages/cppunit-1.12.1-11.el7.x86_64.rpm
wget ftp://fr2.rpmfind.net/linux/centos/7.2.1511/os/x86_64/Packages/cppunit-devel-1.12.1-11.el7.x86_64.rpm
wget ftp://195.220.108.108/linux/epel/7/x86_64/g/glpk-4.52.1-2.el7.x86_64.rpm
wget ftp://fr2.rpmfind.net/linux/epel/7/x86_64/g/glpk-devel-4.52.1-2.el7.x86_64.rpm

sudo yum install cppunit-1.12.1-11.el7.x86_64.rpm cppunit-devel-1.12.1-11.el7.x86_64.rpm glpk-4.52.1-2.el7.x86_64.rpm glpk-devel-4.52.1-2.el7.x86_64.rpm 

wget http://liquidtelecom.dl.sourceforge.net/project/mcmc-jags/JAGS/4.x/Source/JAGS-4.2.0.tar.gz

sudo ./configure --with-jags-modules=/usr/local/lib/JAGS/modules --libdir=/usr/local/lib64
sudo make
sudo make check
sudo make install

sudo R
install.packages("metafor")
install.packages("meta")
Sys.setenv(PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig")
Sys.setenv(LD_LIBRARY_PATH="/usr/lib64/JAGS")
Sys.setenv(JAGS_LIBDIR="/usr/local/lib64")
Sys.setenv(LD_RUN_PATH="/usr/local/lib64")
Sys.setenv(CPATH="/usr/include/glpk")
install.packages("gemtc")
