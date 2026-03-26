#!/bin/bash

# Define a function for retries with exponential backoff
retry_with_backoff() {
    local n=1
    local max_attempts=5
    local delay=1
    local command=""

    command="$1"

    while [[ $n -le $max_attempts ]]; do
        eval $command && return 0
        echo "Attempt $n failed!"
        sleep $delay
        delay=$(( delay * 2 ))
        n=$(( n + 1 ))
    done
    echo "All attempts failed! Exiting..."
    exit 1
}

# Function to check if script is running as root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Not running as root. Admin privileges might be required for some operations."
        echo "Use sudo if necessary."
    else
        echo "Running as root."
    fi
}

# Parse command line arguments for offline mode
offline_mode=false
while getopts "o" option; do
    case $option in
        o)
            offline_mode=true
            echo "Running in offline mode."
            ;;    
    esac
done

check_root

# Skip web build if not in the right directory
if [ ! -d "web" ]; then
    echo "Not in the correct directory for web build. Skipping..."
    exit 0
fi

# Use curl or wget for downloads with retries and timeouts
download_file() {
    local url="$1"
    local output="$2"

    if $offline_mode; then
        echo "Offline mode: Skipping download of $url"
        return
    fi

    if command -v curl &> /dev/null; then
        retry_with_backoff "curl -L --retry 3 --retry-delay 1 --connect-timeout 10 -o $output $url"
    elif command -v wget &> /dev/null; then
        retry_with_backoff "wget --timeout=10 --tries=3 -O $output $url"
    else
        echo "Neither curl nor wget is available. Exiting..."
        exit 1
    fi
}

# Example download
download_file "https://example.com/file.tar.gz" "file.tar.gz"

# Parallel operations (implementation depends on actual commands used in setup)
# For instance: 
# command1 &
# command2 &
# wait
