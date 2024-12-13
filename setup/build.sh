#!/bin/sh

TARGETS="z7lite_7010 z7lite_7020 zynqberry"

export XILINX_PATH=/opt/Xilinx
export XILINX_VERSION=2024.1
export XILINX_KERNEL_VERSION=2023.2
export BUILDROOT_VERSION=2024.02.9
export EMUTOS_VERSION=1.3

# Check dependencies
MISSING=
command -v wget > /dev/null || MISSING="$MISSING wget"
command -v git > /dev/null || MISSING="$MISSING git"
command -v gcc > /dev/null || MISSING="$MISSING gcc"
command -v g++ > /dev/null || MISSING="$MISSING g++"
command -v make > /dev/null || MISSING="$MISSING make"
command -v dtc > /dev/null || MISSING="$MISSING device-tree-compiler"
command -v mkimage > /dev/null || MISSING="$MISSING u-boot-tools"
command -v flex > /dev/null || MISSING="$MISSING flex"
command -v bison > /dev/null || MISSING="$MISSING bison"
command -v pkg-config > /dev/null || MISSING="$MISSING pkgconf"

if [ ! -z "$MISSING" ] ; then
    echo "Missing dependencies. Please install the following packages:"
    echo $MISSING
    exit 1
fi

# Check library dependencies
pkg-config uuid || MISSING="$MISSING uuid-dev"
pkg-config gnutls || MISSING="$MISSING gnutls-dev"
pkg-config libssl || MISSING="$MISSING libssl-dev"
# TODO: libtinfo5

if [ ! -z "$MISSING" ] ; then
    echo "Missing dependencies. Please install the following packages:"
    echo $MISSING
    exit 1
fi

# Check Xilinx tools install
# TODO


# Root filesystem
if [ ! -f output/rootfs.ub ] ; then
    recipes/rootfs.sh
fi

# Linux kernel
if [ ! -f output/uImage ] ; then
    recipes/kernel.sh
fi

# boot.scr
if [ ! -f output/boot.scr ] ; then
    recipes/boot_scr.sh
fi

for target in $TARGETS ; do
    mkdir -p output/$target

    # Vivado
    if [ ! -f output/$target/zest_top.bit ] ; then
        recipes/vivado.sh $target
    fi

    # Device tree
    if [ ! -f output/$target/devicetree.dtb ] ; then
        recipes/devicetree.sh $target
    fi

    # First stage bootloader
    if [ ! -f output/$target/fsbl.elf ] ; then
        recipes/fsbl.sh $target
    fi

    # U-Boot
    if [ ! -f output/$target/u-boot.elf ] ; then
        recipes/u-boot.sh $target
    fi

    # boot.bin
    if [ ! -f output/$target/boot.bin ] ; then
        recipes/boot_bin.sh $target
    fi

    rm -f output/$target/ps7_init*
done

# Drivers
recipes/drivers.sh

# Release files
recipes/release.sh "$TARGETS"
