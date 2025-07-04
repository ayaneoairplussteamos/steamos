#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

set -e

echo "options snd-hda-intel index=1 patch=hda-jack-retask.fw,hda-jack-retask.fw,hda-jack-retask.fw,hda-jack-retask.fw dyndbg" > /etc/modprobe.d/hda-jack-retask.conf
cat << EOF > /lib/firmware/hda-jack-retask.fw
[codec]
0x10ec0269 0x1f660103 0
 
[pincfg]
0x12 0x90a60130
0x14 0x90170110
0x17 0x40000000
0x18 0x04a19040
0x19 0x411111f0
0x1a 0x90170110
0x1b 0x411111f0
0x1d 0x40e69945
0x1e 0x411111f0
0x21 0x04214020
EOF