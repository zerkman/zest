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
  uint16_t xchars;          // number of characters in the OSD (width)
  uint16_t ychars;          // number of characters in the OSD (height)
  uint16_t xpos;            // X position of the OSD from the left border
  uint16_t ypos;            // Y position of the OSD from the top border
  uint16_t sprt_pos[8][2];  // X and Y sprite position
  uint32_t sprt_colour[8];  // sprite colour
  uint32_t config[1];       // reserved
  uint8_t palette[MAX_SCANLINES][8][3]; // max 192 scanlines (24 chars), 8 colours per scanline
  uint16_t sprt_data[8][16]; // sprite pixel data
  uint16_t text[1624];      // max. 1624 displayed characters
} *osdreg;                  // size = 4096 bytes

int osdfd;
int _xchars;
int _ychars;

int osd_init(void) {
  if (osdreg == NULL) {
    if (parmreg == NULL) {
      return 1;
    }
    osdreg = (void*)(((uint8_t*)parmreg)+0x2000);
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
    int v = (bgc&7)<<11 | ' ';
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
    int mode = (fgc&7)<<8 | (bgc&7)<<11;
    volatile uint16_t *p = osdreg->text + y*_xchars + x;
    for (i=0; i<l; ++i) {
      *p++ = mode | (uint8_t)text[i];
    }
  }
}

void osd_putchar(int c, int x, int y, int fgc, int bgc) {
  if (osdreg != NULL) {
    osdreg->text[y*_xchars + x] = (c&255) | (fgc&7)<<8 | (bgc&7)<<11;
  }
}

void osd_set_palette_all(const uint8_t data[8*3]) {
  if (osdreg != NULL) {
    int i;
    for (i=0; i<MAX_SCANLINES; ++i) {
      memcpy((void*)osdreg->palette[i],data,8*3);
    }
  }
}

void osd_set_palette(int row, int nrows, const uint8_t data[][8*3]) {
  if (osdreg != NULL) {
    int i;
    for (i=0; i<nrows; ++i) {
      memcpy((void*)osdreg->palette[row+i],data[i],8*3);
    }
  }
}


void osd_calculate_gradient(const uint8_t col1[3], const uint8_t col2[3], int steps, uint8_t *output)
{
  if (steps<2 || steps>MAX_SCANLINES) return;
  uint32_t current_r = col1[0] << 24;
  uint32_t current_g = col1[1] << 24;
  uint32_t current_b = col1[2] << 24;
  uint32_t step_r = (int32_t)((col2[0] << 24)-current_r) / (steps-1);
  uint32_t step_g = (int32_t)((col2[1] << 24)-current_g) / (steps-1);
  uint32_t step_b = (int32_t)((col2[2] << 24)-current_b) / (steps-1);
  int i;
  current_r += 0x800000;
  current_g += 0x800000;
  current_b += 0x800000;
  for (i = 0; i < steps; i++)
  {
    *output++ = current_r >> 24;
    *output++ = current_g >> 24;
    *output++ = current_b >> 24;
    current_r += step_r;
    current_g += step_g;
    current_b += step_b;
  }
  // Here's an equivalent routine (more or less) using floats
  // Don't forget to "#include <math.h>" if you wish to use this
  /*
  float current_r = (float)col1[0];
  float current_g = (float)col1[1];
  float current_b = (float)col1[2];
  float step_r = ((float)col2[0]-current_r) / (float)(steps-1);
  float step_g = ((float)col2[1]-current_g) / (float)(steps-1);
  float step_b = ((float)col2[2]-current_b) / (float)(steps-1);
  int i;
  for (i = 0; i < steps; i++)
  {
    *output++ = (uint8_t)(rintf(current_r));
    *output++ = (uint8_t)(rintf(current_g));
    *output++ = (uint8_t)(rintf(current_b));
    current_r += step_r;
    current_g += step_g;
    current_b += step_b;
  }
  */
}
void osd_set_palette_with_one_gradient(const uint8_t static_cols[8*3],uint8_t gradient[MAX_SCANLINES][3],int gradient_index)
{
  uint8_t current_palette[8*3];
  memcpy(current_palette,static_cols,8*3);
  int i;
  uint8_t *gradient_rgb=&current_palette[gradient_index*3];
  for (i=0;i<MAX_SCANLINES;++i) {
    memcpy(gradient_rgb,gradient[i],3);
    osd_set_palette(i,1,(const uint8_t (*)[24]) current_palette);
  }
}
