#!/bin/bash
declare -A INSTALLED_KERNELS
declare -A ARCH_DICT
declare -A ZFS_DICT
declare -A STABLE_KERNELS
declare -A TESTING_KERNELS
declare -A AVAILABLE_KERNELS
declare -A AVAILABLE_ZFS
declare -a BUILD_KERNELS
declare -a CURRENT_ZFS

debug_zfs_releases() {
    # Print out the compatible releases
    echo "Compatible ZFS Releases:"
    for release in "${!COMPATIBLE_RELEASES[@]}"; do
        echo "$release: Linux kernel ${COMPATIBLE_RELEASES[$release]}"
    done
    echo "==================================="
}

debug_arch_dict() {
    for arch in "${!ARCH_DICT[@]}"; do
        echo "Architecture: $arch"
        echo "Versions: ${ARCH_DICT[$arch]}"
        echo "-------------------"  
    done
    echo "==================================="
    return 0
}

debug_installed_kernel() {
    echo "Kernel Packages:"
    for key in "${!INSTALLED_KERNELS[@]}"; do
        echo "$key: ${INSTALLED_KERNELS[$key]}"
    done
    echo "==================================="
    return 0
}

debug_available_kernel() {
    echo "AVAILABLE_KERNELS:"
    for key in "${!AVAILABLE_KERNELS[@]}"; do
        echo "$key: ${AVAILABLE_KERNELS[$key]}"
    done
    return 0
}