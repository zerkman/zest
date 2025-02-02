# Communication with the Linux system

One part of zeST runs on your board's Arm CPU, running a Linux embedded environment.

Advanced or even intermediary users can interact with it, to perform different tasks: managing files, transferring files from/to your personal computer, configuration, and more.

This document presents ways to interact with the zeST board using a computer (PC running Windows or Linux, Mac).

## Access from a computer

To access the Linux command line, follow the instructions of the next subsections.

### Serial console

For serial access you will need a terminal emulator on the computer.

 - on Windows or Mac, you can use a tool like [Tabby](https://tabby.sh/).
 - on Linux: minicom

The board's serial port is configured at 921600 bps, 8 bit, 1 stop bit, so configure your terminal emulator accordingly.
This setting has been chosen to speed up file transfers through serial.
Typical serial port is `COM8` on Windows, or `/dev/ttyUSB0` on Linux.

Connect your board to the computer with a standard USB cable.
That cable must be connected to the UART port of the board.

Once connected to the board, press Enter.
This should display a `Login:` prompt.
Type `root`, press Enter, and if you see the `#` prompt, this means you have successfully connected to the root account on the board.

This is a standard [unix shell](https://en.wikipedia.org/wiki/Unix_shell) session, so you can issue the usual shell commands.
We will not describe here how to use a unix shell, there are plenty of useful webpages for that, such as [this one](https://www.stationx.net/unix-commands-cheat-sheet/) or [this one](https://www.geeksforgeeks.org/basic-shell-commands-in-linux/).



### SSH over ethernet

Ethernet is working; it is configured to detect its IP address with DHCP.
However, in current releases of zeST, there is no SSH server configured.
This will be fixed in the future, once a valid, ramdisk-friendly, secure solution is established.


## The Linux OS

zeST's Linux operating system is an embedded system built using [Buildroot](https://buildroot.org/).
It is a minimal system that runs in a ramdisk.

Different operations can be done directly on this embedded Linux system.

### Start and stop zeST

Before manipulating files that are being used in zeST (such as the hard disk image file), you need to stop zeST.
This is done with the command:

    zestboot stop

To start zeST again:

    zestboot start

To just restart zeST:

    zestboot restart

Note that the `zestboot` script runs zeST so that it uses the default `/sdcard/zest.cfg` configuration file.
You can have it use a different configuration file with the command:

    zeST /path/to/config.cfg

In that case, zeST runs as a foreground process.
You can stop it again by pressing Ctrl+C.


### SD card mount point

The contents of the SD card can be seen in the `/sdcard` folder.

### File transfer through serial (zmodem)

To send a file from the computer to the current directory of your shell session, just initiate a zmodem transfer on your terminal utility (minicom: press Ctrl+a, then s).
The terminal utility will make use of the pre-installed `rz` command on the zeST linux system so the files are written on the current directory.

To send a file from the zeST shell session to your computer, use the `sz filename` command.

### Mount a partition from an Atari-formatted hard disk image file

Mounting a partition gives you access to its contents in a system directory.
From there you can copy, rename, delete files, transfer them with zmodem or ssh, whatever you may do on a disk drive.

**Warning #1**: Make sure you have stopped zeST before doing the following operations.
There is a risk that your data gets corrupted if you access the contents of the image when zeST is already accessing it.
To stop zeST, follow the instructions in the [Start and stop zeST](#start-and-stop-zest) section.

**Warning #2**: Once you are done with file management in the partition, you must unmount it before starting zeST again.

To mount the partition, you need to know the beginning sector number for that partition.
Those are listed when you partition the disk with your partitioning tool.
The first partition (partition C) normally should start from sector 2.

From the sector number, you can deduce an *offset* by multiplying it by 512.
Thus, for partition C the offset should be 1024.

The command for mounting a partition with offset 1024 from an image file located in `/sdcard/hdd.img` is the following:

    mount -oloop,offset=1024 -tmsdos /sdcard/hdd.img /mnt

The partition contents should then be accessible in the `/mnt` folder.
You can perform any file copies, deletions, renames, as you want.

When you are done with your modifications, unmount the partition with the command:

    umount /mnt
