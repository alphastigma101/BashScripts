#!/bin/bash
source ./compatiability.sh 
TYPE=$(uname -m)
KEY=""
ZFS_KEY=""
STATUS="$1"
# Function to compare if version is greater than or equal to the comparison version
version_greater_than_equal() {
    [[ "$(echo -e "$1\n$2" | sort -V | head -n 1)" == "$2" ]]
}

# Function to compare if version is less than or equal to the comparison version
version_less_than_equal() {
    [[ "$(echo -e "$1\n$2" | sort -V | tail -n 1)" == "$2" ]]
}

check_kernel() {
    # Assuming that user merged kernel source from portage
    local pkg=$(cat var/lib/portage/world | grep -E '^sys-kernel\/[[:alpha:]]+-[[:alpha:]]+:[0-9]+\.[0-9]+\.[0-9]+$')
    if echo $pkg | grep -Eq 'gentoo-sources'; then
        # Can't assign an array to the map. Therefore, make it a string
        # and convert it back into an array using mapfile
        INSTALLED_KERNELS["gentoo-sources"]=$pkg
        KEY="gentoo-sources"
    else
        if echo $pkg | grep -Eq 'gentoo-kernel-bin'; then
            INSTALLED_KERNELS["gentoo-kernel-bin"]=$pkg
            KEY="gentoo-kernel-bin"
        else 
            system_update_bug_report
            exit 0
        fi 
    fi
    return 0
}

check_zfs() {
    # Re-Update the installed kernel map
    check_kernel
    curl -s https://packages.gentoo.org/packages/sys-fs/zfs > gentoo_zfs_sources.html
    local line=$(grep -oP 'title="\d+\.\d+\.\d+ [^"]+"' gentoo_zfs_sources.html)
    local installed_zfs=$(cat etc/portage/package.mask/zfs | sed 's/^[^a-zA-Z]*//;s/[[:space:]]*$//')
    local isEmpty=1
    installed_zfs=$(echo "$installed_zfs" | sed 's/[[:space:]]*$//')
    # Create an array that holds zfs and zfs-kmod package versions
    mapfile -t CURRENT_ZFS <<< "$(echo "$installed_zfs" | tr ' ' '\n')"
    local current=${CURRENT_ZFS[0]}
    while read -d '"' -r chunk; do
        if [[ $chunk =~ ^title= ]]; then
            continue  # Skip the "title=" part
        fi
        if [[ $chunk =~ ^([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]is[[:space:]](testing|stable|unknown)[[:space:]]on[[:space:]]([a-z0-9]+)$ ]]; then
            version="${BASH_REMATCH[1]}"
            status="${BASH_REMATCH[2]}"
            architecture="${BASH_REMATCH[3]}"
            # Initialize if empty
            ZFS_DICT[$architecture]="${ZFS_DICT[$architecture]:-}"
            # Append new value
            ZFS_DICT[$architecture]+="$status:$version "
        fi
    done < <(echo "$line")
    local zfs_releases=""
    if [ "$TYPE" == "x86_64" ]; then
        zfs_releases=${ZFS_DICT["amd64"]}
    else 
        zfs_releases=${ZFS_DICT[$TYPE]}
    fi
    IFS=' ' read -r -a lines <<< "$zfs_releases"
    for line in "${lines[@]}"; do
        IFS=':' read -r status_val version_val <<< "$line"
        if [[ "$DEBUG" -eq 1 ]]; then
            echo "Printing out Versions:"
            echo $status_val
            echo "===================================" 
        fi
        # Note: Issue could occur here if the DOM tree structure changes the versions around
        if [ "$STATUS" == "$status_val" ]; then 
            if [ ! -n "$ZFS_KEY" ]; then
                ZFS_KEY="zfs-$version_val" 
            fi
            if [ ! -n "$current" ]; then
                current="sys-fs/zfs-$version_val"
            fi
            AVAILABLE_ZFS["$status_val"]+="sys-fs/zfs-$version_val "
        fi
    done
    # Check to see if the user has the latest version
    local new_zfs=${AVAILABLE_ZFS["$STATUS"]}
    local usr_version=$(echo "$current" | sed 's/.*-\(.*\)/\1/')
    IFS=' ' read -r -a zfs <<< "$new_zfs"
    for ele in "${zfs[@]}"; do
        available_version=$(echo "$ele" | sed 's/^[^:]*://')
        if [[ "$(echo -e "$usr_version\n$available_version" | sort -V | head -n 1)" == "$usr_version" && "$usr_version" != "$available_version" ]]; then
            echo "A zfs update is available! Going to update"
            # rm /etc/portage/package.mask/zfs
            # echo ">=sys-fs/$ZFS_KEY" >> /etc/portage/package.mask/zfs
            # echo ">=sys-fs/zfs-kmod-$available_version" >> /etc/portage/package.mask/zfs
            return 0
        else 
            echo "System has the latest version already installed!"
            exit 0
        fi
    done
    return 0
}
# Function will only install the stable versions
# NOTE: Going to package these scripts and make it so the following flags exist:
# stable, testing, and unknown
install_kernel_resources() {
    local usr_kernel_str=${INSTALLED_KERNELS[$KEY]}
    local available_kernel_str=""
    local build_str=""
    if [ "$TYPE" == "x86_64" ]; then
        available_kernel_str=${ARCH_DICT["amd64"]}
    else 
        available_kernel_str=${ARCH_DICT[$TYPE]}
    fi
    if [ ! -n "$available_kernel_str" ] || [ ! -n "$usr_kernel_str" ]; then
        system_update_bug_report
        exit 0
    fi
    # Split the lines at white-spaces
    IFS=' ' read -r -a lines <<< "$available_kernel_str"
    for line in "${lines[@]}"; do
        IFS=':' read -r status_val version_val <<< "$line"
        if [[ "$DEBUG" -eq 1 ]]; then
            echo "Printing out Versions:"
            echo $status_val
            echo "===================================" 
        fi
        if [ "$STATUS" == "$status_val" ]; then 
            AVAILABLE_KERNELS["$status_val"]+="sys-kernel/"$KEY"":"$version_val"" "
        fi
    done
    mapfile -t usr_kernel_arr <<< "$usr_kernel_str"
    IFS=' ' read -r -a kernel_arr <<< "${AVAILABLE_KERNELS["$STATUS"]}"
    for usr_kernels in "${usr_kernel_arr[@]}"; do
        # Strip off the package name and colon to extract just the version
        usr_version=$(echo "$usr_kernels" | sed 's/^[^:]*://')
        if [ ! -n "$usr_version" ]; then
            system_update_bug_report
            exit 0
        fi
        for available_kernels in "${kernel_arr[@]}"; do
            # Strip off the package name and colon to extract just the version
            available_version=$(echo "$available_kernels" | sed 's/^[^:]*://')
            if [ ! -n "$available_kernels" ]; then
                system_update_bug_report
                exit 0
            fi
            if [[ "$(echo -e "$usr_version\n$available_version" | sort -V | head -n 1)" == "$usr_version" && "$usr_version" != "$available_version" ]]; then
                if [[ ! "$build_str" =~ "linux-$available_version-gentoo" ]]; then
                    build_str+="linux-$available_version-gentoo "
                fi
                # Note: config file needs to be copied somewhere else other than home
                # cp -Prv /lib/modules/$usr_version/.config /home/${USER}/"$user_version_config"
                # emerge -v =sys-kernel/$KEY"-"$available_version
                # emerge --deselect sys-kernel/$KEY"-"$usr_version
                # emerge -a --depclean
            fi
        done 
    done 
    # Remove trailing spaces and newlines
    build_str=$(echo "$build_str" | sed 's/[[:space:]]*$//')
    mapfile -d ' ' -t BUILD_KERNELS <<< "$build_str"
    return 0
}

install_kernel() {
    for build in "${BUILD_KERNELS[@]}"; do
        version=$(echo "$build" | sed 's/^[^-]*-//')
        # eselect kernel set $build
        # cd /usr/src/linux
        # Note: config file needs to be copied somewhere else other than home
        # cp -Prv /home/${USER}/*_config ./.config
        # make menuconfig
        # make -j3 ; make modules && make modules_install
        # cp -Prv arch/x86/boot/bzImage /boot/"vmlinuz-$version-$TYPE"
    done
    return 0
}

install_zfs() {
    local compatible_kernel_ranges=${COMPATIBLE_RELEASES[$ZFS_KEY]}
    local installed_kernels_str=${INSTALLED_KERNELS[$KEY]}
    local start=$(echo "$compatible_kernel_ranges" | cut -d '-' -f1)
    local end=$(echo "$compatible_kernel_ranges" | sed 's/^[^-]*-//')
    mapfile -t kernels <<< "$installed_kernels_str"
    for ele in "${kernels[@]}"; do
        # Strip off the package name and colon to extract just the version
        version=$(echo "$ele" | sed 's/^[^:]*://')
        if version_greater_than_equal "$version" "$start" && version_less_than_equal "$version" "$end"; then
            echo "Kernel version $kernel is within the range ($start - $end)."
            # emerge -C ${CURRENT_ZFS[0]}
            # emerge -C ${CURRENT_ZFS[1]}
            # emerge -1 =sys-fs/$ZFS_KEY
            return 0
        else
            echo "Kernel version $kernel is outside the range ($start - $end)."
        fi
    done 
    return 0
}
update_init() {
    # Need to check and see if the user installed genkernel or dracut
    # Create an array that checks /usr/src/initramfs/lib/modules/*
    # These will be the kernel versions installed
    # There must only be two versions
    # If there is three, remove the lowest kernel version 
    # If not, install the third one and remove the lowest kernel version 
    # If there is not three, then install the latest one that does not go over the range
    # Use lddtree --copy-to-tree /usr/src/initramfs /bin/systemctl 
    # Execute find . crap | cpio more crap | gzip 9 > /boot/initramfs-6.x.x.
    # Note: The 6.x.x must be pulled from the range array so make a string and use it 
    # It will be random
    return 0
}

update_bootloader() {
    # Find out the bootloader that is installed and run the commands to update it 
    return 0
}

populate_data_structures() {
    curl -s https://packages.gentoo.org/packages/sys-kernel/$KEY > kernel_sources.html
    local line=$(grep -oP 'title="\d+\.\d+\.\d+ [^"]+"' kernel_sources.html)
    while read -d '"' -r chunk; do
        if [[ $chunk =~ ^title= ]]; then
            continue  # Skip the "title=" part
        fi
        if [[ $chunk =~ ^([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]is[[:space:]](testing|stable|unknown)[[:space:]]on[[:space:]]([a-z0-9]+)$ ]]; then
            version="${BASH_REMATCH[1]}"
            status="${BASH_REMATCH[2]}"
            architecture="${BASH_REMATCH[3]}"
            # Initialize if empty
            ARCH_DICT[$architecture]="${ARCH_DICT[$architecture]:-}"
            # Append new value
            ARCH_DICT[$architecture]+="$status:$version "
        fi
    done < <(echo "$line")
    return 0
}

clean_up() {
    # Search through the /boot directory and find the file extensions that end with .img 
    # But they match with the vmlinuz-6.x.x 
    # Find the lowest kernel version and remove it
    remove_html 
    return 0
}

main() {
    populate_zfs_releases
    check_kernel
    populate_data_structures
    install_kernel_resources "$STATUS"
    install_kernel
    check_zfs
    install_zfs
    #update_init
    #update_bootloader
    clean_up
}
main
if [[ "$DEBUG" -eq 1 ]]; then
    debug_releases
    debug_arch_dict
    debug_installed_kernel
    debug_stable_kernel
    debug_testing_kernel
fi