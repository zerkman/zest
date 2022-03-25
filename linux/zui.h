/*
 * zui.h - zeST user interface
 *
 * Copyright (c) 2022 Francois Galea <fgalea at free.fr>
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


#ifndef __ZUI_H__
#define __ZUI_H__

#include <stdint.h>

typedef struct _zui_widget ZuiWidget;

ZuiWidget * zui_panel(int x, int y, int width, int height);

ZuiWidget * zui_text(int x, int y, const char *text);

ZuiWidget * zui_button(int x, int y, const char *text, void (*onclick)(ZuiWidget*));

void zui_add_child(ZuiWidget * parent, ZuiWidget * child);

void zui_run(int xpos, int ypos, ZuiWidget *obj);

void zui_free(ZuiWidget * root);

#endif
