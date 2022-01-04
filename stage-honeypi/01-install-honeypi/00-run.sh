#!/bin/bash -e

on_chroot << EOF
echo '>>> Set Debian frontend to Noninteractive'
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive

echo '>>> Update CA certs for a secure connection to GitHub'
update-ca-certificates -f

echo '>>> Download latest HoneyPi Installer'
git clone --depth=1 https://github.com/Honey-Pi/HoneyPi.git /home/${FIRST_USER_NAME}/HoneyPi

echo '>>> Set file rights to /home/pi/HoneyPi'
chmod -R 775 /home/${FIRST_USER_NAME}/HoneyPi
chown -R pi:pi /home/${FIRST_USER_NAME}/HoneyPi
EOF

# default gpio for Ds18b20, per default raspbian would use gpio 4
w1gpio=11

# enable I2C on Raspberry Pi
# enable 1-Wire on Raspberry Pi
echo '>>> Enable I2C and 1-Wire'
if grep -q '^i2c-dev' ${ROOTFS_DIR}/etc/modules; then
  echo '1 - Seems i2c-dev module already exists, skip this step.'
else
  echo 'i2c-dev' >> ${ROOTFS_DIR}/etc/modules
fi
if grep -q '^w1_gpio' ${ROOTFS_DIR}/etc/modules; then
  echo '2 - Seems w1_gpio module already exists, skip this step.'
else
  echo 'w1_gpio' >> ${ROOTFS_DIR}/etc/modules
fi
if grep -q '^w1_therm' ${ROOTFS_DIR}/etc/modules; then
  echo '3 - Seems w1_therm module already exists, skip this step.'
else
  echo 'w1_therm' >> ${ROOTFS_DIR}/etc/modules
fi
if grep -q '^dtoverlay=w1-gpio' ${ROOTFS_DIR}/boot/config.txt; then
  echo '4 - Seems w1-gpio parameter already set, skip this step.'
else
  echo 'dtoverlay=w1-gpio,gpiopin='$w1gpio >> ${ROOTFS_DIR}/boot/config.txt
fi
if grep -q '^dtparam=i2c_arm=on' ${ROOTFS_DIR}/boot/config.txt; then
  echo '5 - Seems i2c_arm parameter already set, skip this step.'
else
  echo 'dtparam=i2c_arm=on' >> ${ROOTFS_DIR}/boot/config.txt
fi

# Enable Wifi-Stick on Raspberry Pi 1 & 2
if grep -q '^net.ifnames=0' ${ROOTFS_DIR}/boot/cmdline.txt; then
  echo '6 - Seems net.ifnames=0 parameter already set, skip this step.'
else
  echo 'net.ifnames=0' >> ${ROOTFS_DIR}/boot/cmdline.txt
fi

echo '>>> Give shell-scripts rights'
if grep -q 'www-data ALL=NOPASSWD: ALL' ${ROOTFS_DIR}/etc/sudoers; then
  echo 'Seems www-data already has the rights, skip this step.'
else
  on_chroot << EOF
echo 'www-data ALL=NOPASSWD: ALL' | EDITOR='tee -a' visudo
EOF
fi

on_chroot << EOF
# Install NTP for time synchronisation with wittyPi
dpkg-reconfigure -f noninteractive ntp

echo '>>> Install software for measurement python scripts'
pip3 install -r /home/${FIRST_USER_NAME}/HoneyPi/requirements.txt --upgrade

echo '>>> Install software for Webinterface'
lighttpd-enable-mod fastcgi
lighttpd-enable-mod fastcgi-php
EOF

on_chroot << EOF
echo '>>> Create www-data user'
usermod -G www-data -a pi
EOF

install -m 755 files/wvdial.conf "${ROOTFS_DIR}/etc/wvdial.conf"
install -m 755 files/wvdial.conf.tmpl "${ROOTFS_DIR}/etc/wvdial.conf.tmpl"
install -m 644 files/wvdial "${ROOTFS_DIR}/etc/ppp/peers/wvdial"
install -m 644 files/lighttpd.conf "${ROOTFS_DIR}/etc/lighttpd/lighttpd.conf"

#echo '>>> Put Measurement Script into Autostart'
#if grep -q "/rpi-scripts/main.py" ${ROOTFS_DIR}/etc/rc.local; then
#  echo 'Seems measurement main.py already in rc.local, skip this step.'
#else
#  sed -i -e '$i \(sleep 2;python3 /home/'${FIRST_USER_NAME}'/HoneyPi/rpi-scripts/main.py)&\n' ${ROOTFS_DIR}/etc/rc.local
#fi

echo '>>> Enable HoneyPi Service as Autostart'
sed -i '/(sleep 2;python3/c\#' /etc/rc.local # disable autostart in rc.local
install -m 644 files/honeypi.service "${ROOTFS_DIR}/lib/systemd/system/honeypi.service"
on_chroot << EOF
systemctl daemon-reload
systemctl enable honeypi.service
EOF

on_chroot << EOF
echo '>>> Enable rc.local'
chmod +x /etc/rc.local
systemctl enable rc-local.service
EOF

on_chroot << EOF
echo '>>> Use bash as default shell interpreter'
ln -s bash /bin/sh.bash
mv /bin/sh.bash /bin/sh
EOF

on_chroot << EOF
echo '>>> Set Up Raspberry Pi as Access Point'
systemctl disable dnsmasq
systemctl disable hostapd || (systemctl unmask hostapd && systemctl disable hostapd)
systemctl stop dnsmasq
systemctl stop hostapd
EOF

echo '>>> Setup Wifi Configuration'
if grep -q 'network={' ${ROOTFS_DIR}/etc/wpa_supplicant/wpa_supplicant.conf; then
  echo 'Seems networks are configure, skip this step.'
else
  install -m 600 files/wpa_supplicant.conf  "${ROOTFS_DIR}/etc/wpa_supplicant/wpa_supplicant.conf"
  on_chroot << EOF
chmod +x /etc/wpa_supplicant/wpa_supplicant.conf
EOF
fi
install -m 644 files/dhcpcd.conf "${ROOTFS_DIR}/etc/dhcpcd.conf"

# Start in client mode
# Configuring the DHCP server (dnsmasq)
install -m 644 files/dnsmasq.conf "${ROOTFS_DIR}/etc/dnsmasq.conf"
# Configuring the access point host software (hostapd)
install -m 644 files/hostapd.conf.tmpl "${ROOTFS_DIR}/etc/hostapd/hostapd.conf.tmpl"
install -m 644 files/hostapd "${ROOTFS_DIR}/etc/default/hostapd"

#on_chroot << EOF
#echo '>>> Add timeout for networking service'
#mkdir -p /etc/systemd/system/networking.service.d/
#bash -c 'echo -e "[Service]\nTimeoutStartSec=60sec" > /etc/systemd/system/networking.service.d/timeout.conf'
#systemctl daemon-reload
#EOF

# i don't know why but unzip command was not found anymore on pi-gen
echo '>>> Install unzip because somehow it is missing since RaspiOS'
apt-get -y update && apt-get -y install zip unzip

STABLE=0

function get_latest_release() {
    REPO=$1
    STABLE=$2
    if [ $STABLE = 1 ]; then
        # return latest stable release
        result="$(curl --silent "https://api.github.com/repos/$REPO/releases/latest" -k | grep -Po '"tag_name": "\K.*?(?=")')"
    else
        # return lastest release, which can be also a pre-releases (alpha, beta, rc)
        result="$(curl --silent "https://api.github.com/repos/$REPO/tags" -k | grep -Po '"name": "\K.*?(?=")' | head -1)"
    fi
    echo "$result"
}

REPO="Honey-Pi/rpi-scripts"
ScriptsTag=$(get_latest_release $REPO $STABLE)
echo ">>> Install latest HoneyPi runtime measurement scripts ($ScriptsTag) from $REPO stable=$STABLE"
if [ ! -z "$ScriptsTag" ]; then
    rm -rf ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts # remove folder to download latest
    echo ">>> Downloading latest rpi-scripts ($ScriptsTag)"
    wget -q "https://codeload.github.com/$REPO/zip/$ScriptsTag" -O ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiScripts.zip
    unzip -q ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiScripts.zip -d ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi
    mv ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts-${ScriptsTag//v} ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts
    sleep 1
    rm ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiScripts.zip
    # set file rights
    on_chroot << EOF
echo '>>> Set file rights to python scripts'
chown -R pi:pi /home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts
chmod -R 775 /home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts
EOF
else
    echo '>>> Something went wrong. Updating rpi-scripts skiped.'
fi

REPO="Honey-Pi/rpi-webinterface"
WebinterfaceTag=$(get_latest_release $REPO $STABLE)
echo ">>> Install latest HoneyPi webinterface ($WebinterfaceTag) from $REPO stable=$STABLE"
if [ ! -z "$WebinterfaceTag" ]; then
    rm -rf ${ROOTFS_DIR}/var/www/html # remove folder to download latest
    echo ">>> Downloading latest rpi-webinterface ($WebinterfaceTag)"
    wget -q "https://codeload.github.com/$REPO/zip/$WebinterfaceTag" -O ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiWebinterface.zip
    unzip -q ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiWebinterface.zip -d ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi
    mkdir -p ${ROOTFS_DIR}/var/www
    mv ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-webinterface-${WebinterfaceTag//v}/dist ${ROOTFS_DIR}/var/www/html
    mv ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-webinterface-${WebinterfaceTag//v}/backend ${ROOTFS_DIR}/var/www/html/backend
    touch ${ROOTFS_DIR}/var/www/html/backend/settings.json # create empty file to give rights to
    sleep 1
    rm -rf ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-webinterface-${WebinterfaceTag//v}
    rm ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiWebinterface.zip
    # set file rights
    on_chroot << EOF
echo '>>> Set file rights to webinterface'
chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html
EOF
else
    echo '>>> Something went wrong. Updating rpi-webinterface skiped.'
fi

# Create File with version information
DATE=`date +%d-%m-%y`
echo "HoneyPi (last install on RPi: $DATE)" > ${ROOTFS_DIR}/var/www/html/version.txt
echo "rpi-scripts $ScriptsTag" >> ${ROOTFS_DIR}/var/www/html/version.txt
echo "rpi-webinterface $WebinterfaceTag" >> ${ROOTFS_DIR}/var/www/html/version.txt
echo "postupdatefinished 1" >> ${ROOTFS_DIR}/var/www/html/version.txt # because this is the most-recent release
