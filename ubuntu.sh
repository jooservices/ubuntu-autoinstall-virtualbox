#!/bin/bash

ubuntu_version="20.04"
ubuntu_name="focal"
ubuntu_full_name="Focal Fossa"

# Urls
ubuntu_daily_live_url="https://cdimage.ubuntu.com/ubuntu-server/${ubuntu_name}/daily-live/current"
ubuntu_release_url="https://releases.ubuntu.com/${ubuntu_name}"

# ISO server filename
ubuntu_iso_filename="${ubuntu_name}-live-server-amd64.iso"

# Use daily as default
download_url=${ubuntu_daily_live_url}

# ISO local filename
local_iso_filename="ubuntu-${ubuntu_version}-daily-$today.iso"

ubuntu_gpg_key_id="843938DF228D22F7B3742BC0D94AA3F0EFE21092"        

destination_iso="${build_dir}/${vmname_slug}.iso"

log "🧩 Build ISO: ${vmname_slug}.iso"

usage() {
        cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-a] [-e] [-u user-data-file] [-m meta-data-file] [-k] [-c] [-r] [-s source-iso-file] [-d destination-iso-file]
💁 This script will create fully-automated Ubuntu ${ubuntu_version} ${download_url} installation media.
Available options:
-h, --help              Print this help and exit
-v, --verbose           Print script debug info
-a, --all-in-one        Bake user-data and meta-data into the generated ISO. By default you will
                        need to boot systems with a CIDATA volume attached containing your
                        autoinstall user-data and meta-data files.
                        For more information see: https://ubuntu.com/server/docs/install/autoinstall-quickstart
-e, --use-hwe-kernel    Force the generated ISO to boot using the hardware enablement (HWE) kernel. Not supported
                        by early Ubuntu 20.04 release ISOs.
-u, --user-data         Path to user-data file. Required if using -a
-m, --meta-data         Path to meta-data file. Will be an empty file if not specified and using -a
-k, --no-verify         Disable GPG verification of the source ISO file. By default SHA256SUMS-$today and
                        SHA256SUMS-$today.gpg in ${ubuntu_dir} will be used to verify the authenticity and integrity
                        of the source ISO file. If they are not present the latest daily SHA256SUMS will be
                        downloaded and saved in ${ubuntu_dir}. The Ubuntu signing key will be downloaded and
                        saved in a new keyring in ${ubuntu_dir}
-c, --no-md5            Disable MD5 checksum on boot
-r, --use-release-iso   Use the current release ISO instead of the daily ISO. The file will be used if it already
                        exists.
-s, --source            Source ISO file. By default the latest daily ISO for Ubuntu 20.04 will be downloaded
                        and saved as ${ubuntu_dir}/ubuntu-${ubuntu_version}-daily-$today.iso
                        That file will be used by default if it already exists.
-d, --destination       Destination ISO file. By default ${destination_iso} will be
                        created, overwriting any existing file.
EOF
        exit
}

function parse_params() {
        # default values of variables set from params
        user_data_file=''
        meta_data_file=''

        source_iso="${ubuntu_dir}/${local_iso_filename}"

        sha_suffix="${today}"
        gpg_verify=1

        all_in_one=0
        use_hwe_kernel=0
        md5_checksum=1
        use_release_iso=0

        while :; do
                case "${1-}" in
                -h | --help) usage ;;
                -v | --verbose) set -x ;;
                -a | --all-in-one) all_in_one=1 ;;
                -e | --use-hwe-kernel) use_hwe_kernel=1 ;;
                -c | --no-md5) md5_checksum=0 ;;
                -k | --no-verify) gpg_verify=0 ;;
                -r | --use-release-iso) use_release_iso=1 ;;
                -u | --user-data)
                        user_data_file="${2-}"
                        shift
                        ;;
                -s | --source)
                        source_iso="${2-}"
                        shift
                        ;;
                -d | --destination)
                        destination_iso="${2-}"
                        shift
                        ;;
                -m | --meta-data)
                        meta_data_file="${2-}"
                        shift
                        ;;
                -?*) die "Unknown option: $1" ;;
                *) break ;;
                esac
                shift
        done

        log "👶 Starting up..."

        # check required params and arguments
        if [ ${all_in_one} -ne 0 ]; then
                log "🔎 Checking user-data file: ${user_data_file}"
                [[ -z "${user_data_file}" ]] && die "💥 user-data file was not specified."
                [[ ! -f "$user_data_file" ]] && die "💥 user-data file could not be found."
                [[ -n "${meta_data_file}" ]] && [[ ! -f "$meta_data_file" ]] && die "💥 meta-data file could not be found."
        fi

        if [ "${source_iso}" != "${ubuntu_dir}/${local_iso_filename}" ]; then
                log "🔎 Checking ${source_iso}"
                file_exists_check "${source_iso}" "💥 Source ISO file could not be found."                
        fi

        if [ "${use_release_iso}" -eq 1 ]; then                
                download_url=${ubuntu_release_url}
                log "🔎 Checking for current release..."
                # Fetch version string from header
                ubuntu_iso_filename=$(curl -sSL "${download_url}" | grep -oP 'ubuntu-20\.04\.\d*-live-server-amd64\.iso' | head -n 1)
                local_iso_filename="${ubuntu_iso_filename}"

                source_iso="${ubuntu_dir}/${ubuntu_iso_filename}"
                current_release=$(echo "${ubuntu_iso_filename}" | cut -f2 -d-)
                sha_suffix="${current_release}"
                log "💿 Current release is ${current_release}"                
        fi

        destination_iso=$(realpath "${destination_iso}")
        source_iso=$(realpath "${source_iso}")

        return 0
}

parse_params "$@"

log "🔎 Checking for required utilities..."
package_check "xorriso"
package_check "sed"
package_check "curl"
[[ ! -f "/usr/lib/ISOLINUX/isohdpfx.bin" ]] && die "💥 isolinux is not installed. On Ubuntu, install the 'isolinux' package."
log "👍 All required utilities are installed."

if [ "${use_release_iso}" -eq 1 ];
then
        log "💿 Using release version: ${ubuntu_iso_filename}"
else
        log "💿 Using daily version: ${ubuntu_iso_filename}"
fi

log "🔎 Checking file ${source_iso}"

if [ ! -f "${source_iso}" ]; then
        log "🌎 Downloading ISO image for Ubuntu ${ubuntu_version} ${ubuntu_full_name}..."
        curl_download "${download_url}/${ubuntu_iso_filename}" "${source_iso}"
else
        log "☑️ Using existing ${source_iso} file."
        if [ ${gpg_verify} -eq 1 ]; then                
                if [ "${source_iso}" != "${ubuntu_dir}/${local_iso_filename}" ]; then
                        log "⚠️ Automatic GPG verification is enabled. If the source ISO file is not the latest daily or release image, verification will fail!"
                fi
                log "👍 Verification succeeded."
        fi
fi

if [ ${gpg_verify} -eq 1 ]; then
        log "🔎 Checking for GPG"
        if [ ! -f "${ubuntu_dir}/SHA256SUMS-${sha_suffix}" ]; then
                log "🌎 Downloading SHA256SUMS & SHA256SUMS.gpg files..."
                curl_download "${download_url}/SHA256SUMS" "${ubuntu_dir}/SHA256SUMS-${sha_suffix}"
                curl_download "${download_url}/SHA256SUMS.gpg" "${ubuntu_dir}/SHA256SUMS-${sha_suffix}.gpg"                
        else
                log "☑️ Using existing SHA256SUMS-${sha_suffix} & SHA256SUMS-${sha_suffix}.gpg files."
        fi

        if [ ! -f "${ubuntu_dir}/${ubuntu_gpg_key_id}.keyring" ]; then
                log "🌎 Downloading and saving Ubuntu signing key..."
                gpg -q --no-default-keyring --keyring "${ubuntu_dir}/${ubuntu_gpg_key_id}.keyring" --keyserver "hkp://keyserver.ubuntu.com" --recv-keys "${ubuntu_gpg_key_id}"
                log "👍 Downloaded and saved to ${ubuntu_dir}/${ubuntu_gpg_key_id}.keyring"
        else
                log "☑️ Using existing Ubuntu signing key saved in ${ubuntu_dir}/${ubuntu_gpg_key_id}.keyring"
        fi

        log "🔐 Verifying ${source_iso} integrity and authenticity..."
        gpg -q --keyring "${ubuntu_dir}/${ubuntu_gpg_key_id}.keyring" --verify "${ubuntu_dir}/SHA256SUMS-${sha_suffix}.gpg" "${ubuntu_dir}/SHA256SUMS-${sha_suffix}" 2>/dev/null
        if [ $? -ne 0 ]; then
                rm -f "${ubuntu_dir}/${ubuntu_gpg_key_id}.keyring~"
                die "👿 Verification of SHA256SUMS signature failed."
        fi

        rm -f "${ubuntu_dir}/${ubuntu_gpg_key_id}.keyring~"
        digest=$(sha256sum "${source_iso}" | cut -f1 -d ' ')
        set +e
        grep -Fq "$digest" "${ubuntu_dir}/SHA256SUMS-${sha_suffix}"
        if [ $? -eq 0 ]; then
                log "👍 Verification succeeded."
                set -e
        else
                die "👿 Verification of ISO digest failed."
        fi
else
        log "🤞 Skipping verification of source ISO."
fi

log "🔧 Extracting ISO image..."
xorriso -osirrox on -indev "${source_iso}" -extract / "$tmpdir" &>/dev/null
chmod -R u+w "$tmpdir"
rm -rf "$tmpdir/"'[BOOT]'
log "👍 Extracted to $tmpdir"

if [ ${use_hwe_kernel} -eq 1 ]; then
        if grep -q "hwe-vmlinuz" "$tmpdir/boot/grub/grub.cfg"; then
                log "☑️ Destination ISO will use HWE kernel."
                sed -i -e 's|/casper/vmlinuz|/casper/hwe-vmlinuz|g' "$tmpdir/isolinux/txt.cfg"
                sed -i -e 's|/casper/initrd|/casper/hwe-initrd|g' "$tmpdir/isolinux/txt.cfg"
                sed -i -e 's|/casper/vmlinuz|/casper/hwe-vmlinuz|g' "$tmpdir/boot/grub/grub.cfg"
                sed -i -e 's|/casper/initrd|/casper/hwe-initrd|g' "$tmpdir/boot/grub/grub.cfg"
                sed -i -e 's|/casper/vmlinuz|/casper/hwe-vmlinuz|g' "$tmpdir/boot/grub/loopback.cfg"
                sed -i -e 's|/casper/initrd|/casper/hwe-initrd|g' "$tmpdir/boot/grub/loopback.cfg"
        else
                log "⚠️ This source ISO does not support the HWE kernel. Proceeding with the regular kernel."
        fi
fi

log "🧩 Adding autoinstall parameter to kernel command line..."
sed -i -e 's/---/ autoinstall  ---/g' "$tmpdir/isolinux/txt.cfg"
sed -i -e 's/---/ autoinstall  ---/g' "$tmpdir/boot/grub/grub.cfg"
sed -i -e 's/---/ autoinstall  ---/g' "$tmpdir/boot/grub/loopback.cfg"
log "👍 Added parameter to UEFI and BIOS kernel command lines."

if [ ${all_in_one} -eq 1 ]; then
        log "🧩 Adding user-data and meta-data files..."
        mkdir "$tmpdir/nocloud"
        cp "$user_data_file" "$tmpdir/nocloud/user-data"
        if [ -n "${meta_data_file}" ]; then
                cp "$meta_data_file" "$tmpdir/nocloud/meta-data"
        else
                touch "$tmpdir/nocloud/meta-data"
        fi
        sed -i -e 's,---, ds=nocloud;s=/cdrom/nocloud/  ---,g' "$tmpdir/isolinux/txt.cfg"
        sed -i -e 's,---, ds=nocloud\\\;s=/cdrom/nocloud/  ---,g' "$tmpdir/boot/grub/grub.cfg"
        sed -i -e 's,---, ds=nocloud\\\;s=/cdrom/nocloud/  ---,g' "$tmpdir/boot/grub/loopback.cfg"
        log "👍 Added data and configured kernel command line."
fi

if [ ${md5_checksum} -eq 1 ]; then
        log "👷 Updating $tmpdir/md5sum.txt with hashes of modified files..."
        md5=$(md5sum "$tmpdir/boot/grub/grub.cfg" | cut -f1 -d ' ')
        sed -i -e 's,^.*[[:space:]] ./boot/grub/grub.cfg,'"$md5"'  ./boot/grub/grub.cfg,' "$tmpdir/md5sum.txt"
        md5=$(md5sum "$tmpdir/boot/grub/loopback.cfg" | cut -f1 -d ' ')
        sed -i -e 's,^.*[[:space:]] ./boot/grub/loopback.cfg,'"$md5"'  ./boot/grub/loopback.cfg,' "$tmpdir/md5sum.txt"
        log "👍 Updated hashes."
else
        log "🗑️ Clearing MD5 hashes..."
        echo > "$tmpdir/md5sum.txt"
        log "👍 Cleared hashes."
fi

log "📦 Repackaging extracted files into an ISO image..."
cd "$tmpdir"
xorriso -as mkisofs -r -V "ubuntu-autoinstall-$today" -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -boot-info-table -input-charset utf-8 -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -o "${destination_iso}" . &>/dev/null
cd "$OLDPWD"
log "👍 Repackaged into ${destination_iso}"