#!/bin/bash -e

on_chroot << EOF
cd /home/pi/
echo '>>> Set Debian frontend to Noninteractive'
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
echo '>>> Update & Upgrade'
apt-get update && apt-get dist-upgrade -y
apt-get install -y git
echo '>>> Download latest HoneyPi Installer'
git clone --depth=1 https://github.com/Honey-Pi/HoneyPi.git HoneyPi
cd HoneyPi
echo '>>> Run HoneyPi Installer'
sh ./install.sh
EOF
