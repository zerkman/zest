#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

if [ $# -ne 1 ] ; then
    echo "usage: $0 target"
    exit 1
fi

target=$1

cd output/$target

rm -f BOOT.bin*
cat<<EOF > boot.bif
//arch = zynq; split = false; format = BIN
the_ROM_image:
{
    [bootloader]fsbl.elf
    zest_top.bit
    u-boot.elf
    devicetree.dtb
}
EOF
$XILINX_PATH/Vitis/$XILINX_VERSION/bin/bootgen -arch zynq -image boot.bif -o BOOT.bin || exit $?
rm boot.bif
