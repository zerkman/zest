#!/bin/sh

TARGETS=$1

# Release files
cd output
mkdir -p release
cp boot.scr release
cp uImage release
cp rootfs.ub release
for target in $TARGETS ; do
    mkdir -p release/boards/$target
    cp $target/boot.bin release/boards/$target
    cp $target/devicetree.dtb release/boards/$target
done
cp ../zest.cfg release
if [ ! -f release/rom.img ] ; then
    if [ ! -f src/emutos-256k-$EMUTOS_VERSION.zip ] ; then
        wget -P src https://sourceforge.net/projects/emutos/files/emutos/$EMUTOS_VERSION/emutos-256k-$EMUTOS_VERSION.zip
    fi
    unzip -p src/emutos-256k-$EMUTOS_VERSION.zip emutos-256k-$EMUTOS_VERSION/etos256uk.img > release/rom.img
fi

mkdir -p release/drivers
cp drivers/*.prg release/drivers
mkdir -p release/drivers/zkbd
cp drivers/zkbd/*.prg release/drivers/zkbd

name="zeST-`date +%Y%m%d`"
tar cf $name.tar release --transform s/release/$name/
xz -9f $name.tar
