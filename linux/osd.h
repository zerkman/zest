/*
 * osd.h - On screen display library
 *
 * Copyright (c) 2020-2023 Francois Galea <fgalea at free.fr>
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


#ifndef __OSD_H__
#define __OSD_H__

#include <stdint.h>

#define MAX_SCANLINES 192

// Initialize the OSD system
int osd_init(void);

// set dimension of OSD (in characters)
void osd_set_size(int xchars, int ychars);

// set X and Y location of OSD (in pixels)
void osd_set_position(int xpos, int ypos);

// show OSD
void osd_show();

// hide OSD
void osd_hide();

// clear the OSD display (fill with spaces)
void osd_clear(int bgc);

// print string at specified location and colours
void osd_text(const char *text, int x, int y, int fgc, int bgc);

// print character at specified location and colours
void osd_putchar(int c, int x, int y, int fgc, int bgc);

// set same colour palette to all scanlines
void osd_set_palette_all(const uint8_t data[8*3]);

// set colour palettes to a group of scanlines
void osd_set_palette(int row, int nrows, const uint8_t data[][8*3]);

#endif
