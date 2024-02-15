#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

if [ $# -ne 1 ] ; then
    echo "usage: $0 target"
    exit 1
fi

target=$1
board=${target%_*}
chip=${target#*_}

mkdir -p output/src
if [ ! -d output/src/device-tree-xlnx ] ; then
    cd output/src
    git clone https://github.com/Xilinx/device-tree-xlnx.git || exit $?
    cd device-tree-xlnx
    git checkout xilinx_v$XILINX_VERSION || exit $?
fi

cd $ZEST_SETUP/output

if [ ! -d $target/dt ] ; then
    cat <<EOF > $target/devicetree.tcl
hsi open_hw_design $target/zest_top.xsa
hsi set_repo_path src/device-tree-xlnx
hsi create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0
hsi generate_target -dir $target/dt
EOF
    $XILINX_PATH/Vitis/$XILINX_VERSION/bin/xsct $target/devicetree.tcl || exit $?
    rm $target/devicetree.tcl
fi

cp $ZEST_SETUP/$board/zest.dts $target/dt || exit $?
cd $target/dt
cpp -nostdinc -I include -I arch -undef -x assembler-with-cpp zest.dts > devicetree.dts || exit $?
dtc -I dts -O dtb -i . -o $ZEST_SETUP/output/$target/devicetree.dtb devicetree.dts || exit $?
rm -f zest.dts devicetree.dts
