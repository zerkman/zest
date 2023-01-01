/*
 * zui.h - zeST user interface
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


#ifndef __ZUI_H__
#define __ZUI_H__

#include <stdint.h>

typedef struct _zui_widget ZuiWidget;

// Panel widget - container for widgets
ZuiWidget * zui_panel(int x, int y, int width, int height);

// Text widget with default values
ZuiWidget * zui_text(int x, int y, const char *text);

// Text widget
ZuiWidget * zui_text_ext(int x, int y, const char *text, int fgcol, int bgcol);

// Button widget with default values
ZuiWidget * zui_button(int x, int y, const char *text, int (*onclick)(ZuiWidget*));

// Button widget
ZuiWidget * zui_button_ext(int x, int y, const char *text, int (*onclick)(ZuiWidget*), int fgcol, int bgcol, int fccol, int encol);

// Change widget text
void zui_set_text(ZuiWidget *obj, const char *text);

// Add child to container widget
void zui_add_child(ZuiWidget * parent, ZuiWidget * child);

// Run the UI
int zui_run(int xpos, int ypos, ZuiWidget *obj);

// Deallocate a hierarchy of widgets
void zui_free(ZuiWidget * root);

#endif
