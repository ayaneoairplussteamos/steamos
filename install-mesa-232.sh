#!/bin/bash

GITHUB_PREFIX="https://ghproxy.homeboyc.cn/https://github.com"

PACKAGE_OVERRIDES="\
    ${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/lib32-libva-mesa-driver-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/lib32-mesa-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/lib32-mesa-vdpau-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/lib32-vulkan-intel-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/lib32-vulkan-radeon-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/libva-mesa-driver-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/mesa-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/mesa-vdpau-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/vulkan-intel-23.2.1.chos1-2-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.2.1-chos1-2/vulkan-radeon-23.2.1.chos1-2-x86_64.pkg.tar.zst \
"

tmp_dir="/tmp/extra_pkgs_232"

mkdir -p $tmp_dir
rm -rf $tmp_dir/*

if [ -n "${PACKAGE_OVERRIDES}" ]; then
	wget --directory-prefix="$tmp_dir" ${PACKAGE_OVERRIDES}
fi

pikaur --noconfirm -U --overwrite '*' $tmp_dir/*