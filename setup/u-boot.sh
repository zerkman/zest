#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

export ARCH=arm
export CROSS_COMPILE=$ZEST_SETUP/output/src/buildroot-${BUILDROOT_VERSION}/output/host/bin/arm-linux-

if [ $# -ne 1 ] ; then
    echo "usage: $0 target"
    exit 1
fi

target=$1

mkdir -p output/src
if [ ! -d output/src/u-boot-xlnx ] ; then
    cd output/src
    git clone https://github.com/Xilinx/u-boot-xlnx.git || exit $?
    cd u-boot-xlnx
    git checkout xilinx-v$XILINX_VERSION || exit $?
fi

cd $ZEST_SETUP/output/src/u-boot-xlnx
make clean
cp $ZEST_SETUP/u-boot_defconfig configs/zest_defconfig || exit $?
make zest_defconfig || exit $?
cp $ZEST_SETUP/output/$target/devicetree.dtb arch/arm/dts/unset.dtb
mkdir -p board/xilinx/zynq/custom_hw_platform
cp $ZEST_SETUP/output/$target/ps7_init_gpl.[ch] board/xilinx/zynq/custom_hw_platform || exit $?

make -j`nproc` || exit $?
cp u-boot.elf $ZEST_SETUP/output/$target
