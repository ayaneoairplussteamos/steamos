#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/hhd_mini2025.sh" | sh

set -e

PYTHON_SITE_PACKAGES_PATH=$(python3 -c "import site; print(site.getsitepackages()[0])")
HHD_PATH="${PYTHON_SITE_PACKAGES_PATH}/hhd"


ORIG_PRODUCT_NAME="G1617-01"
DEST_PRODUCT_NAME="G1617-02"

sudo find "$HHD_PATH" -name "*.py" -exec sed -i "s/$ORIG_PRODUCT_NAME/$DEST_PRODUCT_NAME/g" {} \;