#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

if [ $# -ne 1 ] ; then
    echo "usage: $0 target"
    exit 1
fi

target=$1

cd output/$target

rm -f boot.bin*
cat<<EOF > boot.bif
//arch = zynq; split = false; format = BIN
the_ROM_image:
{
    [bootloader]fsbl.elf
    zest_top.bit
    u-boot.elf
    [load=0x800000]devicetree.dtb
}
EOF
$XILINX_PATH/Vitis/$XILINX_VERSION/bin/bootgen -arch zynq -image boot.bif -o boot.bin || exit $?
rm boot.bif

# Create the boot file for setting up QSPI on zynqberry and other xc7z010-clg225 based boards
# so they can then continue the boot process from the SD card like the other boards.
# The procedure is commented out by default because it is not intended to be part of the normal release.
#if [ "$target" = zynqberry ] ; then
#    cat<<EOF > boot.bif
#//arch = zynq; split = false; format = BIN
#the_ROM_image:
#{
#    [bootloader]fsbl.elf
#}
#EOF
#    $XILINX_PATH/Vitis/$XILINX_VERSION/bin/bootgen -arch zynq -image boot.bif -o spi_boot.bin || exit $?
#    rm boot.bif
#fi
