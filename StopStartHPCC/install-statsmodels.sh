sudo yum install -y git
git clone https://github.com/statsmodels/statsmodels
cd statsmodels
sudo pip install .
#sudo pip install --global-option=build_ext  --global-option="-I/usr/local/include/python3.4m" .
