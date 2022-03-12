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
#include <linux/input-event-codes.h>

#include "osd.h"

#define XCHARS 60
#define YCHARS 20   // XCHARS*YCHARS must not exceed 1248
#define XPOS 176
#define YPOS 116

// From ikbd.c
int input_event(int timeout, int *type, int *code, int *value);

extern volatile int thr_end;

void text_centered(const char *text, int ypos, int fg, int bg) {
  int s = strlen(text);
  osd_text(text,(XCHARS-s)/2,ypos,fg,bg);
}

void menu_bar(int active_item) {
  static const char * headers[] = { "File", "Disk", "Hardware", "About" };
  char buf[XCHARS+1];
  memset(buf,' ',XCHARS);
  buf[XCHARS] = 0;
  osd_text(buf,0,0,1,0);
  int i;
  for (i=0; i<4; ++i) {
    int fg,bg;
    memset(buf,' ',XCHARS/4);
    buf[XCHARS/4] = 0;
    memcpy(buf+2,headers[i],strlen(headers[i]));

    if (i==active_item) {
      fg = 1;
      bg = 0;
    } else {
      fg = 0;
      bg = 1;
    }
    osd_text(buf,i*15,0,fg,bg);
    osd_putchar(headers[i][0],i*15+2,0,2,bg);
  }
}


void display_dummy(void) {
}

void display_about(void) {
  osd_text("  zeST  ",XCHARS/2-4,3,0,1);
  text_centered("by zerkman / Sector One",5,1,0);
  text_centered("https://zest.sector1.fr",10,3,0);
}

void display(int menuid) {
  void (*displayfunc[4])(void) = { display_dummy, display_dummy, display_dummy, display_about };
  osd_clear(0);
  menu_bar(menuid);
  displayfunc[menuid]();
}

void menu(void) {
  static const uint16_t osd_palette[] = { RGB(0x40,0x40,0x40), RGB(0xc0,0xc0,0xc0), RGB(0xff,0x40,0x40), RGB(0x40,0x40,0xff) };
  int quit = 0;
  int menuid = 3;

  osd_init();
  osd_set_size(XCHARS,YCHARS);
  osd_set_position(XPOS,YPOS);
  osd_set_palette_all(osd_palette);
  display(menuid);
  osd_show(1);

  while (quit == 0 && thr_end == 0) {
    int evtype, evcode, evvalue;
    int retval = input_event(100,&evtype,&evcode,&evvalue);
    if (retval < 0) {
      // an error occurred
      break;
    }
    if (retval > 0 && evtype == EV_KEY && evvalue == 1) {
      int newid = menuid;
      switch (evcode) {
        case KEY_ESC:
        case KEY_SCREENLOCK:
          quit = 1;
          break;
        case KEY_F1:
        case KEY_F2:
        case KEY_F3:
        case KEY_F4:
          newid = evcode-KEY_F1;
          break;
        case KEY_F: newid = 0; break;
        case KEY_D: newid = 1; break;
        case KEY_H: newid = 2; break;
        case KEY_A: newid = 3; break;
        default:
          break;
      }
      if (newid != menuid) {
        menuid = newid;
        display(menuid);
      }
    }
  }

  osd_hide();


}
