#!/bin/bash
set -eu

pkg_urls=()
for arg in "$@"; do
    pkg_urls+=("$arg")
done

echo "pkg_urls: ${pkg_urls[@]}"

tmp_dir=$(mktemp -d)

for pkg_url in "${pkg_urls[@]}"; do
    if [[ -x "$(command -v aria2c)" ]];then
        aria2c -x 16 -s 16 --auto-file-renaming=false --allow-overwrite=true --console-log-level=warn --dir="$tmp_dir" "$pkg_url"
    else
        wget --directory-prefix="$tmp_dir" "$pkg_url"
    fi
done

sudo rm -f /frzr_root/boot/*-ucode.img || true
sudo rm -f /frzr_root/boot/chimeraos-*_*/* || true
sudo rm -f /frzr_root/boot/*-fallback.img || true

pikaur -Sy
pikaur -S dkms --needed --noconfirm && pikaur --noconfirm -U --overwrite '*' "$tmp_dir"/* || true

rm -rf "$tmp_dir"

if [[ -x $(command -v chos-kernel-mv) ]]; then
    sudo chos-kernel-mv || true
    echo "Moved kernel to boot done!"
fi