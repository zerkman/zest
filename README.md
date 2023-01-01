# zeST - An implementation of an Atari ST in VHDL

Copyright (c) 2019-2023 by François Galea (fgalea à free.fr)

This is a complete implementation of an Atari ST in VHDL, which targets cheap Xilinx Zynq-7000-based prototyping boards.

Its main features are:
- Cycle accuracy, whenever possible (and necessary)
- HDMI for video and audio output
- USB for keyboard, mouse input (planned: joysticks, mass storage, MIDI...).

External hardware cores zeST is based on:
- Jorge Cwik's [fx68k](https://github.com/ijor/fx68k.git) processor core, a cycle-accurate 68000 processor implementation
- Tsuyoshi Hasegawa's [HD63701 compatible processor core](https://opencores.org/projects/hd63701), used as the keyboard processor
- John Kent's [6850 compatible ACIA core](https://opencores.org/projects/system09)

All other components have been redesigned from scratch.


zeST is distributed under the GNU General Public License v3 licence.
See the LICENSE file or https://www.gnu.org/licenses/gpl-3.0.html for more details.

## Contributors
- François Galea
- George Nakos

## Links

- [Main project page](https://zest.sector1.fr)
- [Project building instructions](doc/build.md)
