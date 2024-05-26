#!/bin/bash -e

# Function to run commands in the chroot environment
run_in_chroot() {
  echo "Running in chroot: $1"
  on_chroot << EOF
$1
EOF
}

# Function to check and update config files
update_config_file() {
  local file=$1
  local pattern=$2
  local entry=$3
  echo "Updating $file: Adding $entry"
  if grep -q "$pattern" "$file"; then
    echo "Seems $pattern parameter already set in $file, skipping."
  else
    echo "$entry" >> "$file"
  fi
}

# Default paths
CONFIG_PATH="${ROOTFS_DIR}/boot/config.txt"
CMDLINE_PATH="${ROOTFS_DIR}/boot/cmdline.txt"

# Update paths if the files contain "DO NOT EDIT THIS FILE"
echo "Checking for 'DO NOT EDIT THIS FILE' in config.txt and cmdline.txt"
for file in config.txt cmdline.txt; do
  if grep -q 'DO NOT EDIT THIS FILE' "${ROOTFS_DIR}/boot/$file"; then
    eval "${file^^}_PATH=\"${ROOTFS_DIR}/boot/firmware/$file\""
  fi
done

# Set Debian frontend to Noninteractive
echo "Setting Debian frontend to Noninteractive"
run_in_chroot "
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
update-ca-certificates -f
"

# Download and set up HoneyPi Installer
echo "Cloning HoneyPi repository"
if [ ! -d "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi" ]; then
  run_in_chroot "
  git clone --depth=1 https://github.com/Honey-Pi/HoneyPi.git /home/${FIRST_USER_NAME}/HoneyPi
  git config --global --add safe.directory /home/${FIRST_USER_NAME}/HoneyPi
  chmod -R 775 /home/${FIRST_USER_NAME}/HoneyPi
  chown -R pi:pi /home/${FIRST_USER_NAME}/HoneyPi
  "
else
  echo "HoneyPi repository already exists, skipping clone."
fi

# Enable I2C
echo 'Enabling I2C'
for module in i2c-bcm2708 i2c-dev; do
  update_config_file "${ROOTFS_DIR}/etc/modules" "^$module" "$module"
done
for param in "dtparam=i2c1=on" "dtparam=i2c_arm=on"; do
  update_config_file "$CONFIG_PATH" "^$param" "$param"
done

# Enable 1-Wire
echo 'Enabling 1-Wire'
for module in w1_gpio w1_therm; do
  update_config_file "${ROOTFS_DIR}/etc/modules" "^$module" "$module"
done
update_config_file "$CONFIG_PATH" "^dtoverlay=w1-gpio" "dtoverlay=w1-gpio,gpiopin=$w1gpio"

# Enable Wifi-Stick on Raspberry Pi 1 & 2
echo 'Enabling Wifi-Stick on Raspberry Pi 1 & 2'
update_config_file "$CMDLINE_PATH" "^net.ifnames=0" "net.ifnames=0"

# Enable miniuart-bt on Raspberry Pi and set core frequency
echo "Enabling miniuart-bt and setting core frequency"
update_config_file "$CONFIG_PATH" "dtoverlay=pi3-miniuart-bt" "dtoverlay=pi3-miniuart-bt"
update_config_file "$CONFIG_PATH" "core_freq=250" "core_freq=250"

# Enable HDMI safe mode
echo 'Enabling HDMI safe mode'
update_config_file "$CONFIG_PATH" "^hdmi_safe=1" "hdmi_safe=1"

# Create www-data user and add pi to www-data group
echo 'Creating www-data user and adding pi to www-data group'
run_in_chroot "usermod -G www-data -a pi"

# Give shell-scripts rights
echo 'Updating sudoers for www-data'
if ! grep -q 'www-data ALL=NOPASSWD: ALL' "${ROOTFS_DIR}/etc/sudoers"; then
  run_in_chroot "echo 'www-data ALL=NOPASSWD: ALL' | EDITOR='tee -a' visudo"
fi

# Install NTP and configure pip and required libraries
echo 'Configuring NTP'
run_in_chroot "
dpkg-reconfigure -f noninteractive ntp
mkdir -p /var/log/ntpsec/
mkdir -p /etc/ntpsec/
"

echo 'Configuring pip and setting global.break-system-packages'
run_in_chroot "
python3 -m pip config set global.break-system-packages true
mv /usr/lib/python3.11/EXTERNALLY-MANAGED /usr/lib/python3.11/EXTERNALLY-MANAGED.old || true
export PIP_ROOT_USER_ACTION=ignore
python3 -m pip install --upgrade pip
"

echo 'Removing old rpi.gpio to replace it with rpi-lgpio wheel'
run_in_chroot "
apt-get purge python{,3}-rpi.gpio
"

echo 'Installing required Python libraries'
run_in_chroot "
pip3 install -r /home/${FIRST_USER_NAME}/HoneyPi/requirements.txt
python3 -m pip install --upgrade setuptools wheel
"

echo 'Configuring BCM2709 hardware'
run_in_chroot "
echo -e '\nHardware   : BCM2709' >> /etc/cpuinfo
if [ -e /etc/cpuinfo ]; then
  mount --bind /etc/cpuinfo /proc/cpuinfo
fi
"

echo 'Installing additional Python libraries'
run_in_chroot "
pip3 install Adafruit_DHT
pip3 install Adafruit_Python_DHT
pip3 install timezonefinder==6.1.8 numpy
"

# Install configuration files
echo 'Installing configuration files'
install -m 755 files/wvdial.conf "${ROOTFS_DIR}/etc/wvdial.conf"
install -m 755 files/wvdial.conf.tmpl "${ROOTFS_DIR}/etc/wvdial.conf.tmpl"
install -m 644 files/wvdial "${ROOTFS_DIR}/etc/ppp/peers/wvdial"
install -m 644 files/lighttpd.conf "${ROOTFS_DIR}/etc/lighttpd/lighttpd.conf"
install -m 644 files/ntp.conf "${ROOTFS_DIR}/etc/ntpsec/ntp.conf"
install -m 644 files/motd "${ROOTFS_DIR}/etc/motd"

# Enable HoneyPi Service
echo 'Enabling HoneyPi Service'
install -m 644 files/honeypi.service "${ROOTFS_DIR}/lib/systemd/system/honeypi.service"
run_in_chroot "
systemctl daemon-reload
systemctl enable honeypi.service
"

# Enable rc.local
echo 'Enabling rc.local'
run_in_chroot "
chmod +x /etc/rc.local
systemctl enable rc-local.service
"

# Set bash as default shell
echo 'Setting bash as default shell'
run_in_chroot "
ln -s bash /bin/sh.bash
mv /bin/sh.bash /bin/sh
"

# Set Up Raspberry Pi as Access Point
echo 'Setting up Raspberry Pi as Access Point'
run_in_chroot "
systemctl disable dnsmasq
systemctl disable hostapd || (systemctl unmask hostapd && systemctl disable hostapd)
systemctl stop dnsmasq
systemctl stop hostapd
"

# Setup Wifi Configuration
echo 'Setting up Wifi Configuration'
if ! grep -q 'network={' "${ROOTFS_DIR}/etc/wpa_supplicant/wpa_supplicant.conf"; then
  install -m 600 files/wpa_supplicant.conf  "${ROOTFS_DIR}/etc/wpa_supplicant/wpa_supplicant.conf"
  run_in_chroot "chmod +x /etc/wpa_supplicant/wpa_supplicant.conf"
fi
install -m 644 files/dhcpcd.conf "${ROOTFS_DIR}/etc/dhcpcd.conf"
install -m 644 files/dnsmasq.conf "${ROOTFS_DIR}/etc/dnsmasq.conf"
install -m 644 files/hostapd.conf.tmpl "${ROOTFS_DIR}/etc/hostapd/hostapd.conf.tmpl"
install -m 644 files/hostapd "${ROOTFS_DIR}/etc/default/hostapd"



# Install unzip if missing
echo 'Installing unzip if missing'
apt-get -y update && apt-get -y install --no-install-recommends zip unzip

# Function to get the latest release from a GitHub repository
get_latest_release() {
  local repo=$1
  local stable=$2
  echo "Fetching latest release for $repo"
  if [ "$stable" -eq 1 ]; then
    curl --silent "https://api.github.com/repos/$repo/releases/latest" -k | grep -Po '"tag_name": "\K.*?(?=")'
  else
    curl --silent "https://api.github.com/repos/$repo/tags" -k | grep -Po '"name": "\K.*?(?=")' | head -1
  fi
}

# Install latest HoneyPi runtime measurement scripts
echo 'Installing latest HoneyPi runtime measurement scripts'
REPO="Honey-Pi/rpi-scripts"
ScriptsTag=$(get_latest_release $REPO $STABLE)
if [ -n "$ScriptsTag" ]; then
  echo "Downloading HoneyPi scripts: $ScriptsTag"
  rm -rf "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts"
  wget -q "https://codeload.github.com/$REPO/zip/$ScriptsTag" -O "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiScripts.zip"
  unzip -q "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiScripts.zip" -d "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi"
  mv "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts-${ScriptsTag//v}" "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts"
else
  echo "Failed to fetch or download HoneyPi scripts."
fi

# Enable file rights to HoneyPi scripts
echo 'Setting file rights for HoneyPi scripts'
run_in_chroot "
chown -R pi:pi /home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts
chmod -R 775 /home/${FIRST_USER_NAME}/HoneyPi/rpi-scripts
"

# Install latest HoneyPi web interface
echo 'Installing latest HoneyPi web interface'
REPO="Honey-Pi/rpi-webinterface"
WebinterfaceTag=$(get_latest_release $REPO $STABLE)
if [ -n "$WebinterfaceTag" ]; then
  echo "Downloading HoneyPi web interface: $WebinterfaceTag"
  rm -rf "${ROOTFS_DIR}/var/www/html"
  wget -q "https://codeload.github.com/$REPO/zip/$WebinterfaceTag" -O "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiWebinterface.zip"
  unzip -q "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/HoneyPiWebinterface.zip" -d "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi"
  mkdir -p "${ROOTFS_DIR}/var/www"
  mv "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-webinterface-${WebinterfaceTag//v}/dist" "${ROOTFS_DIR}/var/www/html"
  mv "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/HoneyPi/rpi-webinterface-${WebinterfaceTag//v}/backend" "${ROOTFS_DIR}/var/www/html/backend"
else
  echo "Failed to fetch or download HoneyPi web interface."
fi

# Enable file rights to HoneyPi web interface
echo 'Setting file rights for HoneyPi web interface'
run_in_chroot "
chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html
"

# Reload Lighttpd to apply changes
echo 'Reloading Lighttpd to apply changes'
run_in_chroot "service lighttpd force-reload || echo 'Lighttpd reload failed, continuing.'"


# Set folder permissions
echo 'Setting folder permissions for /home/pi'
run_in_chroot "
sudo chown -R pi:pi /home/pi
sudo chmod -R 755 /home/pi
"

# Create File with version information
DATE=$(date +%d-%m-%y)
echo "HoneyPi (last install on RPi: $DATE)" > "${ROOTFS_DIR}/var/www/html/version.txt"
echo "rpi-scripts $ScriptsTag" >> "${ROOTFS_DIR}/var/www/html/version.txt"
echo "rpi-webinterface $WebinterfaceTag" >> ${ROOTFS_DIR}/var/www/html/version.txt
echo "postupdatefinished 1" >> "${ROOTFS_DIR}/var/www/html/version.txt"
