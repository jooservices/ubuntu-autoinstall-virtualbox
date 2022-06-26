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

export -f log
export -f cleanup
export -f runner
export -f file_exists_check
export -f package_check
export -f curl_download
export -f die