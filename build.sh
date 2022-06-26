#!/bin/bash

set -Eeuo pipefail

source ./variables.sh
source ./functions.sh

function append_userdata()
{
    printf "$1\n" >> ${tmp_userdata_file}
}


# The most common use of the trap command though is to trap the bash-generated psuedo-signal named EXIT
trap cleanup SIGINT SIGTERM ERR EXIT

# Create directories
log "🧩 Ubuntu directory ${ubuntu_dir}"
mkdir -p ${ubuntu_dir}
log "🧩 Ubuntu directory ${build_dir}"
mkdir -p ${build_dir}

# Read Ubuntu data
read -e -p 'Name: ' -i "ubuntu-$(date +%s)" vmname
vmname_slug=$(echo "${vmname}" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/-/g | sed -r s/^-+\|-+$//g | tr A-Z a-z)
read -e -p 'Hostname: ' -i "ubuntu" hostname
read -e -p 'Realname: ' -i "SoulEvil" realname
read -e -p 'Username: ' -i "soulevil" username
read -e -p 'Password: ' -i "ubuntu" password
## Encrypt password
password=$(echo "$password" | openssl passwd -6 -salt "$salt" -stdin)
read ssh_key<~/.ssh/id_ed25519.pub

# Read VM data
read -e -p 'RAM (MB): ' -i "4096" ram
read -e -p 'CPU: ' -i "4" cpu
read -e -p 'Storage (MB): ' -i "64000" storage

# VM
export ram
export cpu
export storage

export vmname
export vmname_slug

# Ubuntu
export hostname
export username
export realname
export password

export ssh_key

### USERDATA ###
## user-data

log "👷 Creating user-data"
append_userdata "#cloud-config"
append_userdata "autoinstall:"
append_userdata "  version: 1"
append_userdata "  identity:"
append_userdata "    hostname: $hostname"
append_userdata "    password: $password"
append_userdata "    realname: $realname"
append_userdata "    username: $username"
append_userdata "  ssh:"
append_userdata "    allow-pw: false"
append_userdata "    install-server: true"
append_userdata "    authorized-keys:"
append_userdata "    - $ssh_key"
append_userdata "  refresh-installer:"
append_userdata "    update: yes"
append_userdata "    channel: edge"
append_userdata "  update: yes"
append_userdata "  packages:"
packages=("zip" "unzip" "git")
for package in "${packages[@]}"
do
    :
    append_userdata "    - ${package}"
done

#sed -i "s|_hostname|${hostname}|g" "$tmp_userdata_file"
#sed -i "s|_realname|${realname}|g" "$tmp_userdata_file"
#sed -i "s|_username|${username}|g" "$tmp_userdata_file"
#sed -i "s|_password|${password}|g" "$tmp_userdata_file"
#sed -i "s|_ssh_key|${ssh_key}|g" "$tmp_userdata_file"

#echo "" >> ${tmp_userdata_file}

log "👍 Builded user-data"
cat ${tmp_userdata_file}

### END USERDATA ###

### GENERATE ISO ###
 ./ubuntu.sh -a -r -u ${tmp_userdata_file}
### END GENERATE ISO ###

./virtualbox.sh

## Done
die "✅ Build completed." 0