#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/ibus-py.sh" | sh

set -eu

ibus_pinyin_url="https://archive.archlinux.org/packages/i/ibus-pinyin/ibus-pinyin-1.5.0-8-x86_64.pkg.tar.zst"

temp_dir=$(mktemp -d)

curl -L "$ibus_pinyin_url" -o "$temp_dir/ibus-pinyin.pkg.tar.zst"

sudo pacman -U "$temp_dir/ibus-pinyin.pkg.tar.zst" --noconfirm --needed

echo "ibus-pinyin 安装成功"