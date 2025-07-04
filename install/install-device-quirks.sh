#!/bin/bash
# shellcheck disable=SC2154,SC1091

set -e

if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as a normal user, not root."
    exit 1
fi

if [ -x "$(command -v sk-unlock-pacman)" ]; then
    sudo sk-unlock-pacman
fi

conflict_pkgname=chimeraos-device-quirks-git
if [ -x "$(command -v pacman)" ]; then
    pakage_name=$(pacman -Qi $conflict_pkgname 2>/dev/null | awk '{print $1}')
    if [[ "$pakage_name" == "$conflict_pkgname" ]]; then
        sudo pacman -Rdd --noconfirm $conflict_pkgname || true
    fi
fi

check_path="/usr/share/device-quirks/id-device"
check_owner_package=$(LANG=en_US pacman -Qo $check_path 2>/dev/null | awk '{print $5}')

pkgname=${check_owner_package:-"chimeraos-device-quirks-sk"}

temp_dir=$(mktemp -d)

sudo pacman -Sy

mkdir -p "$temp_dir/$pkgname"
cd "$temp_dir/$pkgname"

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/aur-pkgs/${pkgname}/PKGBUILD" -o PKGBUILD

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

if [ -x "$(command -v frzr-tweaks)" ]; then
    sudo frzr-tweaks
fi