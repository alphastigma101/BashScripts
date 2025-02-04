#!/bin/bash
source ./compatiability.sh 
declare -a INSTALLED_KERNELS
check_kernel() {
    # Grab the kernel versions that are installed on the system 
    # The code in compatibility will get a range of kernel versions 
    # Which a for loop can be used to iterate the kernel versions 
    # Store them into an array of some sort 
    return 0
}

check_zfs() {
    # Grab the kernel versions that are installed on the system 
    # The code in compatibility will get a range of kernel versions 
    # Which a for loop can be used to iterate the kernel versions 
    # Store them into an array of some sort 
    return 0
}

install_kernel() {
    # Using the ranges that will be stored in array, install gentoo-sources-6.x.x.
    # Or whatever is inside the ranges, it must be higher than the ones that are already installed 
    # So making an array that holds the kernel versions that are installed is needed 
    # copy the .config from the latest one and paste it somewhere safe 
    # Install the new kernel versions and use eselect to select it  
    # Copy over the .config to /usr/src/linux/.config 
    # run make menuconfig 
    # make -j3 ; make modules && make modules_install
    # cp -Prv arch/x86/boot/bzImage /boot/vmlinuz-6.x.x whatever kernel version was installed which can be accessed from the range array
    return 0
}

install_zfs() {
    return 0
}
update_init() {
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

clean_up() {
    # Search through the /boot directory and find the file extensions that end with .img 
    # But they match with the vmlinuz-6.x.x 
    # Find the lowest kernel version and remove it
    remove_html 
    return 0
}

main() {
    populate_releases
    #check_kernel
    #check_zfs
    #install_kernel
    #install_zfs
    #update_init
    #update_bootloader
    clean_up
}
main