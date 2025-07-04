#!/bin/bash
# shellcheck disable=SC2154,SC1091

set -e

# cant run this script as root
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as a normal user, not root."
    exit 1
fi

# /usr/bin/sk-unlock-pacman
if [ -x "$(command -v sk-unlock-pacman)" ]; then
    sudo sk-unlock-pacman
fi

pkgname=gamescope-session-git

temp_dir=$(mktemp -d)

sudo pacman -Sy

mkdir -p "$temp_dir/$pkgname"
cd "$temp_dir/$pkgname"

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/aur-pkgs/${pkgname}/PKGBUILD" -o PKGBUILD
curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/aur-pkgs/${pkgname}/gamescope-session.install" -o gamescope-session.install

# 比较版本
installed_pkgver=$(pacman -Q "$pkgname" 2>/dev/null | awk '{print $2}')
makepkg -fCcs --nobuild --noconfirm
source PKGBUILD

full_pkgver="${pkgver}-${pkgrel}"

echo "installed_pkgver: $installed_pkgver"
echo "pkgver: $full_pkgver"

if [ -z "$installed_pkgver" ] || [ "$(vercmp "$full_pkgver" "$installed_pkgver")" -gt 0 ]; then
    echo "安装新版本 $pkgname"
    PKGDEST=$(pwd) pikaur --noconfirm --rebuild -P PKGBUILD --overwrite "*"
else
    echo "已安装最新版本 $pkgname"
    exit 0
fi

sudo pacman -U --noconfirm *.pkg.tar.zst --overwrite "*" --needed