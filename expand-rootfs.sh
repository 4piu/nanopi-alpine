#!/bin/sh
# Auto-expand rootfs script
# This script expands the root partition and filesystem to fill the entire SD card

ROOTDEV=$(findmnt -n -o SOURCE /)
ROOTPART=$(echo "$ROOTDEV" | grep -o '[0-9]*$')
ROOTDISK=$(echo "$ROOTDEV" | sed 's/[0-9]*$//')

# Check if we're on an SD card
case "$ROOTDISK" in
    *mmcblk*) ;;
    *) echo "Root filesystem is not on an SD card. Expansion not supported."; exit 0 ;;
esac

# Get the current size of the root partition
CURRENT_SIZE=$(blockdev --getsz "$ROOTDEV" 2>/dev/null || echo "0")
DISK_SIZE=$(blockdev --getsz "$ROOTDISK" 2>/dev/null || echo "0")

# Calculate available space (leaving some buffer)
AVAILABLE_SIZE=$((DISK_SIZE - 2048))  # Leave 1MB at end

# Check if expansion is needed
if [ "$CURRENT_SIZE" -ge "$AVAILABLE_SIZE" ] || [ "$AVAILABLE_SIZE" -le "$CURRENT_SIZE" ]; then
    echo "Root partition is already expanded or expansion not needed."
    rm -f /etc/local.d/expand-rootfs.start
    exit 0
fi

echo "Expanding root partition from $CURRENT_SIZE to $AVAILABLE_SIZE sectors..."

# Use fdisk to expand the partition
fdisk "$ROOTDISK" <<FDISK_EOF >/dev/null 2>&1
p
d
$ROOTPART
n
p
$ROOTPART


w
FDISK_EOF

# Force kernel to reread partition table
partprobe "$ROOTDISK" 2>/dev/null || echo 1 > /sys/class/block/$(basename "$ROOTDISK")/$(basename "$ROOTDEV")/uevent

# Resize the filesystem
echo "Expanding ext4 filesystem..."
resize2fs "$ROOTDEV" 2>/dev/null

echo "Root filesystem expansion completed successfully!"

# Remove this script after successful expansion
rm -f /etc/local.d/expand-rootfs.start

echo "Auto-expansion script removed. System will continue normal boot."
