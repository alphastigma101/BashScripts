#!/bin/bash

# Function that will output errors
error() {
    local x="$1"
    local y="$2"
    local arr="$3"
    if [ "$x" == "install_kernel" ]; then
        echo "[ERROR:] In $x. $y! "
        echo "Cleaning up...."
        make clean || cd /usr/src/linux && make clean
        make mrproper
        exit 0
    elif  [ "$x" == "install_kernel_resources" ]; then
        echo "[ERROR:] In $x. $y! "
        exit 0
    elif [ "$x" == "install_zfs" ]; then 
        echo "[ERROR:] In $x. $y! "
        exit 0
    elif [ "$x" == "update_init" ]; then 
        echo "[ERROR:] In $x. $y! "
        exit 0
    fi
    exit 0
}