#!/bin/sh

ZEST_PATH=${PWD%/*}
ZEST_SETUP=${PWD}
VITIS=$XILINX_PATH/Vitis/$XILINX_VERSION

if [ $# -ne 1 ] ; then
    echo "usage: $0 target"
    exit 1
fi

target=$1

cd output/$target

# Create the fsbl app
cat <<EOF > fsbl.tcl
set hwdsgn [hsi open_hw_design zest_top.xsa]
hsi generate_app -hw \$hwdsgn -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -sw fsbl -dir fsbl
EOF
$VITIS/bin/xsct fsbl.tcl || exit $?

if [ "$target" = zynqberry ] ; then
    # Force booting from SD card - necessary on clg225 FPGAs
    # also enable booting from SD1
    patch -p0 <<EOF
--- fsbl/main.c.orig	2024-11-03 00:34:28.898010650 +0100
+++ fsbl/main.c	2024-11-03 00:26:37.276663226 +0100
@@ -374,8 +374,10 @@
 	/*
 	 * Read bootmode register
 	 */
-	BootModeRegister = Xil_In32(BOOT_MODE_REG);
-	BootModeRegister &= BOOT_MODES_MASK;
+	//BootModeRegister = Xil_In32(BOOT_MODE_REG);
+	//BootModeRegister &= BOOT_MODES_MASK;
+	// Force reading boot info from SD card even when booting from QSPI
+	BootModeRegister = SD_MODE;

 	/*
 	 * QSPI BOOT MODE
@@ -532,7 +534,8 @@
 	if ((FlashReadBaseAddress != XPS_QSPI_LINEAR_BASEADDR) &&
 			(FlashReadBaseAddress != XPS_NAND_BASEADDR) &&
 			(FlashReadBaseAddress != XPS_NOR_BASEADDR) &&
-			(FlashReadBaseAddress != XPS_SDIO0_BASEADDR)) {
+			(FlashReadBaseAddress != XPS_SDIO0_BASEADDR) &&
+			(FlashReadBaseAddress != XPS_SDIO1_BASEADDR)) {
 		fsbl_printf(DEBUG_GENERAL,"INVALID_FLASH_ADDRESS \r\n");
 		OutputStatus(INVALID_FLASH_ADDRESS);
 		FsblFallback();
EOF
fi

# Build/install/clean
(cd fsbl; PATH=$VITIS/gnu/aarch32/lin/gcc-arm-none-eabi/bin:$PATH make)
mv fsbl/executable.elf fsbl.elf
rm -rf fsbl fsbl.tcl
