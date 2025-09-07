#!/bin/bash

set -e

# Get script directory and setup variables
cdir="$(dirname "$0")"
chroot_dir="$(readlink -f "$1")"

sudo mkdir -p "$chroot_dir/etc/apk"
# Add repositories
for r in main community; do
    sudo sh -c "echo '$ROOTFS_URL/$r' >> '$chroot_dir/etc/apk/repositories'"
done
# Load custom packages if available
if [ -f "$cdir/alpine-packages.txt" ]; then
    # store list to variable
    packages=$(grep -vE '^\s*#' "$cdir/alpine-packages.txt" | xargs)
fi
# Create the chroot base
sudo "$APK" add -p "$chroot_dir" --initdb -U --arch $ALPINE_ARCH --allow-untrusted alpine-base e2fsprogs-extra $packages
if [ $? -ne 0 ]; then
    echo "Error: apk add failed"
    exit 1
fi
# Enable ttyS0 console
sudo sed -i 's!^#ttyS0!ttyS0!' "$chroot_dir/etc/inittab"

# Add auto-expand rootfs script
if [ -f "$cdir/expand-rootfs.sh" ]; then
    sudo mkdir -p "$chroot_dir/etc/local.d"
    sudo cp "$cdir/expand-rootfs.sh" "$chroot_dir/etc/local.d/expand-rootfs.start"
    sudo chmod +x "$chroot_dir/etc/local.d/expand-rootfs.start"
    # Enable the local service to run at boot
    sudo mkdir -p "$chroot_dir/etc/runlevels/default"
    sudo ln -sf "/etc/init.d/local" "$chroot_dir/etc/runlevels/default/local"
fi
