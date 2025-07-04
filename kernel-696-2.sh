#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel-696-2.sh" | sh

set -eu

pkg_urls=(
    "https://ns.switchsystem.eu.org/d/guest/stos/kernel/linux-chimeraos-6.9.6.sk.chos2-1-x86_64.pkg.tar.zst"
    "https://ns.switchsystem.eu.org/d/guest/stos/kernel/linux-chimeraos-headers-6.9.6.sk.chos2-1-x86_64.pkg.tar.zst"
)

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel.sh" | sh -s "${pkg_urls[@]}"