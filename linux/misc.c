/*
 * misc.c - various utility functions
 *
 * Copyright (c) 2024-2025 Francois Galea <fgalea at free.fr>
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

#include "misc.h"

// compute RGB gradient in [start..finish) interval
void gradient(uint32_t *palette, int n_values, uint32_t start, uint32_t finish) {
  // RGB components in 8.8 fixed point
  int r = ((start>>16)&0xff)<<8;
  int g = ((start>>8)&0xff)<<8;
  int b = (start&0xff)<<8;
  int fr = ((finish>>16)&0xff)<<8;
  int fg = ((finish>>8)&0xff)<<8;
  int fb = (finish&0xff)<<8;
  int dr = (fr-r)/n_values;
  int dg = (fg-g)/n_values;
  int db = (fb-b)/n_values;
  int i;
  for (i=0;i<n_values;++i) {
    palette[i] = (r>>8)<<16 | (g>>8)<<8 | b>>8;
    r += dr;
    g += dg;
    b += db;
  }
}
