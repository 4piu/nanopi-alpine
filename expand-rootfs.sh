#!/bin/sh
# Auto-expand rootfs script
# This script expands the root partition and filesystem to fill the entire SD card

ROOTDEV="/dev/mmcblk0"
FIRST_SECTOR=2048

# Check if root device exists
if [ ! -b "$ROOTDEV" ]; then
    echo "Root device $ROOTDEV not found. Exiting."
    exit 1
fi

echo "Expanding root partition"

# Use fdisk to expand the partition
fdisk "$ROOTDEV" <<FDISK_EOF > /dev/null 2>&1
d
n
p
1
$FIRST_SECTOR

w
FDISK_EOF

# Resize the filesystem
echo "Expanding ext4 filesystem..."
resize2fs -f "${ROOTDEV}p1"

if [ $? -ne 0 ]; then
    echo "Error: resize2fs command failed with return code $?. Exiting."
    exit 1
else 
    echo "Root filesystem expansion completed successfully!"
fi

# Remove this script after successful expansion
rm -f /etc/local.d/expand-rootfs.start && reboot
