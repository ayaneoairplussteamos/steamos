#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel-611-3-sk1-3.sh" | sh

set -eu

pkg_urls=(
    "https://github.com/3003n/linux-chimeraos/releases/download/v6.11.3-sk1-3/linux-chimeraos-6.11.3.sk1-3-x86_64.pkg.tar.zst"
    "https://github.com/3003n/linux-chimeraos/releases/download/v6.11.3-sk1-3/linux-chimeraos-headers-6.11.3.sk1-3-x86_64.pkg.tar.zst"
)

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel.sh" | sh -s "${pkg_urls[@]}"