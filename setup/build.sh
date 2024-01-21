#!/bin/sh

TARGETS="z7lite_7010 z7lite_7020"

export XILINX_PATH=/opt/Xilinx
export XILINX_VERSION=2023.2
export BUILDROOT_VERSION=2023.11.1
export EMUTOS_VERSION=1.2.1

# Root filesystem
if [ ! -f output/rootfs.ub ] ; then
    recipes/rootfs.sh
fi

# Linux kernel
if [ ! -f output/uImage ] ; then
    recipes/kernel.sh
fi

# boot.scr
if [ ! -f output/$target/boot.scr ] ; then
    recipes/boot_scr.sh $target
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

    # BOOT.bin
    if [ ! -f output/$target/BOOT.bin ] ; then
        recipes/boot_bin.sh $target
    fi

    rm -f output/$target/ps7_init*
done

# Drivers
recipes/drivers.sh

# Release files
recipes/release.sh "$TARGETS"
