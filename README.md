# HoneyPi Image Generator [![Build Status](https://travis-ci.com/Honey-Pi/HoneyPi-Build-Raspbian.svg?branch=master)](https://travis-ci.com/Honey-Pi/HoneyPi-Build-Raspbian) [![HoneyPi CI release](https://github.com/Honey-Pi/HoneyPi-Build-Raspbian/actions/workflows/release.yml/badge.svg?branch=master)](https://github.com/Honey-Pi/HoneyPi-Build-Raspbian/actions/workflows/release.yml)
_Tool used to create the HoneyPi images. Based on raspberrypi.org Raspberry Pi OS Lite images_

This build script uses the official Pi-Gen build script (https://github.com/RPi-Distro/pi-gen). It adds a custom stage to the default Raspberry Pi OS Lite (previously known as Raspbian Lite) image build.

## Quick start

1. [Download latest release](https://github.com/Honey-Pi/HoneyPi-Build-Raspbian/releases)
2. Burn image on sd card
3. Power on your Pi, after your first boot it does automatically reboot, wait some time after the boot. The HoneyPi services are automatically starting.
4. Press the hardware button connected to your Raspberry Pi to start the 'HoneyPi'-AccessPoint (IP: `192.168.4.1`, WiFi-Password: `HoneyPi!`) or connect your Raspberry to your Homenetwork-WiFi.
5. Visit with your browser http://IpOfYourPi/ or http://honeypi.local/ for further configuration.
6. More information on controlling the software can be found in the [main repo](https://github.com/Honey-Pi/HoneyPi). The default SSH password in this pre-built HoneyPi image is `hivescale`. 
7. Have fun!

## Development

### Build the Image
Be sure that you have installed Docker on your System. You will also need a git client installed.
Just start the script by calling:

```
sudo ./build-honeypi.sh
```

### Clean up
For cleaning up the workspace just call

```
sudo ./clean.sh
```

### Build folder
The build will be placed in the folder ```pi-gen/deploy/```

### Requirements

For MacOS:

```
brew install coreutils
```

## Acknowledgments
* Special thanks to [FabScanPi](https://github.com/mariolukas/FabScanPi-Build-Raspbian) for this blueprint.
* Thanks to [HyperBian](https://github.com/hyperion-project/HyperBian) for the GitHub Action.
