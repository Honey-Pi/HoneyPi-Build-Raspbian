#!/bin/bash

# get pi-gen sources
git clone https://github.com/RPi-Distro/pi-gen
cd pi-gen
git fetch && git fetch --tags
#git checkout 2020-02-05-raspbian-buster # All images up to HoneyPi v1.0.8-beta10
git checkout 2020-12-02-raspbian-buster
cd ..

# not used because /config already defines STAGE_LIST
#touch pi-gen/stage3/SKIP pi-gen/stage4/SKIP pi-gen/stage5/SKIP
#touch pi-gen/stage3/SKIP_IMAGES pi-gen/stage4/SKIP_IMAGES pi-gen/stage5/SKIP_IMAGES

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
CONTINUE=1 PRESERVE_CONTAINER=1 ./build-docker.sh
#./build-docker.sh
#./build.sh
