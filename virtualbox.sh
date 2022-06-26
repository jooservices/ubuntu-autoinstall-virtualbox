#!/bin/bash

vmpath=$(VBoxManage list systemproperties | grep -i "default machine folder:" \
    | cut -b 24- | awk '{gsub(/^ +| +$/,"")}1')

sascontrollername="SAS Controller"
idecontrollername="IDE Controller"

log "🔧 Using ${build_dir}/${vmname_slug}"

VBoxManage createvm --name "${vmname}" --ostype Ubuntu_64 --register
VBoxManage modifyvm "${vmname}" --memory ${ram}
VBoxManage createhd --filename "${vmpath}/${vmname}/${vmname_slug}.vdi" --size ${storage}
VBoxManage modifyvm "${vmname}" --cpus ${cpu}

VBoxManage storagectl "${vmname}" --name "${sascontrollername}" --add sas --controller LSILogicSAS
VBoxManage storageattach "${vmname}" --storagectl "${sascontrollername}" --port 0 --device 0 --type hdd --medium "${vmpath}/${vmname}/${vmname_slug}.vdi"
## 
VBoxManage storagectl "${vmname}" --name "${sascontrollername}" --hostiocache on
VBoxManage storagectl "${vmname}" --name "${idecontrollername}" --add ide --controller PIIX4
## Mount Autoinstall ISO
VBoxManage storageattach "${vmname}" --storagectl "${idecontrollername}" --port 0 --device 0 --type dvddrive --medium "${build_dir}/${vmname_slug}.iso"

# Description
description=$(<"${tmp_userdata_file}")
VBoxManage modifyvm "${vmname}" --nestedpaging on
VBoxManage modifyvm "${vmname}" --largepages on
VBoxManage modifyvm "${vmname}" --description "${description}"

#VBoxManage modifyvm "${name}" --vrde on
#VBoxManage modifyvm "${name}" --vrdeport 5587
#VBoxManage modifyvm "Ubuntu" --vrde off

VBoxManage showvminfo "${vmname}"
VBoxManage startvm "${vmname}" --type headless