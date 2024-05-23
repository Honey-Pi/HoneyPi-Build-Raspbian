#!/bin/bash

# get pi-gen sources
git clone https://github.com/RPi-Distro/pi-gen
cd pi-gen
git fetch && git fetch --tags
#git checkout 2020-02-05-raspbian-buster # Up to image v1.0.8-beta10
#git checkout 2020-12-02-raspbian-buster # Up to image v1.1
#git checkout 2021-03-04-raspbian-buster # Used for image v1.3
#git checkout 2023-02-21-raspios-bullseye # Used for images after Dec 2023 v1.4
#git checkout 2023-12-05-raspios-bookworm # v1.5.2
git checkout 2024-03-15-raspios-bookworm # v1.5.3 (fixed GPIO issue on bookworm OS on Raspi Zero/5 devices)
cd ..

# copy config
[ -e pi-gen/config ] && rm -R pi-gen/config
cp config pi-gen/config

# copy custom stage
[ -e pi-gen/stage-honeypi ] && rm -R pi-gen/stage-honeypi
cp -R stage-honeypi pi-gen/stage-honeypi

case "$OSTYPE" in
  darwin*)
	echo "Preparing sed to work with OSX"
	sed -i -e 's/sed -r/sed -E/g' pi-gen/build-docker.sh
	;;
esac

echo "Running build..."
cd pi-gen
PRESERVE_CONTAINER=0 CONTINUE=0 ./build-docker.sh
#CLEAN=1 ./build.sh

