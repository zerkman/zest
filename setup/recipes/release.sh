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
done
cp ../zest.cfg release

mkdir -p release/drivers
cp drivers/*.prg release/drivers
mkdir -p release/drivers/zkbd
cp drivers/zkbd/*.prg release/drivers/zkbd

name="zeST-`date +%Y%m%d`"
tar cf $name.tar release --transform s/release/$name/
xz -9f $name.tar
