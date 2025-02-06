#!/bin/bash
source ./bug_report.sh
source ./debug_data_structures.sh 
DEBUG=0
# Associative array to store compatible releases
declare -A COMPATIBLE_RELEASES
declare -a RANGES
# Function to extract Linux kernel compatibility
parse_linux_compatibility() {
    local url="$1"
    local release_name="$2"
    curl -s $url > $release_name".html"
    # Use grep and sed to extract Linux kernel compatibility line
    local linux_line=$(grep -A10 "Supported Platforms:" "$release_name.html" | grep "Linux kernels" | sed -e 's/^\s*//; s/\s*$//')
    # Check if Linux compatibility line exists
    if [[ -z "$linux_line" ]]; then
        linux_line=$(grep -A10 "Supported Platforms" "$release_name.html" | grep -oP "Linux: compatible with [0-9.]+ - [0-9.]+ kernels" | sed -e 's/^\s*//; s/\s*$//')
    fi
    # Extract the smallest and largest kernel versions using a regex
    if [[ "$linux_line" =~ Linux:\ compatible\ with\ ([0-9.]+)\ -\ ([0-9.]+)\ kernels ]]; then
        min_version="${BASH_REMATCH[1]}"
        max_version="${BASH_REMATCH[2]}"
    fi
    if [[ "$linux_line" =~ Linux\ kernels\ ([0-9]+\.[0-9]+)\ -\ ([0-9]+\.[0-9]+) ]]; then
        min_version="${BASH_REMATCH[1]}"
        max_version="${BASH_REMATCH[2]}"
    fi
    # Store the result in RANGES and COMPATIBLE_RELEASES
    RANGES[0]="$min_version"
    RANGES[1]="$max_version"
    COMPATIBLE_RELEASES["$release_name"]="${RANGES[0]}-${RANGES[1]}"
    return 1
}

populate_zfs_releases() {
    # Fetch the releases page content
    curl -s https://github.com/openzfs/zfs/releases > zfs_releases.html
    mapfile -t RELEASES_PAGE < <(
        awk 'BEGIN{RS="<div"; ORS="<div"} /class="Box-body"/{flag=1} flag; /<\/div>/{flag=0}' zfs_releases.html | \
        grep -oP 'href="\/openzfs\/zfs\/releases\/tag\/[^"]+"' | cut -d '"' -f 2
    )
    for url in "${RELEASES_PAGE[@]}"; do
        release_name=$(echo $url | grep -oP 'zfs-.*$')
        # Try to extract Linux kernel compatibility
        parse_linux_compatibility "https://github.com$url" "$release_name"
    done
}
remove_html() {
    rm -f *.html
}
# Check if DEBUG is set to 1
if [[ "$DEBUG" -eq 1 ]]; then
    # Call populate_releases function if DEBUG is enabled
    populate_zfs_releases
    debug_zfs_releases
fi
