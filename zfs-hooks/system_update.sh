#!/bin/bash
source ./compatiability.sh 
TYPE=$(uname -m)
KEY=""
ZFS_KEY=""
STATUS="$1"

# Function that will check to see if there is an update or not
check_kernel() {
    # Assuming that user merged kernel source from portage
    local pkg=$(cat /var/lib/portage/world | grep -E '^sys-kernel\/[[:alpha:]]+-[[:alpha:]]+:[0-9]+\.[0-9]+\.[0-9]+$')
    if echo $pkg | grep -Eq 'gentoo-sources'; then
        # Can't assign an array to the map. Therefore, make it a string
        # and convert it back into an array using mapfile
        INSTALLED_KERNELS["gentoo-sources"]=$pkg
        KEY="gentoo-sources"
        # TODO Need to find the most latest stable version and increment it by one
        touch /etc/portage/package.mask/gentoo-sources
        #echo >=
    else
        if echo $pkg | grep -Eq 'gentoo-kernel-bin'; then
            INSTALLED_KERNELS["gentoo-kernel-bin"]=$pkg
            KEY="gentoo-kernel-bin"
            # TODO Need to find the most latest stable version and increment it by one
            touch /etc/portage/package.mask/gentoo-kernel-bin
            #echo >=
        else
            system_update_bug_report
            exit 0
        fi 
    fi
    return 0
}
# Function that will check and see if there is an update for zfs
check_zfs() {
    # Re-Update the installed kernel map
    check_kernel
    curl -s https://packages.gentoo.org/packages/sys-fs/zfs > gentoo_zfs_sources.html
    local line=$(grep -oP 'title="\d+\.\d+\.\d+ [^"]+"' gentoo_zfs_sources.html)
    local installed_zfs=$(cat /etc/portage/package.mask/zfs | sed 's/^[^a-zA-Z]*//;s/[[:space:]]*$//')
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
            if [ -d "/etc/portage/package.mask" ]; then 
                rm /etc/portage/package.mask/zfs
                echo ">=sys-fs/$ZFS_KEY" >> /etc/portage/package.mask/zfs
                echo ">=sys-fs/zfs-kmod-$available_version" >> /etc/portage/package.mask/zfs
            else
                echo ">=sys-fs/$ZFS_KEY" >> /etc/portage/package.mask
                echo ">=sys-fs/zfs-kmod-$available_version" >> /etc/portage/package.mask
            fi
            return 0
        else 
            echo "System has the latest version already installed!"
            exit 0
        fi
    done
    return 0
}
# Function that will install the new kernel 
install_kernel() {
    local usr_kernel_str=${INSTALLED_KERNELS[$KEY]}
    local output=0
    local copy_config=0
    for build in "${BUILD_KERNELS[@]}"; do
        version=$(echo "$build" | sed 's/^[^-]*-//')
        eselect kernel set $build
        cd /usr/src/linux || error "install_kernel" "Folder /usr/src/linux does not exist!"
        # Note: config file needs to be copied somewhere else other than home
        if [ "$copy_config" -ne 1 ]; then
            config=$(ls /home/masterkuckles/*-config | head -n 1)
            cp -Prv $config ./.config
            copy_config=1
        fi
        if [ ! -d "/lib/modules/$version-$TYPE" ]; then 
            make menuconfig
            make -j3 || error "install_kernel" "Failed to compile" && \
            make modules_install || error "install_kernel" "Failed to install modules" && \
            make install || error "install_kernel" "Failed to install kernel"
            cp -Prv arch/x86/boot/bzImage /boot/"vmlinuz-$version-$TYPE"
        fi
        if [ -d "/usr/src/initramfs" ]; then
            new_path="$version-$TYPE"
            if [[ "$output" -eq 0 ]]; then
                echo "==================================="
                echo "Creating the directories in /usr/src/initramfs!"
                output=1
            fi
            if [ -d "/usr/src/initramfs/lib" ] && [ -d "/usr/src/initramfs/lib/modules" ]; then
                if [ ! -d "/usr/src/initramfs/lib/modules/$new_path" ]; then  
                    mkdir -vp /usr/src/initramfs/lib/modules/$new_path
                fi
            else
                if [ ! -d  "/usr/src/initramfs/lib" ]; then
                    mkdir -vp /usr/src/initramfs/lib 
                fi
                if [ ! -d "/usr/src/initramfs/lib/modules" ]; then 
                    mkdir -vp /usr/src/initramfs/lib/modules
                fi
                if [ ! -d "/usr/src/initramfs/lib/modules/$new_path" ]; then 
                    mkdir -vp /usr/src/initramfs/lib/modules/$new_path
                fi
            fi
            if [ ! -d "/usr/src/initramfs/lib/modules/$new_path/extra" ]; then
                echo "Creating the extra folder to copy over the modules!"
                mkdir -vp /usr/src/initramfs/lib/modules/$new_path/extra
            fi
        fi
    done
    mapfile -t usr_kernel_arr <<< "$usr_kernel_str"
    local clean_up=0
    for usr_kernels in "${usr_kernel_arr[@]}"; do
        if [ "$clean_up" -ne 0 ]; then
            echo "==================================="
            echo "Cleaning up old directories in /usr/src/initramfs/lib/modules!"
            echo "==================================="
            clean_up=1
        fi
        # Strip off the package name and colon to extract just the version
        usr_version=$(echo "$usr_kernels" | sed 's/^[^:]*://')
        if [ -d "/usr/src/initramfs/$usr_version-gentoo-$TYPE" ]; then
            if [ -d "/usr/src/initramfs/lib/modules/$usr_version-gentoo-$TYPE" ]; then 
                echo "==================================="
                echo "Removing old folders from /usr/src/initramfs/modules/$usr_version-gentoo-$TYPE"
                rm -r /usr/src/initramfs/lib/modules/"$usr_version-gentoo-$TYPE" || error "install_kernel" "Failed to remove $usr_version-gentoo-$TYPE from /usr/src/initramfs/lib/modules/"
            fi
            if [ -d "/lib/modules/$usr_version-gentoo-$TYPE" ]; then 
                echo "==================================="
                echo "Removing old folders from /lib/modules/$usr_version-gentoo-$TYPE"
                rm -r /lib/modules/"$usr_version-gentoo-$TYPE" || error "install_kernel" "Failed to remove $usr_version-gentoo-$TYPE from /lib/modules/"
            fi 
            if [ -d "/boot/vmlinuz-$usr_version-gentoo-$TYPE" ]; then 
                echo "==================================="
                echo "Removing the old vmlinuz from /boot/vmlinuz-$usr_version-gentoo-$TYPE"
                rm  /boot/"vmlinuz-$usr_version-gentoo-$TYPE" || error "install_kernel" "Failed to remove vmlinuz-$usr_version-$TYPE from /boot"
            fi 
            if [ -d "/boot/initramfs-$usr_version-$TYPE.img" ]; then 
                echo "==================================="
                echo "Removing the old initramfs from /boot/initramfs-$usr_version-$TYPE.img"
                rm /boot/"initramfs-$usr_version-$TYPE.img" || error "install_kernel" "Failed to remove initramfs-$usr_version-$TYPE.img from /boot"
            fi 
        else 
            if [ -d "/lib/modules/$usr_version-gentoo-$TYPE" ]; then 
                echo "==================================="
                echo "Removing old folders from /lib/modules/$usr_version-gentoo-$TYPE"
                rm -r /lib/modules/"$usr_version-gentoo-$TYPE" || error "install_kernel" "Failed to remove $usr_version-gentoo-$TYPE from /lib/modules/"
            fi 
            if [ -d "/boot/vmlinuz-$usr_version-gentoo-$TYPE" ]; then 
                echo "==================================="
                echo "Removing the old vmlinuz from /boot/vmlinuz-$usr_version-gentoo-$TYPE"
                rm  /boot/"vmlinuz-$usr_version-gentoo-$TYPE" || error "install_kernel" "Failed to remove vmlinuz-$usr_version-$TYPE from /boot"
            fi 
            if [ -d "/boot/initramfs-$usr_version-$TYPE.img" ]; then 
                echo "==================================="
                echo "Removing the old initramfs from /boot/initramfs-$usr_version-$TYPE.img"
                rm /boot/"initramfs-$usr_version-$TYPE.img" || error "install_kernel" "Failed to remove initramfs-$usr_version-$TYPE.img from /boot"
            fi 
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
            AVAILABLE_KERNELS["$status_val"]+="sys-kernel/$KEY:$version_val "
        fi
    done
    mapfile -t usr_kernel_arr <<< "$usr_kernel_str"
    IFS=' ' read -r -a kernel_arr <<< "${AVAILABLE_KERNELS["$STATUS"]}"
    local copy_config=0
    local kernel_update=0
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
                if [ "$copy_config" -ne 1 ]; then
                    copy_config=1
                    kernel_update=1
                    cp -Prv /usr/src/"linux-$usr_version-gentoo"/.config /home/masterkuckles/"$usr_version-gentoo-$TYPE-config"
                fi
                if ! equery list =sys-kernel/"$KEY-$available_version" > /dev/null; then 
                    emerge -v =sys-kernel/"$KEY-$available_version" || error "install_kernel_resources" "Failed to install the new kernel!"
                    emerge --deselect =sys-kernel/"$KEY-$available_version" || error "install_kernel_resources" "Failed to deselect the old kernels"
                    if [ -d "/usr/src/linux-$available_version-gentoo" ]; then 
                        rm -r  /usr/src/"linux-$available_version-gentoo"
                    fi
		        else 
			        echo "Kernel $KEY-available_version is already installed"
		        fi
            fi
        done 
    done
    if [ "$kernel_update" -ne 0 ]; then
        # Remove trailing spaces and newlines
        build_str=$(echo "$build_str" | sed 's/[[:space:]]*$//')
        mapfile -d ' ' -t BUILD_KERNELS <<< "$build_str"
        install_kernel
        emerge -a --depclean
    else 
        echo "==================================="
        echo "Already have the latest kernel version installed!"
        echo "Exiting script..."
        echo "==================================="
        exit 0
    fi
    return 0
}

# Function that will update to the newest zfs
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
            new_path="$version-$TYPE"
            zfs_version=$(echo $ZFS_KEY | sed 's/^[^-]*-//')
            echo "Kernel version $kernel is within the range ($start - $end)."
            emerge --deselect ${CURRENT_ZFS[0]} || error "install_zfs" "Failed to uninstall the old zfs"
            emerge --deselect ${CURRENT_ZFS[1]} || error "install_zfs" "Failed to uninstall the old zfs kmod"
            emerge -1 =sys-fs/$ZFS_KEY || error "install_zfs" "Failed to install the newer zfs!"
            emerge -1 =sys-fs/zfs"-"kmod"-"$zfs_version || error "install_zfs" "Failed to install the new zfs-kmod!"
            if [ -d "/usr/src/initramfs" ]; then 
                cp -Prv /lib/modules/$new_path/extra/* /usr/src/initramfs/lib/modules/$new_path/extra/ || error "install_zfs" "Failed to copy over modules!"
                cp -Prv /lib/modules/$new_path/modules.* /usr/src/initramfs/lib/modules/$new_path/
            fi 
        else
            echo "======================================"
            echo "Kernel version $kernel is outside the range ($start - $end)."
        fi
    done 
    return 0
}
update_init() {
    local usr_kernel_str=${INSTALLED_KERNELS[$KEY]}
    mapfile -t usr_kernel_arr <<< "$usr_kernel_str"
    if [ -d "/usr/src/initramfs" ]; then 
        cd /usr/src/initramfs
    fi 
    for usr_kernels in "${usr_kernel_arr[@]}"; do
        usr_version=$(echo "$usr_kernels" | sed 's/^[^:]*://')
        if [ -d "/usr/src/initramfs/lib/modules/$usr_version-gentoo-$TYPE" ]; then
            lddtree --copy-to-tree /usr/src/initramfs /sbin/zfs 
            lddtree --copy-to-tree /usr/src/initramfs /sbin/zpool 
            lddtree --copy-to-tree /usr/src/initramfs /sbin/zed 
            lddtree --copy-to-tree /usr/src/initramfs /sbin/zgenhostid
            lddtree --copy-to-tree /usr/src/initramfs /sbin/zvol_wait 
            find . -not -path "/lib/modules/*" -o -path "./lib/modules/$usr_version-gentoo-$TYPE/*" -print0 | cpio --null --create --verbose --format=newc | gzip -9 > boot/initramfs-"$usr_version-gentoo-$TYPE".img
            echo "======================================"
        else 
            Dracut=$(cat /var/lib/portage/world | grep -E '^sys-kernel\/dracut-+:[0-9]+\.[0-9]+\.[0-9]+$')
            # Need to check to see if the string is empty
            if [[ -n "$Dracut" ]]; then
                # If it is not empty then generate initramfs using dracut
                dracut --force --kver="$usr_version" /boot/initramfs-"$usr_version-gentoo-$TYPE".img || error "update_init" "Failed to create initramfs using dracut!"
            fi
            GenKernel=$(cat /var/lib/portage/world | grep -E '^sys-kernel\/genkernel-+:[0-9]+\.[0-9]+\.[0-9]+$')
            # Need to check to see if the string is empty
            if [[ -n "$GenKernel" ]]; then
                # If it is not empty then generate initramfs using genkernel
                genkernel --kernel-config=/usr/src/linux-$usr_version-gentoo/.config initramfs --kerneldir=/usr/src/linux-$usr_version-gentoo || error "update_init" "Failed to create initramfs using genkernel!"
            else 
                error "update_init" "Error: The 'Dracut' and 'GenKernel' variables are empty.\nThis indicates a bug in the script. Please file a bug report or submit a pull request to resolve the issue at: https://github.com/alphastigma101/BashScripts\n\nSteps to follow:\n1. Provide details of your environment (e.g., OS, Bash version).\n2. Describe how to reproduce the issue.\n3. Submit a pull request with a fix if possible.\n\nIf you are unable to submit a fix, please report the issue with as much detail as you can."
            fi  
        fi 
    done 
    return 0
}

update_bootloader() {
    Grub=$(cat /var/lib/portage/world | grep -E '^sys-boot\/grub-+:[0-9]+\.[0-9]+\.[0-9]+$')
    # Need to check to see if the string is empty
    if [[ -n "$Grub" ]]; then
        # If it is not empty then generate initramfs using dracut
        grub-mkconfig -o /boot/grub/grub.cfg || error "update_bootloader" "Failed to update the bootloader!"
    fi 
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
    remove_html 
    return 0
}

main() {
    populate_zfs_releases
    check_kernel
    populate_data_structures
    install_kernel_resources "$STATUS"
    check_zfs
    install_zfs
    update_init
    update_bootloader
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