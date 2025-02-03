#!/bin/bash

# Function to extract Linux kernel compatibility
parse_linux_compatibility() {
    local release_content="$1"
    
    # Use grep and sed to extract Linux kernel compatibility line
    local linux_line=$(echo "$release_content" | grep -A1 "\*\*Linux\*\*:" | tail -n1 | sed -e 's/^\s*//; s/\s*$//')
    
    # Check if Linux compatibility line exists
    if [[ -z "$linux_line" ]]; then
        return 1
    fi
    
    # Extract kernel version range
    if [[ $linux_line =~ compatible\ with\ ([0-9.]+)\ -\ ([0-9.]+)\ kernels ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
        return 0
    fi
    
    return 1
}

# Fetch the releases page content
RELEASES_PAGE=$(curl -s https://github.com/openzfs/zfs/releases)

# Associative array to store compatible releases
declare -A COMPATIBLE_RELEASES

# Extract each release
while read -r release_name; do
    # Fetch the specific release page content
    release_content=$(curl -s "https://github.com/openzfs/zfs/releases/tag/$release_name")
    
    # Try to extract Linux kernel compatibility
    kernel_range=$(parse_linux_compatibility "$release_content")
    
    # If kernel compatibility is found, store in the map
    if [[ $? -eq 0 ]]; then
        COMPATIBLE_RELEASES["$release_name"]="$kernel_range"
    fi
done < <(echo "$RELEASES_PAGE" | grep -oP 'zfs-\d+\.\d+\.\d+')

# Print out the compatible releases
echo "Compatible ZFS Releases:"
for release in "${!COMPATIBLE_RELEASES[@]}"; do
    echo "$release: Linux kernel ${COMPATIBLE_RELEASES[$release]}"
done