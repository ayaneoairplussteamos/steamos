#!/bin/bash

# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/update-mesa-git.sh" | sh

set -e

ACTION=${1:-"--noconfirm"}

API_URL="https://api.github.com/repos/honjow/mesa-git-packages/releases/latest"

RELEASE=$(curl -s $API_URL)

# API Rate Limit check
message=$(echo "$RELEASE" | jq -r '.message')

if [[ "$message" =~ "API rate limit exceeded" ]]; then
    echo "$message" >&2
    exit 1
fi

RELEASE_VERSION=$(echo "$RELEASE" | jq -r '.tag_name')
RELEASE_URL_MESA=$(echo "$RELEASE" | jq -r '.assets[] | select(.browser_download_url | contains("mesa-git") and contains("lib32") | not) | .browser_download_url')
RELEASE_URL_LIB32MESA=$(echo "$RELEASE" | jq -r '.assets[] | select(.browser_download_url | contains("lib32-mesa-git")) | .browser_download_url')

if [ -z "$RELEASE_VERSION" ] || [ -z "$RELEASE_URL_MESA" ] || [ -z "$RELEASE_URL_LIB32MESA" ]; then
    echo "Failed to get latest release info" >&2
    exit 1
fi

echo "Release version: $RELEASE_VERSION"
echo "Release URL Mesa: $RELEASE_URL_MESA"
echo "Release URL Lib32Mesa: $RELEASE_URL_LIB32MESA"

tmp_dir=$(mktemp -d)

mkdir -p $tmp_dir
rm -rf $tmp_dir/*

wget --directory-prefix="$tmp_dir" $RELEASE_URL_MESA $RELEASE_URL_LIB32MESA

pikaur $ACTION -U --overwrite '*' $tmp_dir/*
