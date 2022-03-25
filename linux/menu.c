/*
 * menu.c - Setup menu
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
#include <string.h>
#include <stdio.h>

#include "zui.h"

#define XCHARS 60
#define YCHARS 20   // XCHARS*YCHARS must not exceed 1248
#define XPOS 176
#define YPOS 116

static void buttonclick_ok(ZuiWidget* obj) {
  printf("ok\n");
}

static void buttonclick_cancel(ZuiWidget* obj) {
  printf("cancel\n");
}

static void buttonclick_ignore(ZuiWidget* obj) {
  printf("ignore\n");
}

static void buttonclick_lol(ZuiWidget* obj) {
  printf("lol\n");
}

ZuiWidget * menu_form(void) {
  ZuiWidget * form = zui_panel(0,0,XCHARS,YCHARS);
  zui_add_child(form,zui_text(3,3,"Text 1"));
  zui_add_child(form,zui_text(4,5,"This is a larger text"));
  zui_add_child(form,zui_button(10,16,"  Ok  ",buttonclick_ok));
  zui_add_child(form,zui_button(18,16,"Ignore",buttonclick_ignore));
  zui_add_child(form,zui_button(26,16,"Cancel",buttonclick_cancel));
  zui_add_child(form,zui_button(34,16," LOL  ",buttonclick_lol));

  return form;
}

void menu(void) {
  ZuiWidget *form = menu_form();

  zui_run(XPOS,YPOS,form);

  zui_free(form);
}
