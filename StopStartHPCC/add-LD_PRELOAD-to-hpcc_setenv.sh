user=`whoami`
sudo chmod 777 /opt/HPCCSystems/sbin/hpcc_setenv
sed "s/\/bin\/bash *$/\/bin\/bash\\nexport LD_PRELOAD=\/usr\/lib64\/libpython3.5m.so.1.0\\n/" /opt/HPCCSystems/sbin/hpcc_setenv > /home/$user/tt
sudo mv -v /home/$user/tt /opt/HPCCSystems/sbin/hpcc_setenv
sudo chmod 755 /opt/HPCCSystems/sbin/hpcc_setenv
