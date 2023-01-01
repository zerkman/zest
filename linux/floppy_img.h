/*
 * floppy_img.h - floppy disk image file management
 *
 * Copyright (c) 2022,2023 Francois Galea <fgalea at free.fr>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */


#ifndef __FLOPPY_IMG__
#define __FLOPPY_IMG__

#include <stdint.h>

#define MAXTRACK 84

typedef struct {
  int fd;         // file descriptor
  int format;     // 0:mfm 1:st
  int rdonly;
  int wrb;
  int ntracks;
  int nsides;
  int nsectors;
  int image_size;
  uint8_t buf[6250*2*MAXTRACK];

} Flopimg;

Flopimg * flopimg_open(const char *filename, int rdonly, int skew);

/* set writeback flag = rewrite image file when closed */
void flopimg_writeback(Flopimg *img);

uint8_t * flopimg_trackpos(Flopimg *img, int track, int side);

void flopimg_sync(Flopimg *img);

void flopimg_close(Flopimg *img);


#endif
