#!/bin/bash

polkit_path="/usr/bin/steamos-polkit-helpers/steamos-priv-write"

polkit_url="https://gitee.com/honjow/sk-chos-scripts/raw/master/steamos-polkit-helpers/steamos-priv-write"

temp_dir=$(mktemp -d)

curl -L -o "${temp_dir}/steamos-priv-write" "${polkit_url}"

if [ -f "${polkit_path}" ]; then
  sudo mv "${polkit_path}" "${polkit_path}.bak"
fi

sudo install -Dm755 "${temp_dir}/steamos-priv-write" "${polkit_path}"