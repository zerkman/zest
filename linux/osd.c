/*
 * osd.c - On screen display library
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


#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "osd.h"

extern volatile uint32_t *parmreg;

volatile struct {
  unsigned int show       : 1;    // show the OSD
  unsigned int reserved   : 31;   // reserved for future use
  uint16_t xsize;           // number of pixels in the OSD (width)
  uint16_t ysize;           // number of pixels in the OSD (height)
  uint16_t xpos;            // X position of the OSD from the left border
  uint16_t ypos;            // Y position of the OSD from the top border
  uint32_t resvd0[5];
  uint8_t palette[4][3];    // initial palette
  uint32_t resvd1[5];
  uint32_t colourchg[228];  // per-line colour changes (bits 31:24 - colour id)
  uint32_t bitmap[1804];    // pixels
} *osdreg;                  // size = 8192 bytes

static unsigned int _width;
static unsigned int _height;

uint32_t *osd_bitmap;

int osd_init(void) {
  if (osdreg == NULL) {
    if (parmreg == NULL) {
      return 1;
    }
    osdreg = (void*)(((uint8_t*)parmreg)+0x2000);
    osd_bitmap = (uint32_t*)osdreg->bitmap;
  }
  return 0;
}

// set dimension of OSD in pixels
// width will be rounded to the closest lower or equal multiple of 16
// max height is 256
// max width*height = 28864
void osd_set_size(int width, int height) {
  if (osdreg != NULL) {
    width = (width+15)&-16;
    if (height>MAX_SCANLINES) {
      printf("error: requested OSD height (%d) is too large (max=%d)\n",height,MAX_SCANLINES);
      return;
    }
    int pxsize = width*height/4;
    int maxsz = sizeof(osdreg->bitmap);
    if (pxsize > maxsz) {
      printf("error: requested OSD size (%d bytes) is too large (max=%d)\n",pxsize,maxsz);
      return;
    }
    osdreg->xsize = width;
    osdreg->ysize = height;
    _width = width;
    _height = height;
  }
}

void osd_set_position(int xpos, int ypos) {
  if (osdreg != NULL) {
    osdreg->xpos = xpos;
    osdreg->ypos = ypos;
  }
}

// update OSD surface
void osd_refresh(void) {
  // dummy function
}

void osd_show() {
  if (osdreg != NULL) {
    osdreg->show = 1;
  }
}

void osd_hide() {
  if (osdreg != NULL) {
    osdreg->show = 0;
  }
}

// set colour palette from top to first colour changes (if any)
void osd_set_palette(const uint32_t palette[4]) {
  int i;
  for (i=0;i<4;++i) {
    osdreg->palette[i][0] = palette[i]>>16;
    osdreg->palette[i][1] = palette[i]>>8;
    osdreg->palette[i][2] = palette[i];
  }
}

// set colour palette changes at scanlines
// entry format: col_id<<24 | rgb
// if col_id>=4 no change is done
void osd_set_palette_changes(const uint32_t *col_chg, int count) {
  if (count>0) {
    // special case for row 0: change the default palette entry
    uint32_t c0 = col_chg[0];
    int i = c0>>24;
    if (i<=3) {
      osdreg->palette[i][0] = c0>>16;
      osdreg->palette[i][1] = c0>>8;
      osdreg->palette[i][2] = c0;
    }
    // copy the colour changes for rows>0
    if (count>1) memcpy((void*)osdreg->colourchg,col_chg+1,(count-1)*sizeof(uint32_t));
  }
}
