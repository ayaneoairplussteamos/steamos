#!/bin/bash

workdir=$HOME/homebrew/data/tomoon
core_path=$HOME/homebrew/plugins/tomoon/bin/core/clash

sudo $core_path -f "${workdir}/running_config.yaml" -d $workdir