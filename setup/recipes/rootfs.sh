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
    if [ ! -f ${buildroot}.tar.xz ] ; then
        wget https://buildroot.org/downloads/${buildroot}.tar.xz || exit $?
    fi
    tar xf ${buildroot}.tar.xz
fi

cd ${buildroot}
sed -e "s@\(BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE\).*@\1=\"$ZEST_SETUP/defconfig/linux\"@" $ZEST_SETUP/defconfig/buildroot > configs/zest_defconfig
make zest_defconfig || exit $1
make || exit $1

cd $ZEST_PATH/linux
PATH=$ZEST_SETUP/output/src/${buildroot}/output/host/bin:$PATH make || exit $?

if [ ! -f $ZEST_SETUP/output/src/rom.img ] ; then
    if [ ! -f $ZEST_SETUP/output/src/emutos-256k-$EMUTOS_VERSION.zip ] ; then
        wget -P $ZEST_SETUP/output/src https://sourceforge.net/projects/emutos/files/emutos/$EMUTOS_VERSION/emutos-256k-$EMUTOS_VERSION.zip
    fi
    unzip -p $ZEST_SETUP/output/src/emutos-256k-$EMUTOS_VERSION.zip emutos-256k-$EMUTOS_VERSION/etos256uk.img > $ZEST_SETUP/output/src/rom.img || exit $?
fi

cd $ZEST_SETUP/output/src/${buildroot}
sh $ZEST_SETUP/buildroot_post_build.sh || exit $1

make || exit $1
cp output/images/rootfs.cpio.uboot $ZEST_SETUP/output/rootfs.ub
cp output/images/uImage $ZEST_SETUP/output/uImage
