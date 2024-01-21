#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}

if [ $# -ne 0 ] ; then
    echo "usage: $0"
    exit 1
fi

cd output

cat<<EOF >boot.cmd
setenv bootargs console=ttyPS0,921600 rw earlyprintk uio_pdrv_genirq.of_id=generic-uio rootwait
fatload mmc 0 0x8000 uImage
fatload mmc 0 0x800000 devicetree.dtb
fatload mmc 0 0x900000 rootfs.ub
bootm 0x8000 0x900000 0x800000
EOF
mkimage -A arm -O linux -C none -T script -a 0 -e 0 -n "boot script" -d boot.cmd boot.scr
rm boot.cmd
