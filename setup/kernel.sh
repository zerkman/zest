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
if [ ! -d output/src/linux-xlnx ] ; then
    cd output/src
    git clone https://github.com/Xilinx/linux-xlnx.git || exit $?
    cd linux-xlnx
    git checkout xilinx-v$XILINX_VERSION || exit $?
fi
