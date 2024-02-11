#!/bin/sh
#

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

VIVADO=${XILINX_PATH}/Vivado/${XILINX_VERSION}/bin/vivado

if [ $# -ne 1 ] ; then
    echo "usage: $0 target"
fi

target=$1

if [ ! -f $ZEST_PATH/vivado/zest_${target}.tcl ] ; then
    echo "target '$target' undefined"
    exit 1
fi

proj=zest_${target}
mkdir -p output/$target/vivado
cd output/$target/vivado

$VIVADO -mode batch -source "$ZEST_PATH/vivado/zest_${target}.tcl" -tclargs --origin_dir "$ZEST_PATH" --project_name $proj
cat<<EOF >build.tcl
open_project "$proj/$proj.xpr"
generate_target all [get_files "${proj}/${proj}.srcs/sources_1/bd/ps_domain/ps_domain.bd"]
export_ip_user_files -of_objects [get_files "${proj}/${proj}.srcs/sources_1/bd/ps_domain/ps_domain.bd"] -no_script -sync -force -quiet
set runs [create_ip_run [get_files -of_objects [get_fileset sources_1] "${proj}/${proj}.srcs/sources_1/bd/ps_domain/ps_domain.bd"]]
launch_runs -jobs 16 \$runs
wait_on_runs \$runs
synth_design -flatten_hierarchy none
opt_design
place_design
route_design
write_bitstream -force "../zest_top.bit"
write_hw_platform -fixed -force -file "../zest_top.xsa"
EOF
$VIVADO -mode batch -source build.tcl

cd $ZEST_SETUP
rm -r output/$target/vivado
