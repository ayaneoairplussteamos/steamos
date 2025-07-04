#!/bin/bash

GITHUB_PREFIX="https://ghproxy.homeboyc.cn/https://github.com"

PACKAGE_OVERRIDES="\
    ${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/lib32-libva-mesa-driver-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/lib32-mesa-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/lib32-mesa-vdpau-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/lib32-vulkan-intel-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/lib32-vulkan-radeon-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/libva-mesa-driver-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/mesa-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/mesa-vdpau-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/vulkan-intel-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
	${GITHUB_PREFIX}/ChimeraOS/mesa-chimeraos/releases/download/23.3.0.rc4-chos1-1/vulkan-radeon-23.3.0.rc4.chos1-1-x86_64.pkg.tar.zst \
"

tmp_dir="/tmp/extra_pkgs_233"

mkdir -p $tmp_dir
rm -rf $tmp_dir/*

if [ -n "${PACKAGE_OVERRIDES}" ]; then
	wget --directory-prefix="$tmp_dir" ${PACKAGE_OVERRIDES}
fi

pikaur --noconfirm -U --overwrite '*' $tmp_dir/*