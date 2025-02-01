/*
 * infomsg.c - Information message display on OSD
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

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <dirent.h>

#include "osd.h"
#include "setup.h"
#include "font.h"
#include "infomsg.h"
#include "misc.h"
#include "floppy.h"
#include "config.h"

/* from listview.c */
extern Font *lv_font;
extern int file_select_compar(const struct dirent **a, const struct dirent **b);
extern int filter_flopimg(const struct dirent *e);
/* from infomsg.c */
extern uint64_t gettime(void);
/* from setup.c */
extern volatile int thr_end;


#define XPOS 40
#define YPOS 10
#define FLOPPY_STATUS_RASTER_COUNT 4

extern volatile int thr_end;

static int msg_on;
static int floppy_status_on;
static uint64_t msg_timeout;

uint64_t gettime(void) {
  struct timeval tv;
  gettimeofday(&tv,NULL);
  return tv.tv_sec*1000000 + tv.tv_usec;
}

static void disable_floppy_status() {
  if (floppy_status_on) {
    infomsg_hide();
  }
  floppy_status_on = 0;
}

void switch_floppy_status() {
  floppy_status_on = !floppy_status_on;
  if (floppy_status_on) {
    msg_on = 0;
    static const uint32_t palette[] = { 0x000000,0xffffff,0x202020,0x80ff80 };
    osd_set_palette(palette);
    int height = font_get_height(lv_font);
    uint32_t changes[height];
    gradient(changes,height,0x09DE77,0x148C48);
    int i;
    for (i=0;i<height;++i) changes[i] = 1<<24 | changes[i];
    osd_set_palette_changes(changes,height);
    osd_set_size(FLOPPY_STATUS_RASTER_COUNT*16,height);
    osd_set_position(XPOS,YPOS);
    osd_show();
  } else {
    osd_hide();
  }
}

void * thread_infomsg(void * arg) {
  int height = font_get_height(lv_font);
  while (thr_end==0) {
    usleep(50000);
    if (msg_on && gettime()>=msg_timeout) {
      infomsg_hide();
    }
    if (floppy_status_on) {
      char msg[80];
      memset(osd_bitmap,0,FLOPPY_STATUS_RASTER_COUNT*height*sizeof(uint32_t));
      unsigned int r,w,track,side;
      get_floppy_status(&r,&w,&track,&side);
      sprintf(msg,"%c T:%u S:%u",w?'W':r?'R':'.',track,side);
      font_render_text(lv_font,osd_bitmap,FLOPPY_STATUS_RASTER_COUNT,2,height,FLOPPY_STATUS_RASTER_COUNT*16,0,msg);
    }
  }
  return NULL;
}

void infomsg_hide(void) {
  msg_on = 0;
  floppy_status_on = 0;
  osd_hide();
}

static void show(void) {
  osd_show();
  msg_on = 1;
  msg_timeout = 3000000+gettime();
}


void infomsg_display(const char* msg) {
  static const uint32_t palette[] = { 0x000000,0xffffff,0x202020,0x80ff80 };
  osd_set_palette(palette);
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
  disable_floppy_status();
  int mute = !get_sound_mute();
  set_sound_mute(mute);
  if (mute) {
    infomsg_display("Sound off");
  } else {
    infomsg_display("Sound on");
  }
}

void vol_down(void) {
  disable_floppy_status();
  int vol = get_sound_vol()-1;
  if (vol>=0) {
    set_sound_vol(vol);
    show_volume(vol);
  }
}

void vol_up(void) {
  disable_floppy_status();
  int vol = get_sound_vol()+1;
  if (vol<32) {
    set_sound_vol(vol);
    show_volume(vol);
  }
}

void * thread_jukebox(void * arg) {
  while (thr_end == 0) {
    uint64_t time = gettime();
    usleep(1000);
    if (config.jukebox_enabled /*&& !file_selector_running*/) {
      if (time >= config.jukebox_timeout)
      {
        // Read directory
        struct dirent **namelist;
        int n = scandir(config.jukebox_path,&namelist,&filter_flopimg,&file_select_compar);
        if (n<=0)
        {
          infomsg_display("Error while reading jukebox directory. Jukebox off.");
        }

        // Select random image
        srand(time);
        char *selected_item;
        do {
          int selected_image = rand() % n;
          selected_item = namelist[selected_image]->d_name;
        } while (selected_item[strlen(selected_item)-1] == '/'); // Avoid directories - TODO is this needed any more?
        // Construct image filename
        char new_disk_image_name[PATH_MAX];
        strcpy(new_disk_image_name, config.jukebox_path);
        strcat(new_disk_image_name, selected_item);
        // Boot the image and set timeout
        change_floppy(new_disk_image_name,0);
        //config.mem_size = selected_ram_size;
        cold_reset();
        config.jukebox_timeout = config.jukebox_timeout_duration + gettime();
        infomsg_display(new_disk_image_name);
      }
    }
  }
  return NULL;
}
