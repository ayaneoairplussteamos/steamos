#!/bin/bash
# shellcheck disable=SC2154,SC1091

set -e

# cant run this script as root
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as a normal user, not root."
    exit 1
fi

check_steam_game() {
    # 检查 proton 进程和 SteamLinuxRuntime
    if pgrep -f "/proton " >/dev/null || pgrep -f "/SteamLinuxRuntime" >/dev/null; then
        return 0
    fi

    return 1
}

if check_steam_game; then
    echo "检测到 Steam 游戏正在运行"
    echo "为避免控制器断开连接，请在退出游戏后再次运行更新"
    exit 1
fi

if [ -x "$(command -v sk-unlock-pacman)" ]; then
    sudo sk-unlock-pacman
fi

main_path="/usr/bin/__sk-chos-addon-update"
owner_package=$(LANG=en_US pacman -Qo $main_path 2>/dev/null | awk '{print $5}')

pkgname=${owner_package:-"sk-chos-addon"}

temp_dir=$(mktemp -d)

sudo pacman -Sy

mkdir -p "$temp_dir/$pkgname"
cd "$temp_dir/$pkgname"

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/aur-pkgs/${pkgname}/PKGBUILD" -o PKGBUILD
curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/aur-pkgs/${pkgname}/sk-chos-addon.install" -o sk-chos-addon.install


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
