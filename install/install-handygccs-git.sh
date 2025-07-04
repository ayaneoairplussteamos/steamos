#!/bin/bash

set -e

pkgname=handygccs-git

temp_dir=$(mktemp -d)

mkdir -p $temp_dir/$pkgname
cd $temp_dir/$pkgname

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/aur-pkgs/${pkgname}/PKGBUILD" -o PKGBUILD

sudo pacman -Sy
makepkg -fCcs --noconfirm

sudo pacman -U --noconfirm *.pkg.tar.zst --overwrite "*"