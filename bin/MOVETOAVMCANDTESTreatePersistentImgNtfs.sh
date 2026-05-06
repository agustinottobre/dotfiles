#!/bin/bash

size=1024
fstype=ntfs
label=Windows_Persistence
outputfile=persistence.img

print_usage() {
    echo 'Usage:  sudo ./CreatePersistentImg.sh [ -s size ] [ -l LABEL ] [ -o outputfile name ]'
    echo '  OPTION: (optional)'
    echo '   -s size in MB, default is 1024'
    echo '   -l label, default is Windows_Persistence'
    echo '   -o outputfile name, default is persistence.img'
    echo '   -h, --help show this help message'
    echo ''
}

print_err() {
    echo ""
    echo "$*"
    echo ""
}

uid=$(id -u)
if [ $uid -ne 0 ]; then
    print_err "Please use sudo or run the script as root."
    exit 1
fi

while [ -n "$1" ]; do
    if [ "$1" = "-s" ]; then
        shift
        size=$1
    elif [ "$1" = "-l" ]; then
        shift
        label=$1
    elif [ "$1" = "-o" ]; then
        shift
        outputfile=$1
    elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        print_usage
        exit 0
    else
        print_usage
        exit 1
    fi
    shift
done

# Check label
if [ -z "$label" ]; then
    echo "The label can NOT be empty."
    exit 1
fi

# Check size
if ! [[ "$size" =~ ^[0-9]+$ ]]; then
    echo "Invalid size $size"
    exit 1
fi

# Create the image file
dd if=/dev/zero of="$outputfile" bs=1M count=$size
sync

# Setup loop device
freeloop=$(losetup -f)

losetup $freeloop "$outputfile"

# Create NTFS filesystem
mkfs.ntfs -Q -L "$label" "$freeloop"

sync

# Clean up
losetup -d $freeloop

echo "Persistence disk created successfully: $outputfile"

