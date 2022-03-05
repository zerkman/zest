
# How to generate everything from source

## Required material

You’ll need:
 - Vivado and Vitis IDE. The version I used is 2020.2.
 - Development tools:
   - git
   - make
   - device-tree-compiler
   - u-boot-tools

My build system is a Debian bullseye Linux system, but I believe any GNU/Linux system will do.

This documentation assumes the following file paths:
- The Xilinx tools (Vivado, SDK) installation directory is `/opt/Xilinx`.
- The Vitis workspace directory is `$HOME/xilinx/workspace`.
- All source files and git clones are in `$HOME/src`.
- Your Vivado project is in a subdirectory of `zest/vivado`. The project directory name depends on your FPGA board.

## Get the zeST source code

Issue those commands:

    $ cd $HOME/src
    $ git clone --depth=1 --recursive https://github.com/zerkman/zest.git

## Create the Vivado project and generate the bitstream file

### Download the board definition files

This step is necessary (?) only to people using the Z-Turn board.

To get the Z-Turn board definition files for Vivado, use the command:

    $ cd $HOME/src
    $ git clone https://github.com/q3k/zturn-stuff

The directory for the board definition files is `zturn-stuff/boards`.

### Create the Vivado project

In the `zest/vivado` directory, you will find a `create_project.sh` shell script and different TCL script files, each one corresponding to a specific FPGA board. You will need to identify the file that corresponds to your hardware.

If, for instance, you choose to create the project corresponding to the zest_z7lite.tcl file, enter the command:

    $ ./create_project.sh zest_z7lite

This will create a `zest_z7lite` directory with all the project files in it.

Now your Vivado project setup is complete.

### Generate the bitstream file

Open the project in Vivado.
From the left panel, in **Program and debug**, click **Generate Bitstream**. The process will take a few minutes to complete.

When the generation is complete, you need to copy the bitstream file to the zeST setup directory. If, depending on your FPGA board, your Vivado project name is for instance `zest_z7lite`, the command will be:

    $ cp $HOME/src/zest/vivado/zest_z7lite/zest_z7lite.runs/impl_1/zest_top.bit $HOME/src/zest/setup

### Export the hardware

Click **File -> Export -> Export Hardware**. This opens the *Export Hardware Platform* dialog.
- On the first page of the dialog, click **Next**.
- As platform properties, choose **Pre-synthesis**, then click **Next**.
- Now you can choose the export file name. The default is `$HOME/src/zest/vivado/zest_z7lite/zest_top.xsa`, assuming your Vivado project name is `zest_z7lite`. Just leave it as is and click **Next**.
- Click **Finish**.

You have now generated the platform file to generate the bootloaders, as well as the Linux device tree.

You may now exit Vivado.

## Build the device tree

Get the device tree source code, at the same version as your Vivado/Vitis setup.

    $ cd $HOME/src
    $ git clone https://github.com/Xilinx/device-tree-xlnx.git
    $ cd device-tree-xlnx
    $ git checkout xilinx-v2020.2

Now, run Vitis.

### Vitis setup

At the first run of Vitis, you will be asked to choose a workspace directory. Choose `$HOME/xilinx/workspace`.

### Set up the device tree source directory

- Click **Window -> Preferences**. This opens the *Preferences* dialog.
- On the left panel, choose **Xilinx -> Software Repositories**.
- In the Local Repositories section, add the `$HOME/src/device-tree-xlnx` directory you just created above.

### Create the device tree project

- Click **File -> New -> Platform Project...**. This opens the *New Platform Project* dialog.
- As Platform project name, enter the name `zest_devicetree`. Then, click **Next**.
- In the *Create a new platform from hardware (XSA)* tab, choose the XSA file you exported from Vivado. If you kept the default file name, it should be `$HOME/src/zest/vivado/project_name/zest_top.xsa`.
- In *Software Specification*, as *Operating system*, choose **device_tree**. Leave the default setting for the processor. Leave the *Generate boot components* checkbox unchecked. Then, click **Finish**.
- Click **Project -> Build All**. After a few seconds, the device tree source files will be generated.

### Create the device tree blob

The generated device tree files should be in the `$HOME/xilinx/workspace/zest_devicetree/ps7_cortexa9_0/device_tree_domain/bsp` directory. So issue the commands:

    $ cd $HOME/src/zest
    $ mkdir setup/dt
    $ cp $HOME/xilinx/workspace/zest_devicetree/ps7_cortexa9_0/device_tree_domain/bsp/*.dts* setup/dt

You also need the specific `zest.dts` device tree source file for your board.
All zeST's board-specific device tree source files are in a dedicated subdirectory in `$HOME/src/zest/setup`.
For instance, for the Z7-Lite board, issue the command:

    $ cp setup/z7lite/zest.dts setup/dt

Now, you can build the device tree blob:

    $ cd setup/dt
    $ cpp -nostdinc -I include -I arch -undef -x assembler-with-cpp zest.dts > devicetree.dts
    $ dtc -I dts -O dtb -i . -o ../devicetree.dtb devicetree.dts

This generates the `$HOME/src/zest/setup/devicetree.dtb` device tree blob file.


## Build the first stage bootloader

The generation of the board support package (BSP) and first stage bootloader (FSBL), is done in Vitis.

- Click **File -> New -> Platform Project...**. This opens the *New Platform Project* dialog.
- As Platform project name, enter the name `zest_bsp`. Then, click **Next**.
- In the *Create a new platform from hardware (XSA)* tab, choose the XSA file you exported from Vivado. If you kept the default file name, it should be `$HOME/xilinx/zest/zest_top.xsa`.
- In *Software Specification*, as *Operating system*, choose **standalone**. Leave the default setting for the processor. Check the *Generate boot components* checkbox. Then, click **Finish**.
- Click **Project -> Build All**. After a few seconds, the BSP and FSBL files will be generated.
- Copy the FSBL binary file to the zeST `setup` directory:

      $ cp $HOME/xilinx/workspace/zest_bsp/zynq_fsbl/fsbl.elf $HOME/src/zest/setup

<!-- For early information when booting, you may add `FSBL_DEBUG_INFO` in the C preprocessor defines in the fsbl project properties. -->


## Build the buildroot filesystem

This process will create the whole Linux filesystem for your Zynq board, as well as the build toolchain that can be used for builing the Linux kernel, u-boot and the userland applications.

TODO

From now on, you can set up the environement for the specific toolchain:

    $ export ARCH=arm
    $ export CROSS_COMPILE=$HOME/src/buildroot/output/host/bin/arm-linux-

## Build the u-boot bootloader

Get the source code and issue the following configurations:

    $ cd $HOME/src
    $ git clone https://github.com/Xilinx/u-boot-xlnx.git
    $ cd u-boot-xlnx
    $ git checkout xilinx-v2020.2
    $ make xilinx_zynq_virt_defconfig
    $ sed -i 's/^\(CONFIG_DEFAULT_DEVICE_TREE\)=.*/\1=""/g' .config
    $ sed -i 's/^\(CONFIG_BAUDRATE\)=.*/\1=921600/g' .config

Copy the required files:

    $ cp $HOME/src/zest/setup/devicetree.dtb arch/arm/dts/unset.dtb
    $ mkdir -p board/xilinx/zynq/custom_hw_platform
    $ cp $HOME/xilinx/workspace/zest_bsp/hw/ps7_init_gpl.[ch] board/xilinx/zynq/custom_hw_platform

Build u-boot

    $ make

Copy the `u-boot.elf` file to the zeST `setup` directory:

    $ cp u-boot.elf $HOME/src/zest/setup

## Make BOOT.bin

You need to make a `BOOT.bin` file that embeds the FSBL, the bitstream, u-boot and a device tree file for u-boot.

If you have performed the previous steps correctly, you should now have the following files in your `$HOME/src/zest/setup` directory:

- `devicetree.dtb`
- `fsbl.elf`
- `zest_top.bit`
- `u-boot.elf`

In `$HOME/src/zest/setup` you should find a `boot.bif` text file containing the following:
```
//arch = zynq; split = false; format = BIN
the_ROM_image:
{
        [bootloader]fsbl.elf
        zest_top.bit
        u-boot.elf
        devicetree.dtb
}
```

The file describes the proper pathnames for the different required files.

Issue the command:

    $ /opt/Xilinx/Vitis/2020.2/bin/bootgen -arch zynq -image boot.bif -o BOOT.bin

If everything went correctly, now you’ve got the required `BOOT.bin` file.

## Make boot.scr

TODO

## Build the Linux kernel

Get the Linux source code:

    $ git clone https://github.com/Xilinx/linux-xlnx.git
    $ git checkout xilinx-v2020.2

Create the default configuration file:

    $ make xilinx_zynq_defconfig

Build the kernel and copy the image file to your zeST `setup` directory:

    $ make UIMAGE_LOADADDR=0x8000 uImage
    $ cp arch/arm/boot/uImage $HOME/src/zest/setup
