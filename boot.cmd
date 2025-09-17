setenv machid 1029
setenv bootargs earlyprintk console=ttyS0,115200 root=/dev/mmcblk0p1 rw noinitrd rootwait

# Load main device tree
load mmc 0:1 0x43000000 boot/sun8i-h3-nanopi-neo.dtb
fdt addr 0x43000000
fdt resize 8192

# Dynamic overlay loading (auto-generated)
setenv overlay_files ""

# Load each overlay in the list
for overlay_file in ${overlay_files}; do
    if load mmc 0:1 0x44000000 boot/overlay/${overlay_file}; then
        echo "Loading overlay: ${overlay_file}"
        fdt apply 0x44000000
    else
        echo "Overlay not found: ${overlay_file}"
    fi
done

# Load kernel and boot
load mmc 0:1 0x41000000 boot/zImage
bootz 0x41000000 - 0x43000000

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr