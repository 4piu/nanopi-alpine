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
IMAGE_SIZE               ?= 50M
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

.PHONY: all
all: output/nanopi-alpine.img

CHROOT_DIR=build-tmp/$(shell echo $(ROOTFS_TARBALL) | sed 's!\.tar\..*!!')

$(CHROOT_DIR):
	ROOTFS_URL=$(ROOTFS_URL) ./build-chroot.sh $@

output/$(ROOTFS_TARBALL):$(CHROOT_DIR)
	sudo tar -C $(CHROOT_DIR) -czf $@ .
	
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

output/boot.scr: boot.cmd
	mkimage -C none -A arm -T script -d '$^' '$@'

output/nanopi-alpine.img: output/$(UBOOT_FORMAT_CUSTOM_NAME) output/boot.scr output/$(ROOTFS_TARBALL) $(KERNEL_PRODUCTS_OUTPUT)
	truncate -s '$(IMAGE_SIZE)' '$@'
	sudo sh -c "                                       \
	    UBOOT='output/$(UBOOT_FORMAT_CUSTOM_NAME)'     \
	    BOOTSCR='output/boot.scr'                      \
	    KERNEL='$(word 1,$(KERNEL_PRODUCTS_OUTPUT))'   \
	    DTB='$(word 2,$(KERNEL_PRODUCTS_OUTPUT))'      \
	    ROOTFS_TARBALL='output/$(ROOTFS_TARBALL)'      \
	    IMAGE='$@'                                     \
	    ./make-image.sh"

.PHONY: clean
clean:
#	if [ -d u-boot/ ]; then $(MAKE) -C sources/u-boot/ clean; fi
#	if [ -d linux/ ]; then $(MAKE) -C sources/linux/ clean; fi
	rm -f output/*
	rm -rf build-tmp/

.PHONY: distclean
distclean:
	rm -rf sources/*
