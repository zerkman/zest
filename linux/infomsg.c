/*
 * infomsg.c - Information message display on OSD
 *
 * Copyright (c) 2023-2024 Francois Galea <fgalea at free.fr>
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

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>

#include "osd.h"
#include "setup.h"
#include "infomsg.h"

#define XPOS 250
#define YPOS 32

extern volatile int thr_end;

static int msg_on;
static uint64_t msg_timeout;

uint64_t gettime(void) {
  struct timeval tv;
  gettimeofday(&tv,NULL);
  return tv.tv_sec*1000000 + tv.tv_usec;
}

void * thread_infomsg(void * arg) {
  osd_init();

  while (thr_end==0) {
    usleep(1000);
    if (msg_on && gettime()>=msg_timeout) {
      infomsg_hide();
    }
  }
  return NULL;
}

void infomsg_hide(void) {
  msg_on = 0;
  osd_hide();
}

static void show(void) {
  static const uint8_t palette[] = {
    0,0,0,
    255,255,192,
    32,32,32,
    128,255,128,
    255,128,128,
    255,255,255,
    255,255,255,
    255,255,255,
  };
  osd_set_palette_all(palette);
  osd_show();
  msg_on = 1;
  msg_timeout = 3000000+gettime();
}

void infomsg_display(const char* msg) {
  int len = strlen(msg);
  osd_set_size(len,1);
  osd_set_position(XPOS,YPOS);
  osd_text(msg,0,0,1,0);
  show();
}

static void show_volume(int vol) {
  int i;
  osd_set_size(33,1);
  osd_set_position(XPOS,YPOS);
  osd_putchar(0x0b,0,0,1,0);
  osd_putchar(' ',1,0,1,0);
  for (i=0;i<31;++i) {
    if (i>=vol) {
      osd_putchar(' ',i+2,0,1,2);
    } else if (i<=16) {
      osd_putchar(' ',i+2,0,1,3);
    } else {
      osd_putchar(' ',i+2,0,1,4);
    }
  }
  show();
}

void vol_mute(void) {
  int mute = !get_sound_mute();
  set_sound_mute(mute);
  if (mute) {
    infomsg_display("\x0b off");
  } else {
    infomsg_display("\x0b on");
  }
}

void vol_down(void) {
  int vol = get_sound_vol()-1;
  if (vol>=0) {
    set_sound_vol(vol);
    show_volume(vol);
  }
}

void vol_up(void) {
  int vol = get_sound_vol()+1;
  if (vol<32) {
    set_sound_vol(vol);
    show_volume(vol);
  }
}
