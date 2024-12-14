/*
 * infomsg.c - Information message display on OSD
 *
 * Copyright (c) 2024 Francois Galea <fgalea at free.fr>
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
#include "font.h"
#include "infomsg.h"
#include "misc.h"

/* from listview.c */
extern Font *lv_font;

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
  static const uint32_t palette[] = { 0x000000,0xffffff,0x202020,0x80ff80 };
  osd_set_palette(palette);
  osd_show();
  msg_on = 1;
  msg_timeout = 3000000+gettime();
}

static void infomsg_display(const char* msg) {
  int width = font_text_width(lv_font,msg);
  int height = font_get_height(lv_font);
  uint32_t changes[height];
  gradient(changes,height,0xDE7709,0x8C4814);
  int i;
  for (i=0;i<height;++i) changes[i] = 1<<24 | changes[i];
  osd_set_palette_changes(changes,height);

  int raster_count = (width+15)/16;
  osd_set_size(raster_count*16,height);
  osd_set_position(XPOS,YPOS);
  memset(osd_bitmap,0,raster_count*height*sizeof(uint32_t));
  font_render_text(lv_font,osd_bitmap,raster_count,2,height,raster_count*16,0,msg);
  show();
}

static void show_volume(int vol) {
  char buf[40];
  int pc = vol*100/16;
  sprintf(buf,"Vol: %d%%",pc);
  infomsg_display(buf);
}

void vol_mute(void) {
  int mute = !get_sound_mute();
  set_sound_mute(mute);
  if (mute) {
    infomsg_display("Sound off");
  } else {
    infomsg_display("Sound on");
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
