#!/bin/sh

TARGETS="z7lite_7010 z7lite_7020 zturn"

export XILINX_PATH=/opt/Xilinx
export XILINX_VERSION=2023.2
export BUILDROOT_VERSION=2023.11.1

# Root filesystem
./rootfs.sh

# Linux kernel
./kernel.sh

for target in $TARGETS ; do
    mkdir -p output/$target

    # Vivado
    if [ ! -f output/$target/zest_top.bit ] ; then
        ./vivado.sh $target
    fi

    # Device tree
    if [ ! -f output/$target/devicetree.dtb ] ; then
        ./devicetree.sh $target
    fi

    # First stage bootloader
    if [ ! -f output/$target/fsbl.elf ] ; then
        ./fsbl.sh $target
    fi

    # U-Boot
    if [ ! -f output/$target/u-boot.elf ] ; then
        ./u-boot.sh $target
    fi

    rm -f output/$target/ps7_init*

done
