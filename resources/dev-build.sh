#!/bin/sh
# Builds my current dev version ... need to have branch identified right!!!

# For those who find bash painful "$#" is the eqivalent 
#   of the count of arguments after the program name
if  [ $# -eq 0 ]; then
   TARGET_BRANCH="master"
else
   TARGET_BRANCH="$1"
fi

clear

echo "Retrieving repo and checking out: $TARGET_BRANCH"
echo "==> Building dev version"
cd /
echo "--> ... be at root"
echo "--> ... clearing all Fabmo dirs"

sudo systemctl stop fabmo
echo "--> ... Stopped fabmo service"

sudo rm -rf /fabmo
sudo rm -rf /opt/fabmo
echo

echo "--> Cloning current version of FabMo Engine from GitHub"
cd /
sudo git clone https://github.com/fabmo/fabmo-engine ./fabmo

cd /fabmo
echo

echo "--> Setting Branch"
sudo git checkout $TARGET_BRANCH

git status
echo

echo "--> Ready for npm install"
sudo npm install

echo
echo "================================================="
echo "==> Seem to have done it ... "
echo "STARTING FabMo!"
echo "================================== check path! =="
echo
sudo npm run build
sudo systemctl restart fabmo; tail -f /var/log/daemon.log


