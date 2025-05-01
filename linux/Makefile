# Makefile - Generate zest host program
#
# Copyright (c) 2020-2025 Francois Galea <fgalea at free.fr>
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
#export PATH:=$(HOME)/src/buildroot-2024.02.9/output/host/bin:$(PATH)

TOOLCHAIN=arm-linux-
CC=$(TOOLCHAIN)gcc
CXX=$(TOOLCHAIN)g++
LD=$(TOOLCHAIN)ld
AR=$(TOOLCHAIN)ar

TARGETS=zeST
CFLAGS=-g -Wall -Os
LDLIBS=`pkg-config --libs inih`
LDFLAGS=-s

all: $(TARGETS)

clean:
	rm -f *.o $(TARGETS)

zeST: setup.o floppy.o floppy_img.o hdd.o ikbd.o sil9022a.o osd.o menu.o input.o config.o listview.o misc.o font.o infomsg.o midi.o
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

setup.o: setup.c config.h setup.h

config.o: config.c config.h

menu.o: menu.c listview.h menu.h misc.h config.h setup.h floppy.h hdd.h

osd.o: osd.c osd.h

floppy.o: floppy.c floppy.h floppy_img.h hdd.h midi.h config.h

floppy_img.o: floppy_img.c floppy_img.h

ikbd.o: ikbd.c input.h menu.h config.h infomsg.h

listview.o: listview.c listview.h input.h osd.h font.h misc.h

misc.o: misc.c misc.h

font.o: font.c font.h

hdd.o: hdd.c hdd.h config.h

midi.o: midi.c midi.h config.h

infomsg.o: infomsg.c infomsg.h osd.h setup.h font.h config.h
