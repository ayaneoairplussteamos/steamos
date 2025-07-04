# shellcheck disable=SC2148,SC2034
#/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/devices/quirks.sh" | sh

set -e
BOARD_NAME="$(cat /sys/devices/virtual/dmi/id/board_name)"

# Claw A1M
BOARD_CLAW_A1M="MS-1T41"

# Claw 8
BOARD_CLAW8="MS-1T52"

if [[ ":$BOARD_CLAW8:" =~ ":$BOARD_NAME:" ]]; then
    echo "Claw 8"
    mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"
    curl -sL "https://gitee.com/honjow/sk-chos-scripts/raw/master/devices/claw8/80-alsa-headroom.conf" \
        >"$HOME/.config/wireplumber/wireplumber.conf.d/80-alsa-headroom.conf"

elif [[ ":$BOARD_CLAW_A1M:" =~ ":$BOARD_NAME:" ]]; then
    echo "Claw A1M"
    mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"
    curl -sL "https://gitee.com/honjow/sk-chos-scripts/raw/master/devices/claw8/80-alsa-headroom.conf" \
        >"$HOME/.config/wireplumber/wireplumber.conf.d/80-alsa-headroom.conf"

# No Match
else
    echo "${BOARD_NAME} does not have a quirk configuration script. Exiting."
fi
