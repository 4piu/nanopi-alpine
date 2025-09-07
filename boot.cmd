setenv machid 1029
setenv bootargs earlyprintk console=ttyS0,115200 root=/dev/mmcblk0p1 rw noinitrd rootwait
load mmc 0:1 0x43000000 boot/sun8i-h3-nanopi-neo.dtb
load mmc 0:1 0x41000000 boot/zImage
bootz 0x41000000 - 0x43000000
