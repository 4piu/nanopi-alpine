#!/bin/bash
cdir=$(pwd)
find_apk_tools () {
    local burl pkg tmpdir
    apk=$(which apk)
    if [ -z "$apk" ]; then # get apk-tools-static
        echo "##############################"
        echo "# You do not have apk, so we #"
        echo "# will get a static copy and #"
        echo "# and use it                 #"
        echo "##############################"
        arch=$(uname -m) # armv6l> armhf aarch64 armv7
        case $arch in
            armv6*|armhf) arch="armhf";;
            x86_64|x86|aarch64) arch="$arch";;
            armv7*) arch="armv7";;
            *) echo "unknown native arch '$arch'"
            exit 1
        esac
        burl="$ROOTFS_URL/main/$arch"
        tmpdir="build-tmp"
        mkdir -p "$tmpdir/apk"
        wget -O "$tmpdir/index.html" "$burl"
        pkg=$(grep apk-tools-static "$tmpdir/index.html" |sed 's!.*apk-!apk-!;s!<.*!!')
        wget -O "$tmpdir/apk-tools-static.apk" "$burl/$pkg"
        cd "$tmpdir/apk"
        tar -xf "../apk-tools-static.apk"
        pkg=$(find . -name 'apk.static' | head -n1)
        if [ -n "$pkg" ] && [ -f "$pkg" ]; then
            mv "$pkg" .
        else
            echo "Error: apk.static not found after extraction"
            exit 1
        fi
        apk="$(pwd)/apk.static"
        cd "$cdir"
    fi
}

create_chroot () {
    local chroot_dir tarball_file
    chroot_dir="$1"
    tarball_file="$2"

    binlinks="ln mount less grep md5sum sh getty login sed ash ls vi"
    mkdir -p "$chroot_dir/etc/apk"
    # Add repositories
    for r in main community; do
        echo "$ROOTFS_URL/$r" >> "$chroot_dir/etc/apk/repositories"
    done
    # Create the chroot base
    sudo "$apk" add -p "$chroot_dir" --initdb -U --arch armhf --allow-untrusted alpine-base
    if [ $? -ne 0 ]; then
        echo "Error: apk add failed"
        exit 1
    fi
    # Enable ttyS0 console
    sudo sed -i 's!^#ttyS0!ttyS0!' "$chroot_dir/etc/inittab"

    # Create some links to busybox
    cd "$chroot_dir/bin"
    for b in $binlinks; do
        if [ ! -e "$b" ]; then
            sudo ln -s busybox $b
	fi
    done
    # Create symlinks for init and getty
    cd ../sbin
    if [ ! -e init ]; then sudo ln -s /bin/sh init; fi
    if [ ! -e getty ]; then sudo ln -s /bin/getty getty; fi
    # Ensure root owns everything
    cd ..
    sudo chown -R root:root *
    # Create the tarball
    sudo tar -cf "$cdir/$tarball_file" *
    cd "$cdir"
}

check_tools () {
    local list missing l w
    missing=""
    list="gcc tar sed grep wget sfdisk mkfs.f2fs mkfs.ext2 losetup"
    l=$(which kpartx)
    if [ -z "$l" ]; then
        l=$(which partx)
	if [ -z "$1" ]; then missing="partx or kpartx,"; fi
    fi
    for l in $list; do
        w=$(which "$l")
	if [ -z "$w" ]; then missing="$missing $l,"; fi
    done
    l=$(which "$1") #try the cross-compiler in the path
    if [ -z "$l" ]; then # try harder. :)
        # check for cross-compiler...
        l=$(dirname $(which gcc))
        w=$(ls $l/arm-*-gcc)
        if [ -z "$w" ]; then missing="$missing arm-xxx-gcc"; fi
    fi
    if [ -n "$missing" ]; then
        echo "These tools are missing in your system. Please install them first"
	echo "$missing"
	exit 1
    fi

}
check_tools "${CROSS_COMPILE}gcc"
find_apk_tools
create_chroot "$1" "$2"
