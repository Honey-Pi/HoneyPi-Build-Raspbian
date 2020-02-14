#!/bin/bash

# get pi-gen sources
git clone https://github.com/RPi-Distro/pi-gen
cd pi-gen
git fetch && git fetch --tags
git checkout 2020-02-05-raspbian-buster
cd ..

touch pi-gen/stage5/SKIP_IMAGES
touch pi-gen/stage5/SKIP

touch pi-gen/stage4/SKIP_IMAGES
touch pi-gen/stage4/SKIP

# copy config
cp config pi-gen/config

# copy custom stage
cp -R stage-honeypi pi-gen/stage-honeypi

case "$OSTYPE" in
  darwin*)
	echo "Preparing sed to work with OSX"
	sed -i -e 's/sed -r/sed -E/g' pi-gen/build-docker.sh
	;;
esac

echo "Running build..."
cd pi-gen
./build-docker.sh
#./build.sh
