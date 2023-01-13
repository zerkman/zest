/*
 * config.h - zeST configuration
 *
 * Copyright (c) 2023 Francois Galea <fgalea at free.fr>
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

#ifndef __CONFIG_H__
#define __CONFIG_H__


enum cfg_mem_size {
  CFG_256K = 0,
  CFG_512K,
  CFG_1M,
  CFG_2M,
  CFG_2_5M,
  CFG_4M
};


typedef struct {
  // main
  int mono;                         // 1 if mono, 0 if colour mode
  enum cfg_mem_size mem_size;       // memory size
  int wakestate;                    // wakestate (1-4)
  const char *rom_file;             // ROM file, full path

  // floppy
  const char *flopimg_dir;          // Default directory to open new image files
  const char *floppy_a;             // Floppy image file, full path
} ZestConfig;

extern ZestConfig config;

// Load config from file
void config_load(const char *filename);


#endif
