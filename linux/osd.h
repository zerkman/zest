/*
 * osd.h - On screen display library
 *
 * Copyright (c) 2020-2022 Francois Galea <fgalea at free.fr>
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


int osd_init(void);

#ifndef __OSD_H__
#define __OSD_H__

#include <stdint.h>

#define OSDFLG_INVERSE 0x1

#define RGB(r,g,b) ((r&0x1f)<<11 | (g&0x3f)<<5 | (b&0x1f))

int osd_init(void);

void osd_set_size(int xchars, int ychars);

void osd_set_position(int xpos, int ypos);

void osd_show();

void osd_hide();

void osd_text(const char *text, int x, int y, int fgc, int bgc, unsigned int flags);

void osd_set_colours(int row, int nrows, const uint16_t *data);

#endif
