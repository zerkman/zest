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

#define FILE_SELECTOR_VIEWS 3

typedef struct _file_selector_state {
  int total_listing_files;
  int file_selector_current_top;
  int file_selector_cursor_position;
  char selected_file[PATH_MAX];
  char current_directory[PATH_MAX];
} FILE_SELECTOR_STATE;

enum {
  FILE_SELECTOR_DISK_A,
  FILE_SELECTOR_DISK_B,
  FILE_SELECTOR_TOS_IMAGE
};

extern FILE_SELECTOR_STATE file_selector_state[FILE_SELECTOR_VIEWS];

#endif