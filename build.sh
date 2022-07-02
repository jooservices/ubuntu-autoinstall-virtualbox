#!/bin/bash

set -Eeuo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

source ./variables/core
source ./sources/core

# The most common use of the trap command though is to trap the bash-generated psuedo-signal named EXIT
trap cleanup SIGINT SIGTERM ERR EXIT

# Create directories
log "\e[33m🧩 Ubuntu directory \e[1m${ubuntu_dir}\e[0m"
mkdir -p ${ubuntu_dir}
log "\e[33m🧩 Ubuntu directory \e[1m${build_dir}\e[0m"
mkdir -p ${build_dir}

source ./sources/ubuntu
source ./sources/vm

### GENERATE ISO ###
./sources/build_ubuntu_iso -a -r -u ${tmp_userdata_file}
### END GENERATE ISO ###

### GENERATE VM ###
./sources/build_vm
### END VM ###

# Done
die "✅ Build completed." 0