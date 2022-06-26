#!/bin/bash

set -Eeuo pipefail

source ./variables.sh
source ./functions.sh

# The most common use of the trap command though is to trap the bash-generated psuedo-signal named EXIT
trap cleanup SIGINT SIGTERM ERR EXIT

init

### UPDATE USERDATA ###
## user-data
log "🧩 Copy user-data to ${tmpdir}"
cp ./user-data ${tmp_userdata_file}

log "👷 Updating user-data"
sed -i "s|_hostname|${hostname}|g" "$tmp_userdata_file"
sed -i "s|_password|${password}|g" "$tmp_userdata_file"
sed -i "s|_realname|${realname}|g" "$tmp_userdata_file"
sed -i "s|_username|${username}|g" "$tmp_userdata_file"
sed -i "s|_ssh_key|${ssh_key}|g" "$tmp_userdata_file"

echo "" >> ${tmp_userdata_file}

log "👍 Updated user-data"
cat ${tmp_userdata_file}

### END USERDATA ###

### GENERATE ISO ###
./ubuntu.sh -a -u ${tmp_userdata_file}
### END GENERATE ISO ###

./virtualbox.sh

## Done
die "✅ Build completed." 0