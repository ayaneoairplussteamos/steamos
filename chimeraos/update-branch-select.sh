#!/bin/bash
# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/chimeraos/update-branch-select.sh" | sh
# curl -L https://tinyurl.com/sk-update-bs | sh

set -e

BRANCH_SELECT_URL="https://gitee.com/honjow/sk-chos-scripts/raw/master/chimeraos/os-branch-select"
BRANCH_SELECT_FILE="/usr/lib/os-branch-select"

temp_file=$(mktemp)

curl -L "$BRANCH_SELECT_URL" -o "$temp_file"

if [[ -f "$temp_file" ]]; then
  sudo cp -f "$temp_file" "$BRANCH_SELECT_FILE"
  sudo chmod 755 "$BRANCH_SELECT_FILE"
fi

rm -f "$temp_file"

echo "更新完成"
