# Makefile - Generate program data for simulation
#
# Copyright (c) 2020,2021 Francois Galea <fgalea at free.fr>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

TARGETS=display_checker.vhd display_checker.bin \
	hbl_vbl.vhd hbl_vbl.bin \
	mfp.bin mfp.vhd \
	acia.bin acia.vhd \
	all_hw.bin all_hw.vhd \

all: $(TARGETS)

clean:
	rm -f $(TARGETS)

%.bin: %.s
	vasmm68k_mot -Fbin $< -o $@

%.vhd: %.bin
	lua bin2array.lua $< > $@
