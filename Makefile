export CROSS_COMPILE=arm-none-eabi-
export ARCH=arm

################################################################################
## Config
################################################################################
KERNEL_DT_FILE           ?= allwinner/sun8i-h3-nanopi-neo.dtb
KERNEL_DEFCONFIG         ?= sunxi
KERNEL_VERSION           ?= v6.16

UBOOT_BOARD_DEFCONFIG    ?= nanopi_neo
UBOOT_FORMAT_CUSTOM_NAME ?= u-boot-sunxi-with-spl.bin
UBOOT_VERSION            ?= v2025.07

ALPINE_VERSION           ?= v3.22
ALPINE_ARCH			     ?= armhf
# Note: we build this tarball.
ROOTFS_TARBALL = alpine-chroot-armhf.tar.gz
ROOTFS_URL =http://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}
################################################################################
## Possible modifiers:
##  DO_UBOOT_DEFCONFIG
##  DO_UBOOT_MENUCONFIG
##  DO_LINUX_DEFCONFIG
##  DO_LINUX_MENUCONFIG
################################################################################

################################################################################
# TSTAMP:=$(shell date +'%Y%m%d-%H%M%S')
# SDCARD_IMAGE:=nanopi-alpine-$(TSTAMP).img

KERNEL_PRODUCTS=$(addprefix sources/linux/,arch/arm/boot/zImage arch/arm/boot/dts/$(KERNEL_DT_FILE))
KERNEL_PRODUCTS_OUTPUT=$(addprefix output/,$(notdir $(KERNEL_PRODUCTS)))
ROOTFS_DIR=output/$(shell echo $(ROOTFS_TARBALL) | sed 's!\.tar\..*!!')

.PHONY: all
all: output/nanopi-alpine.img

# U-Boot
output/boot.scr: boot.cmd
	mkimage -C none -A arm -T script -d '$^' '$@'

sources/u-boot.ready:
	git clone --depth 1 --branch $(UBOOT_VERSION) git://git.denx.de/u-boot.git 'sources/u-boot' && \
	touch 'sources/u-boot.ready'

sources/u-boot/.config: sources/u-boot.ready
	if [ ! -f u-boot.config ] || [ -n '$(DO_UBOOT_DEFCONFIG)' ]; then                 \
	    $(MAKE) -C sources/u-boot/ $(MAKEFLAGS) '$(UBOOT_BOARD_DEFCONFIG)_defconfig'; \
	else                                                                              \
	    cp u-boot.config sources/u-boot/.config;                                      \
	fi
	if [ -n '$(DO_UBOOT_MENUCONFIG)' ]; then                                          \
	    $(MAKE) -C sources/u-boot/ $(MAKEFLAGS) menuconfig;                           \
	fi

sources/u-boot/u-boot-sunxi-with-spl.bin: sources/u-boot/.config
	$(MAKE) -C sources/u-boot/ all

output/$(UBOOT_FORMAT_CUSTOM_NAME): sources/u-boot/$(UBOOT_FORMAT_CUSTOM_NAME)
	cp $^ $@

# Linux kernel
sources/linux.ready:
	git clone --depth=1 --branch $(KERNEL_VERSION) https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git 'sources/linux/' && \
	touch 'sources/linux.ready'

sources/linux/.config: sources/linux.ready
	if [ ! -f kernel.config ] || [ -n '$(DO_LINUX_DEFCONFIG)' ]; then   \
	    $(MAKE) -C sources/linux/ '$(KERNEL_DEFCONFIG)_defconfig';      \
	else                                                                \
	    cp kernel.config sources/linux/.config;                         \
	fi
	if [ -n '$(DO_LINUX_MENUCONFIG)' ]; then                            \
	    $(MAKE) -C sources/linux/ menuconfig;                           \
	fi

$(KERNEL_PRODUCTS): sources/linux/.config
	$(MAKE) -C sources/linux/ zImage dtbs

$(KERNEL_PRODUCTS_OUTPUT): $(KERNEL_PRODUCTS)
	cp $^ output/

# Alpine rootfs
sources/apk-tools/apk:
	ROOTFS_URL=$(ROOTFS_URL) ./ensure-apk.sh $@

$(ROOTFS_DIR):sources/apk-tools/apk
	ROOTFS_URL=$(ROOTFS_URL) ALPINE_ARCH=$(ALPINE_ARCH) APK="sources/apk-tools/apk" ./build-chroot.sh $@

# Build and install kernel modules to rootfs
$(ROOTFS_DIR)/lib/modules: $(ROOTFS_DIR) $(KERNEL_PRODUCTS)
	$(MAKE) -C sources/linux/ $(MAKEFLAGS) modules
	sudo $(MAKE) -C sources/linux/ $(MAKEFLAGS) INSTALL_MOD_PATH=$(abspath $(ROOTFS_DIR)) modules_install

output/$(ROOTFS_TARBALL): $(ROOTFS_DIR)/lib/modules
	sudo tar -C $(ROOTFS_DIR) -czf $@ .

# Final image
output/nanopi-alpine.img: output/$(UBOOT_FORMAT_CUSTOM_NAME) output/boot.scr $(ROOTFS_DIR)/lib/modules $(KERNEL_PRODUCTS_OUTPUT)
	sudo sh -c "                                       \
	    UBOOT='output/$(UBOOT_FORMAT_CUSTOM_NAME)'     \
	    BOOTSCR='output/boot.scr'                      \
	    KERNEL='$(word 1,$(KERNEL_PRODUCTS_OUTPUT))'   \
	    DTB='$(word 2,$(KERNEL_PRODUCTS_OUTPUT))'      \
	    ROOTFS_DIR='$(ROOTFS_DIR)'                     \
	    IMAGE='$@'                                     \
	    ./make-image.sh"

.PHONY: clean
.SILENT: clean
clean:
	if [ -d $(ROOTFS_DIR) ]; then sudo rm -rf $(ROOTFS_DIR); fi
	rm -rf output/*

.PHONY: distclean
.SILENT: distclean
distclean:
	if [ -d u-boot/ ]; then $(MAKE) -C sources/u-boot/ clean; fi
	if [ -d linux/ ]; then $(MAKE) -C sources/linux/ clean; fi
	rm -rf sources/apk-tools

.PHONY: check-tools
check-tools:
	./check-tools.sh

.PHONY: install
.SILENT: install
install: output/nanopi-alpine.img
	sudo lsblk
	read -p "Enter the SD card device (e.g., /dev/sdX): " DEV; \
	if [ -z "$$DEV" ]; then echo "No device entered. Aborting."; exit 1; fi ; \
	read -p "Are you sure you want to write to $$DEV? This will erase all data on the device. (yes/no): " CONFIRM; \
	if [ "$$CONFIRM" != "yes" ]; then echo "Aborting."; exit 1; fi; \
	echo "Writing image to $$DEV..."; \
	sudo dd if=output/nanopi-alpine.img of="$$DEV" bs=4M status=progress conv=fsync; \
	sync; \
	echo "Image written to $$DEV. You can now remove the SD card."