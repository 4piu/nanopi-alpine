#!/bin/sh
# Auto-expand rootfs script
# This script expands the root partition and filesystem to fill the entire SD card

ROOT_DEV="/dev/mmcblk0"
ROOT_PART="/dev/mmcblk0p1"
FIRST_SECTOR=2048

LOG_PREFIX="expand-rootfs:"
LOG_OUT="/dev/kmsg"

# Check if root device exists
if [ ! -b "$ROOT_DEV" ]; then
    echo "$LOG_PREFIX Root device $ROOT_DEV not found. Exiting." | tee $LOG_OUT
    exit 1
fi

# Get partition size difference
size_diff=$(( $(blockdev --getsize64 "$ROOT_DEV") - $(blockdev --getsize64 "$ROOT_PART") ))
echo "$LOG_PREFIX Size difference: $size_diff bytes" | tee $LOG_OUT

# If size difference is less than 10MB, assume no need to expand
if [ $size_diff -gt $((10 * 1024 * 1024)) ]; then
    echo "$LOG_PREFIX Expanding root partition" | tee $LOG_OUT

# Use fdisk to expand the partition
fdisk "$ROOT_DEV" <<FDISK_EOF > /dev/null 2>&1
d
n
p
1
$FIRST_SECTOR

w
FDISK_EOF
echo "$LOG_PREFIX Partition table updated. Rebooting to apply changes..." | tee $LOG_OUT
reboot && exit 0
fi

# Resize the filesystem (after reboot)
set -e
echo "$LOG_PREFIX Expanding ext4 filesystem..." | tee $LOG_OUT
resize2fs -f "$ROOT_PART" && rm -f /etc/local.d/expand-rootfs.start && reboot
