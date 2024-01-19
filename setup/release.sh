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
    cp $target/BOOT.bin release/boards/$target
    cp $target/devicetree.dtb release/boards/$target
done
cp ../zest.cfg release
if [ ! -f release/rom.img ] ; then
    wget https://sourceforge.net/projects/emutos/files/emutos/$EMUTOS_VERSION/emutos-192k-$EMUTOS_VERSION.zip
    unzip -p emutos-192k-$EMUTOS_VERSION.zip emutos-192k-$EMUTOS_VERSION/etos192uk.img > release/rom.img
    rm emutos-192k-$EMUTOS_VERSION.zip
fi
