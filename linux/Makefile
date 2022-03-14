# Makefile - Generate zest host program
#
# Copyright (c) 2020-2022 Francois Galea <fgalea at free.fr>
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

TARGETS=zeST
CFLAGS=-g -Wall -Os

all: $(TARGETS)

clean:
	rm -f *.o $(TARGETS)

zeST: setup.o floppy.o floppy_img.o ikbd.o sil9022a.o osd.o menu.o
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

setup.o: setup.c

menu.o: menu.c osd.h

osd.o: osd.c osd.h

floppy.o: floppy.c floppy_img.h

floppy_img.o: floppy_img.c floppy_img.h
