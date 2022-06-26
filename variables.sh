#!/bin/bash

tmpdir=$(mktemp -d)
if [[ ! "$tmpdir" || ! -d "$tmpdir" ]]; then
        die "Could not create temporary working directory."
else
        echo "Created temporary working directory $tmpdir"
fi

tmp_userdata_file=${tmpdir}/user-data
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
build_dir="${script_dir}/builds"
ubuntu_dir="${script_dir}/ubuntu"

[[ ! -x "$(command -v date)" ]] && echo "💥 date command not found." && exit 1
today=$(date +"%Y-%m-%d")

salt=$(openssl rand -base64 12)

export tmpdir
export tmp_userdata_file
export script_dir
export build_dir
export ubuntu_dir
export today
export salt