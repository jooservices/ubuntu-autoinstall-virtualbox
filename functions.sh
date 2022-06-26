#!/bin/bash

function log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

function cleanup() {    
    if [ -n "${tmpdir+x}" ]; then
        rm -rf "$tmpdir"
        log "🚽 Deleted temporary working directory $tmpdir"
    fi
}

function die() {
    local msg=$1
    local code=${2-1} # Bash parameter expansion - default exit status 1. See https://wiki.bash-hackers.org/syntax/pe#use_a_default_value
    log "$msg"
    exit "$code"
}

function runner()
{
    version=$(curl -I -v -s https://github.com/actions/runner/releases/latest 2>&1 | perl -ne 'next unless s/^< location: //; s{.*/v}{}; s/\s+//; print')
}

function file_exists_check()
{
    [[ ! -f "$1" ]] && die "$2"
}

function package_check()
{
    [[ ! -x "$(command -v $1)" ]] && die "💥 $1 is not installed. On Ubuntu, install  the '$1' package."
}

function curl_download()
{
    curl -NsSL "$1" -o "$2"
    log "👍 Downloaded and saved to $2"
}

function init()
{
    # Create directories
    log "🧩 Ubuntu directory ${ubuntu_dir}"
    mkdir -p ${ubuntu_dir}
    log "🧩 Ubuntu directory ${build_dir}"
    mkdir -p ${build_dir}

    # Read Ubuntu data
    read -e -p 'Name: ' -i "ubuntu-$(date +%s)" vmname
    read -e -p 'Hostname: ' -i "ubuntu" hostname
    read -e -p 'Username: ' -i "soulevil" username
    read -e -p 'Realname: ' -i "SoulEvil" realname
    read -e -p 'Password: ' -i "ubuntu" password
    read ssh_key<~/.ssh/id_ed25519.pub
    password=$(echo "$password" | openssl passwd -6 -salt "$salt" -stdin)
    vmname_slug=$(echo "${vmname}" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/-/g | sed -r s/^-+\|-+$//g | tr A-Z a-z)

    # Read VM data
    read -e -p 'RAM (MB): ' -i "4096" ram
    read -e -p 'CPU: ' -i "4" cpu
    read -e -p 'Storage (MB): ' -i "64000" storage

    export storage
    export cpu
    export ram
    export vmname
    export vmname_slug
    export hostname
    export username
    export password
    export ssh_key
}

export -f log
export -f cleanup
export -f runner
export -f file_exists_check
export -f package_check
export -f curl_download
export -f die
export -f init