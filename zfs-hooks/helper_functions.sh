#!/bin/bash

# Function to compare if version is greater than or equal to the comparison version
version_greater_than_equal() {
    [[ "$(echo -e "$1\n$2" | sort -V | head -n 1)" == "$2" ]]
}

# Function to compare if version is less than or equal to the comparison version
version_less_than_equal() {
    [[ "$(echo -e "$1\n$2" | sort -V | tail -n 1)" == "$2" ]]
}
