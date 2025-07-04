#!/bin/bash

# 当前目录
current_dir=$(pwd)

plugins_dir="${current_dir}/plugins"

function download_decky_plugin() {
    local git_api_url="https://api.github.com/repos/$1/releases/latest"
    local grep_expression=${2:-".tar.gz"}

    local max_retries=5
    local retry_count=0
    local base_delay=2
    local download_url=""

    while [ $retry_count -lt $max_retries ] && [ -z "$download_url" ]; do
        if [ $retry_count -gt 0 ]; then
            # 计算指数退避延迟时间，增加随机抖动
            local delay=$((base_delay * 2 ** (retry_count - 1) + RANDOM % 2))
            echo "Retry $retry_count/$max_retries for $git_api_url after waiting ${delay}s..."
            sleep $delay
        fi

        download_url=$(curl -s "$git_api_url" | grep "browser_download_url" | cut -d '"' -f 4 | grep "$grep_expression") || true
        echo "download_url: $download_url"

        if [ -z "$download_url" ]; then
            echo "Failed to get download URL, retry attempt $retry_count/$max_retries"
            retry_count=$((retry_count + 1))
        fi
    done

    if [ -z "$download_url" ]; then
        echo "Failed to get download URL after $max_retries attempts"
        return
    fi

    basename=$(basename "$download_url")

    curl -L "$download_url" -o "${plugins_dir}/${basename}"

    if [ -z "$download_url" ]; then
        echo "Failed to get download URL after $max_retries attempts"
        return
    fi

    echo "Downloaded $basename to $plugins_dir"

}

# HueSync
download_decky_plugin "honjow/HueSync"
# PowerControl
download_decky_plugin "mengmeet/PowerControl"
# aarron-lee/DeckyPlumber
download_decky_plugin "aarron-lee/DeckyPlumber"
# chenx-dust/DeckyClash
download_decky_plugin "chenx-dust/DeckyClash" "DeckyClash.zip"
# aarron-lee/SimpleDeckyTDP
download_decky_plugin "aarron-lee/SimpleDeckyTDP" "SimpleDeckyTDP.zip"
