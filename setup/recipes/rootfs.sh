#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

if [ $# -ne 0 ] ; then
    echo "usage: $0"
    exit 1
fi

buildroot=buildroot-${BUILDROOT_VERSION}

unset echo

mkdir -p output/src
cd output/src

if [ ! -d $buildroot ] ; then
    wget https://buildroot.org/downloads/${buildroot}.tar.xz || exit $?
    tar xf ${buildroot}.tar.xz
    rm -f ${buildroot}
fi

cd ${buildroot}
cp $ZEST_SETUP/buildroot_defconfig configs/zest_defconfig
make zest_defconfig
make

cd $ZEST_PATH/linux
PATH=$ZEST_SETUP/output/src/${buildroot}/output/host/bin:$PATH make || exit $?

cd $ZEST_SETUP/output/src/${buildroot}
sh $ZEST_SETUP/buildroot_post_build.sh || exit $1
make || exit $1
cp output/images/rootfs.cpio.uboot $ZEST_SETUP/output/rootfs.ub
