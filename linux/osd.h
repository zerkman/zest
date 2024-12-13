/*
 * osd.h - On screen display library
 *
 * Copyright (c) 2020-2024 Francois Galea <fgalea at free.fr>
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

extern uint32_t *osd_bitmap;

// Initialize the OSD system
int osd_init(void);

// set dimension of OSD in pixels
// width will be rounded to the closest lower or equal multiple of 16
// max height is 256
// max width*height = 28864
void osd_set_size(int width, int height);

// set X and Y location of OSD (in pixels)
void osd_set_position(int xpos, int ypos);

// update OSD surface
void osd_refresh(void);

// show OSD
void osd_show();

// hide OSD
void osd_hide();

// set colour palette from top to first colour changes (if any)
void osd_set_palette(const uint32_t palette[4]);

// set colour palette changes at scanlines
// entry format: col_id<<24 | rgb
// if col_id>=4 no change is done
void osd_set_palette_changes(const uint32_t *col_chg, int count);

#endif
