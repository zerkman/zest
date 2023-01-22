# Makefile - Generate zest host program
#
# Copyright (c) 2020-2023 Francois Galea <fgalea at free.fr>
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

# You can set the path to your local buildroot toolchain by uncommenting the
# following line and setting the correct path.
#export PATH:=$(HOME)/src/buildroot-2022.02.8/output/host/bin:$(PATH)

TOOLCHAIN=arm-linux-
CC=$(TOOLCHAIN)gcc
CXX=$(TOOLCHAIN)g++
LD=$(TOOLCHAIN)ld
AR=$(TOOLCHAIN)ar

TARGETS=zeST
CFLAGS=-g -Wall -Os
LDLIBS=`pkg-config --libs inih`

all: $(TARGETS)

clean:
	rm -f *.o $(TARGETS)

zeST: setup.o floppy.o floppy_img.o ikbd.o sil9022a.o osd.o zui.o menu.o input.o config.o
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

setup.o: setup.c config.h setup.h

config.o: config.c config.h

menu.o: menu.c menu.h zui.h setup.h osd.h config.h

osd.o: osd.c osd.h

zui.o: zui.c zui.h input.h

floppy.o: floppy.c floppy_img.h config.h

floppy_img.o: floppy_img.c floppy_img.h

ikbd.o: ikbd.c input.h
