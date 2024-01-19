#!/bin/sh

TARGETS="z7lite_7010 z7lite_7020 zturn"

export XILINX_PATH=/opt/Xilinx
export XILINX_VERSION=2023.2

for target in $TARGETS ; do
    mkdir -p output/$target

    # Vivado
    if [ ! -f output/$target/zest_top.bit ] ; then
        ./vivado.sh $target
    fi

    # Device tree
    if [ ! -f output/$target/devicetree.dtb ] ; then
        ./devicetree.sh $target
    fi

    rm -f output/$target/ps7_init.*

done
