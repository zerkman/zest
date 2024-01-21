#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

if [ $# -ne 1 ] ; then
    echo "usage: $0 target"
    exit 1
fi

target=$1

cd output/$target

cat <<EOF > fsbl.tcl
set hwdsgn [hsi open_hw_design zest_top.xsa]
hsi generate_app -hw \$hwdsgn -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -compile -sw fsbl -dir fsbl
EOF
$XILINX_PATH/Vitis/$XILINX_VERSION/bin/xsct fsbl.tcl || exit $?
mv fsbl/executable.elf fsbl.elf
rm -rf fsbl fsbl.tcl
