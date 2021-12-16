#!/bin/sh
#
# tcl file was created using the following vivado tcl commands:
# cd </path/to/zest>
# write_project_tcl -paths_relative_to . -force vivado/zest_xxx.tcl
#
# File was then reworked to fix some absolute and relative paths using the following command:
# sed -i "s/"`pwd | sed -e 's/\//\\\\\//g'`"/../" vivado/zest_xxx.tcl

if [ ! -x "${VIVADO}" ] ; then
  VIVADO=`which vivado`
  if [ ! -x "${VIVADO}" ] ; then
    echo "vivado command could not be found. Please set its path in the VIVADO variable."
    exit 1
  fi
fi

if [ ! $# -eq 1 ] ; then
  echo "usage: $0 proj_name"
  exit 1
fi

PROJ_NAME=${1%%.tcl}
if [ ! -f "${PROJ_NAME}.tcl" ] ; then
  echo "'${PROJ_NAME}.tcl' file not found"
  exit 1
fi

${VIVADO} -mode batch -source ${PROJ_NAME}.tcl -tclargs --origin_dir .. --project_name ${PROJ_NAME}
