#!/bin/bash
# shellcheck disable=SC2154,SC1091

set -e

# cant run this script as root
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as a normal user, not root."
    exit 1
fi

# Function to retrieve values from a .conf file
# Usage: getValue filename section key
get_conf_value() {
    local filename="$1"
    local section="$2"
    local key="$3"

    local section_found=false
    local key_found=false
    local values=()

    while IFS= read -r line || [[ -n $line ]]; do
        # Remove leading and trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Check if the line is a comment or empty
        if [[ $line == \#* ]] || [[ -z $line ]]; then
            continue
        fi

        # Check if the line matches the section header
        if [[ $line == "[$section]" ]]; then
            section_found=true
        elif [[ $line == '['* ]]; then
            # If a new section is encountered, break
            if $section_found; then
                break
            fi
        elif $section_found; then
            # Check if the line contains the desired key
            if [[ $line == *"$key"* ]]; then
                local value=$(echo "$line" | sed -n "s/.*$key *= *\([^ ]*\).*/\1/p")
                values+=("$value")
                key_found=true
            fi
        fi
    done <"$filename"

    if $key_found; then
        if [ "${#values[@]}" -eq 1 ]; then
            # If only one value is found, return it
            echo "${values[0]}"
        else
            # If multiple values are found, return them as an array
            echo "${values[@]}"
        fi
    fi
}

# /usr/bin/sk-unlock-pacman
if [ -f "/bin/bash/sk-unlock-pacman" ]; then
    sudo /usr/bin/sk-unlock-pacman
fi

main_path="/usr/bin/sk-chos-tool"
owner_package=$(LANG=en_US pacman -Qo $main_path 2>/dev/null | awk '{print $5}')

pkgname=${owner_package:-"sk-chos-tool"}

# download sk-chos-tool.AppImage
RELEASE=$(curl -s "https://api.github.com/repos/honjow/sk-chos-tool/releases/latest" --connect-timeout 10)

# if $RELEASE not starting with '{', then there is an error
if [[ "x${RELEASE:0:1}" != "x{" ]]; then
    github_prefix=""
    RELEASE=$(curl -s ${EMUDECK_GITHUB_URL})
fi

MESSAGE=$(echo "$RELEASE" | jq -r '.message')

if [[ "$MESSAGE" != "null" ]]; then
    echo "$MESSAGE" >&2
    exit 1
fi

RELEASE_VERSION=$(echo "$RELEASE" | jq -r '.tag_name')
RELEASE_URL=$(echo "$RELEASE" | jq -r '.assets[0].browser_download_url')

if [ -z "$RELEASE_VERSION" ] || [ -z "$RELEASE_URL" ]; then
    echo "Failed to get latest release info" >&2
    exit 1
fi

cdn_file="/etc/github_cdn.conf"
release_cdns=$(get_conf_value "$cdn_file" "release" "server")
# convert to array
release_cdns=($release_cdns)

count=${#release_cdns[@]}

if [ $count -gt 0 ]; then
    echo "Found $count release CDN(s) in $cdn_file"
    # radom select a cdn
    github_release_prefix=${release_cdns[$RANDOM % $count]}
    echo "Using release CDN: $github_release_prefix"

    if /usr/bin/is_enable_github_cdn 2>/dev/null; then
        if [[ -n "$github_release_prefix" ]]; then
            # replace 'https://github.com' with the custom prefix
            RELEASE_URL=$(echo $RELEASE_URL | sed "s|https://github.com|${github_release_prefix}|")
            echo "RELEASE_URL: ${RELEASE_URL}"
        fi
    fi
fi

temp_dir=$(mktemp -d)

mkdir -p "$temp_dir/$pkgname"
cd "$temp_dir/$pkgname"

curl -L "${RELEASE_URL}" --connect-timeout 20 -o sk-chos-tool.AppImage

# if size of sk-chos-tool.AppImage is less than 5MB, then it is not a valid AppImage
if [ $(stat -c %s sk-chos-tool.AppImage) -lt 5000000 ]; then
    echo "Failed to download sk-chos-tool.AppImage" >&2
    exit 1
fi

sudo pacman -Sy

curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/aur-pkgs/${pkgname}/PKGBUILD" -o PKGBUILD
curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/aur-pkgs/${pkgname}/sk-chos-tool.install" -o sk-chos-tool.install

version=${RELEASE_VERSION#v}
sed -i "s/^pkgver=.*/pkgver=${version}/" PKGBUILD

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
