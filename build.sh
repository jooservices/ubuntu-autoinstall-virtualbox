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
append_userdata "    channel: 'stable'"
append_userdata "  update: yes"
append_userdata "  packages:"
packages=("zip" "unzip" "git" "curl" "wget")
for package in "${packages[@]}"
do
    :
    append_userdata "    - ${package}"
done

append_userdata "  package_update: true"
append_userdata "  package_upgrade: true"

name="Viet Vu"
email="jooservices@gmail.com"
append_userdata "  user-data:"
append_userdata "    timezone: Asia/Ho_Chi_Minh"
append_userdata "    users:"
append_userdata "      - name: $username"
append_userdata "        gecos: Viet Vu"
#append_userdata "        passwd: $password"
append_userdata "        sudo: ALL=(ALL) NOPASSWD:ALL"
#append_userdata "        ssh_authorized_keys:"
#append_userdata "          - $ssh_key:"
append_userdata "    runcmd:"
append_userdata "      - cd $username"
append_userdata "      - su $username"
append_userdata "      - echo Autoinstall completed under $username"
append_userdata "      - wget https://raw.githubusercontent.com/jooservices/bash/main/services/git.sh"
append_userdata "      - git config --global user.email \"${email}\""
append_userdata "      - git config --global user.name \"${name}\""
append_userdata "      - ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 <<<y >/dev/null 2>&1"

log "👍 Builded user-data"
cat ${tmp_userdata_file}

### END USERDATA ###

### GENERATE ISO ###
./ubuntu.sh -a -r -u ${tmp_userdata_file}
### END GENERATE ISO ###

./virtualbox.sh

## Done
die "✅ Build completed." 0