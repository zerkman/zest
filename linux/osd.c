/*
 * osd.c - On screen display library
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


#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#define MAX_SCANLINES 192


void *uio_map(const char *file, size_t length, int *fd);

volatile struct {
  unsigned int show       : 1;    // show the OSD
  unsigned int reserved   : 31;   // reserved for future use
  uint16_t xchars;          // number of characters in the OSD (width)
  uint16_t ychars;          // number of characters in the OSD (height)
  uint16_t xpos;            // X position of the OSD from the left border
  uint16_t ypos;            // Y position of the OSD from the top border
  uint32_t config[13];      // reserved
  uint16_t palette[MAX_SCANLINES][4]; // max 192 scanlines (24 chars), 4 colours per scanline
  uint16_t text[1248];      // max. 1248 displayed characters
} *osdreg;                  // size = 4096 bytes

int osdfd;
int _xchars;
int _ychars;

int osd_init(void) {
  if (osdreg == NULL) {
    osdreg = uio_map("/dev/uio1",0x1000,&osdfd);
    if (osdreg == NULL) {
      return 1;
    }
  }
  return 0;
}

void osd_set_size(int xchars, int ychars) {
  if (osdreg != NULL) {
    int nchars = xchars*ychars;
    int maxchars = sizeof(osdreg->text)/sizeof(osdreg->text[0]);
    if (nchars > maxchars) {
      printf("error: requested OSD size (%d) is too large (max=%d)\n",nchars,maxchars);
      return;
    }
    osdreg->xchars = xchars;
    osdreg->ychars = ychars;
    _xchars = xchars;
    _ychars = ychars;
  }
}

void osd_set_position(int xpos, int ypos) {
  if (osdreg != NULL) {
    osdreg->xpos = xpos;
    osdreg->ypos = ypos;
  }
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

void osd_clear(int bgc) {
  if (osdreg != NULL) {
    int n = _xchars*_ychars;
    int i;
    int v = (bgc&3)<<10 | ' ';
    volatile uint16_t *p = osdreg->text;
    for (i=0; i<n; ++i) {
      *p++ = v;
    }
  }
}

void osd_text(const char *text, int x, int y, int fgc, int bgc) {
  if (osdreg != NULL) {
    int i;
    int l = strlen(text);
    int mode = (fgc&3)<<8 | (bgc&3)<<10;
    volatile uint16_t *p = osdreg->text + y*_xchars + x;
    for (i=0; i<l; ++i) {
      *p++ = mode | (uint8_t)text[i];
    }
  }
}

void osd_putchar(int c, int x, int y, int fgc, int bgc) {
  if (osdreg != NULL) {
    osdreg->text[y*_xchars + x] = (c&255) | (fgc&3)<<8 | (bgc&3)<<10;
  }
}

void osd_set_palette_all(const uint16_t data[4]) {
  if (osdreg != NULL) {
    int i;
    for (i=0; i<MAX_SCANLINES; ++i) {
      memcpy((void*)osdreg->palette[i],data,8);
    }
  }
}

void osd_set_palette(int row, int nrows, const uint16_t data[][4]) {
  if (osdreg != NULL) {
    memcpy((void*)osdreg->palette[row],data,nrows*8);
  }
}
