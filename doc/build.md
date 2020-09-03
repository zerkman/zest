
# How to generate everything from source

## Required material

You’ll need:
 - Vivado and Vivado SDK. The version I used is 2019.1.
 - Development tools:
  - git
  - make
  - device-tree-compiler

My build system is a Debian bullseye Linux system, but I believe any GNU/Linux system will do.

## Create the Vivado project and generate the bitstream file

### Download the board definition files

To get the Z-Turn board definition files for Vivado, use the command:

    git clone https://github.com/q3k/zturn-stuff

The directory for the board definition files is `zturn-stuff/boards`.

### Create the Vivado project

 - Open Vivado
 - In Tools -> Settings menu, "Boards Repository" tab. Add the directory for your board definition files
 - From the main window, in the "Quick Start" section, click "Create Projet".
  - From the "New Project" wizard window, click "Next" to skip the first frame
  - Set `zest` as the project name, and choose a location for the project. Enable the "Create project subdirectory" so all project files will be in the `project_location/zest` subdirectory. Click "Next".
  - As project type, choose "RTL project". Ensure the "Do not specify sources at this time" checkbox stays unchecked. Click "Next".
  - Now you have to add the source files to the project. Click "Add files" and select all files from the `zest/hdl` directory in the zest source code tree. Click "Add files" again and add all files from the `fx68k` directory. Set target language as VHDL. Click "Next".
  - Now you need to add the constraint file corresponding to your FPGA board. Click "Add files" and select the constraint file for your board from the `zest/xdc` directory in the zest source code tree. Click "Next".
  - Now you have to choose the FPGA platform the project is for. Click "Boards" at the top, and select your board. Click "Next".
  - Click "Finish" to create the project.
 - Now you’ll have the Vivado project open with different panels and windows. You now need to import a block design file specific to your board (from the source `zest/tcl` subdirectory). In the bottom panel, select the "TCL Console" tab. Type the command line:
       source /path/to/zest/tcl/board_bd.tcl
 - From the left panel, select the project manager, then in the Sources panel, right-click on `ps_domain` and select "Create HDL wrapper". In the dialog box, leave all default options and click OK.

Now your Vivado project setup is complete.

### Generate the bitstream file

 - From the left panel, in "Program and debug", click "Generate Bitstream". The process will take a few minutes to complete.
