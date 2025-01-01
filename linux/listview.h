/*
 * listview.h - List view system in the zeST OSD menu
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

#ifndef __LISTVIEW_H__
#define __LISTVIEW_H__

#include <stdint.h>
#include <dirent.h>

typedef struct listview ListView;

#define LV_FILE_EJECTABLE 0x0001

// must be called once before first call to lv_new
void lv_init(const char *font_file_name);

// return entry height in pixels
int lv_entry_height(void);

ListView *lv_new(int xpos, int ypos, int width, int height, const char *header, const uint32_t *palette);

void lv_set_colour_change(ListView *lv, int line_no, int col_no, uint32_t rgb);

// add entry with exit action
int lv_add_action(ListView *lv, const char *title);

// add entry with a list of choices
int lv_add_choice(ListView *lv, const char *title, int *pselect, int count, ...);

// add entry with a file to select
// possible flags:
// - LV_FILE_EJECTABLE: the user can "eject" the file using the Delete/Backspace keys, or appropriate controller button
// - LV_FILE_DIRECTORY: select a directory instead of a file
int lv_add_file(ListView *lv, const char *title, const char **pfilename, int flags, int (*filter)(const struct dirent *));

void lv_delete(ListView *lv);

int lv_select(ListView *lv, int selected);

int lv_run(ListView *lv);

#endif // __LISTVIEW_H__
