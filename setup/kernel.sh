#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

export ARCH=arm
export CROSS_COMPILE=$ZEST_SETUP/output/src/buildroot-${BUILDROOT_VERSION}/output/host/bin/arm-linux-

if [ $# -ne 0 ] ; then
    echo "usage: $0"
    exit 1
fi

mkdir -p output/src
cd output/src
if [ ! -d linux-xlnx ] ; then
    git clone https://github.com/Xilinx/linux-xlnx.git || exit $?
fi
cd linux-xlnx
git checkout xilinx-v$XILINX_VERSION || exit $?
cp $ZEST_SETUP/linux_defconfig arch/arm/configs/zest_defconfig
make zest_defconfig
make UIMAGE_LOADADDR=0x8000 uImage -j`nproc` || exit $?
cp arch/arm/boot/uImage $ZEST_SETUP/output
