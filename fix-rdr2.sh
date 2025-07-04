#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/fix-rdr2.sh" | sh

set -e

compatdata_path="$HOME/.steam/steam/steamapps/compatdata"
id="1174180"
system_xml="$compatdata_path/$id/pfx/drive_c/users/steamuser/Documents/Rockstar Games/Red Dead Redemption 2/Settings/system.xml"
if [ -f "$system_xml" ]; then
    # set adapterIndex to 0
    sed -i 's/<adapterIndex value="[0-9]"/<adapterIndex value="0"/' "$system_xml"
    echo "Red Dead Redemption 2 black screen fix applied."
else
    echo "Red Dead Redemption 2 system.xml not found."
    exit 1
fi