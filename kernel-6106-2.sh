#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel-6106-2.sh" | sh

set -eu

pkg_urls=(
    "https://github.com/3003n/linux-chimeraos/releases/download/v6.10.6.sk-chos2-1/linux-chimeraos-6.10.6.sk.chos2-1-x86_64.pkg.tar.zst"
    "https://github.com/3003n/linux-chimeraos/releases/download/v6.10.6.sk-chos2-1/linux-chimeraos-headers-6.10.6.sk.chos2-1-x86_64.pkg.tar.zst"
)

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel.sh" | sh -s "${pkg_urls[@]}"