# HoneyPi Raspbian Image Generator [![Build Status](https://travis-ci.com/Honey-Pi/HoneyPi-Build-Raspbian.svg?branch=master)](https://travis-ci.com/Honey-Pi/HoneyPi-Build-Raspbian)
_Tool used to create the HoneyPi images. Based on raspberrypi.org Raspberry Pi OS Lite images_

This build script uses the official Pi-Gen build script (https://github.com/RPi-Distro/pi-gen). It adds a custom stage to the default Raspberry Pi OS Lite (previously known as Raspbian Lite) image build.

## Build the Image
Be sure that you have installed Docker on your System. You will also need a git client installed.
Just start the script by calling:

```
sudo ./build-honeypi.sh
```

## Clean up
For cleaning up the workspace just call

```
sudo ./clean.sh
```

## Build folder
The build will be placed in the folder ```pi-gen/deploy/```

## Requirements

```
brew install coreutils
```

## Acknowledgments
Special thanks to [FabScanPi](https://github.com/mariolukas/FabScanPi-Build-Raspbian) for this build script.
