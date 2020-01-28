# HoneyPi-gen
_Tool used to create the honey-pi.de Raspbian images. Based on raspberrypi.org Raspbian images_
This build script uses the official Raspbian build script  (https://github.com/RPi-Distro/pi-gen).

It adds a custom stage to the default Raspbian Lite image build.

## Build the Image
Be sure that you have installed Docker on your System. You will also need a git client installed.
Just start the script by calling:

  sudo ./build-honeypi.sh

## Clean up
For cleaning up the workspace just call

  sudo ./clean.sh

## Build folder.
The build will be placed in the folder ```deploy```

## Requirements

```
brew install coreutils
```


### Thanks
Special thanks to [FabScanPi](https://github.com/mariolukas/FabScanPi-Build-Raspbian) for this build script.
