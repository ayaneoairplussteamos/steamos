#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel-693-4.sh" | sh

set -eu

pkg_urls=(
    "http://honjow.cn:5044/file/Cloud189/sk-kernel/linux-chimeraos-6.9.3.sk.chos4-1-x86_64.pkg.tar.zst"
    "http://honjow.cn:5044/file/Cloud189/sk-kernel/linux-chimeraos-headers-6.9.3.sk.chos4-1-x86_64.pkg.tar.zst"
)

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel.sh" | sh -s "${pkg_urls[@]}"