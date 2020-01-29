#!/bin/bash -e

# configure firstboot options
install -m 777 files/rc.local "${ROOTFS_DIR}/etc/rc.local"
install -m 777 files/firstboot.sh "${ROOTFS_DIR}/root/firstboot.sh"

on_chroot << EOF
	systemctl enable rc-local
EOF
