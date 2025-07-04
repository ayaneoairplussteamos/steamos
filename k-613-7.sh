#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/k-613-7.sh" | sh

set -eu

pkg_urls=(
    "https://ns.switchsystem.eu.org/d/vfs/guest/stos/pkgs/linux-chimeraos-6.13.7.sko-4-x86_64.pkg.tar.zst"
    "https://ns.switchsystem.eu.org/d/vfs/guest/stos/pkgs/linux-chimeraos-headers-6.13.7.sko-4-x86_64.pkg.tar.zst"
)

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/kernel.sh" | sh -s "${pkg_urls[@]}"