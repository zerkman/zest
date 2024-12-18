/*
 * listview.c - List view system in the zeST OSD menu
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
#include <string.h>
#include <stdarg.h>
#include <dirent.h>
#include <unistd.h>
#include <linux/input-event-codes.h>

#include "listview.h"
#include "osd.h"
#include "font.h"
#include "input.h"
#include "misc.h"

// entry types
#define LV_ENTRY_ACTION 1
#define LV_ENTRY_CHOICE 2
#define LV_ENTRY_FILE 3

// width of choice field in 16-pixel rasters
#define N_RASTER_CHOICE 4
#define N_RASTER_FILE 6

Font *lv_font;

extern volatile int thr_end;

// make a screenshot of the OSD as a TGA image in the current directory
//void osd_screenshot(void);

struct lv_entry {
  int type;
  const char *title;
};

// basic object model in which all lv_* structs inherit from lv_entry
struct lv_action {
  struct lv_entry e;
};

struct lv_choice {
  struct lv_entry e;
  int n_choices;
  int *selected;
  const char **entries;
};

struct lv_file {
  struct lv_entry e;
  const char **filename;
  int flags;
  int (*filter)(const struct dirent *);
};

struct listview {
  int xpos;
  int ypos;
  int width;
  int height;
  int selected;             // selected entry
  int offset;               // first entry to display
  int align_left;
  const char *header;
  const uint32_t *palette;
  uint32_t *colour_change;
  int n_entries;
  int capacity;
  struct lv_entry **entries;
};

static int add_entry(ListView *lv,int type,const char *title,struct lv_entry *e) {
  if (lv->n_entries==lv->capacity) {
    lv->capacity = lv->capacity?lv->capacity*2:2;
    lv->entries = realloc(lv->entries,lv->capacity*sizeof(struct lv_entry*));
  }
  e->type = type;
  e->title = strdup(title);
  lv->entries[lv->n_entries] = e;
  return lv->n_entries++;
}

void lv_init(const char *font_file_name) {
  input_init();
  osd_init();
  lv_font = font_new_from_file(font_file_name);
}

int lv_entry_height(void) {
  return font_get_height(lv_font);
}

ListView *lv_new(int xpos, int ypos, int width, int height, const char *header, const uint32_t *palette) {
  ListView *lv = malloc(sizeof(ListView));
  memset(lv,0,sizeof(ListView));
  lv->xpos = xpos;
  lv->ypos = ypos;
  lv->width = width&-16;
  lv->height = height;
  lv->header = header;
  lv->palette = palette;
  lv->colour_change = malloc(height*sizeof(uint32_t));
  memset(lv->colour_change,-1,height*sizeof(uint32_t));
  return lv;
}

void lv_set_colour_change(ListView *lv, int line_no, int col_no, uint32_t rgb) {
  lv->colour_change[line_no] = col_no<<24 | rgb;
}

void lv_delete(ListView *lv) {
  if (lv) {
    int i;
    for (i=0;i<lv->n_entries;++i) {
      struct lv_entry *e = lv->entries[i];
      switch (e->type) {
      case LV_ENTRY_ACTION:
        //struct lv_action *a = (struct lv_action*)e;
        // nothing to free
        break;
      case LV_ENTRY_CHOICE: {
        struct lv_choice *ch = (struct lv_choice*)e;
        free(ch->entries);
        break;
      }
      case LV_ENTRY_FILE:
        //struct lv_file *fl = (struct lv_file*)e;
        break;
      }
      free((char*)e->title);
      free(e);
    }
    free(lv->entries);
    free(lv);
  }
}

// add entry with action function
int lv_add_action(ListView *lv, const char *title) {
  struct lv_action *a = malloc(sizeof(struct lv_action));
  return add_entry(lv,LV_ENTRY_ACTION,title,(struct lv_entry*)a);
}

// add entry with a list of choices
int lv_add_choice(ListView *lv, const char *title, int *pselect, int count, ...) {
  struct lv_choice *ch = malloc(sizeof(struct lv_choice));
  ch->n_choices = count;
  ch->selected = pselect;
  ch->entries = malloc(count*sizeof(const char*));

  int i;
  va_list ap;
  va_start(ap,count);
  for (i=0;i<count;++i) {
    ch->entries[i] = va_arg(ap,char*);
  }
  va_end(ap);
  return add_entry(lv,LV_ENTRY_CHOICE,title,(struct lv_entry*)ch);
}

// add entry with a file to select
// possible flags:
// - LV_FILE_EJECTABLE: the user can "eject" the file using the Delete/Backspace keys, or appropriate controller button
// - LV_FILE_DIRECTORY: select a directory instead of a file
int lv_add_file(ListView *lv, const char *title, const char **pfilename, int flags, int (*filter)(const struct dirent *)) {
  struct lv_file *fi = malloc(sizeof(struct lv_file));
  fi->filename = pfilename;
  fi->flags = flags;
  fi->filter = filter;
  return add_entry(lv,LV_ENTRY_FILE,title,(struct lv_entry*)fi);
}

static void display_entry(ListView *lv, int line_no) {
  int raster_count = lv->width/16;
  int font_height = font_get_height(lv_font);
  uint32_t *bitmap = osd_bitmap+(line_no+1)*raster_count*font_height;
  struct lv_entry *e = lv->entries[line_no+lv->offset];
  switch (e->type) {
  case LV_ENTRY_ACTION:
    font_render_text(lv_font,bitmap,raster_count,2,font_height,lv->width,0,e->title);
    break;
  case LV_ENTRY_CHOICE: {
    const struct lv_choice *ch = (struct lv_choice*)e;
    font_render_text(lv_font,bitmap,raster_count,2,font_height,(raster_count-N_RASTER_CHOICE)*16,0,e->title);
    font_render_text_centered(lv_font,bitmap+raster_count-N_RASTER_CHOICE,raster_count,2,font_height,N_RASTER_CHOICE*16,ch->entries[*ch->selected]);
    break;
  }
  case LV_ENTRY_FILE: {
    const struct lv_file *fl = (struct lv_file*)e;
    const char *filename = *fl->filename;
    if (filename) {
      const char *sep = strrchr(filename,'/');
      if (sep) filename = sep+1;
      if (!filename[0]) filename = NULL;
    }
    font_render_text(lv_font,bitmap,raster_count,2,font_height,(raster_count-N_RASTER_FILE)*16,0,e->title);
    font_render_text_centered(lv_font,bitmap+raster_count-N_RASTER_FILE,raster_count,2,font_height,N_RASTER_FILE*16,filename?filename:"<empty>");
  }
  }
}

static void highlight(ListView *lv, int line_no, int highlight) {
  int font_height = font_get_height(lv_font);
  unsigned int mask = highlight ? 0xffff : 0;
  int raster_count = lv->width/16;
  const struct lv_entry *e = lv->entries[line_no+lv->offset];
  if (e->type == LV_ENTRY_ACTION) {
    int beg_offset = raster_count*font_height*(line_no+1);
    int end_offset = raster_count*font_height*(line_no+2);
    int i;
    for (i=beg_offset;i<end_offset;++i) {
      *((uint16_t*)(osd_bitmap+i)+1) = mask;
    }
  } else {
    int i,y;
    int beg = raster_count-(e->type==LV_ENTRY_CHOICE ? N_RASTER_CHOICE : N_RASTER_FILE);
    uint32_t *bitmap = osd_bitmap+raster_count*font_height*(line_no+1);
    for (y=0;y<font_height;++y) {
      for (i=beg;i<raster_count;++i) {
        *((uint16_t*)(bitmap+i)+1) = mask;
      }
      bitmap += raster_count;
    }
  }
}

// clear the text zone of current choice before displaying a new value
static void clear_choice(ListView *lv) {
  const struct lv_entry *e = lv->entries[lv->selected];
  if (e->type == LV_ENTRY_CHOICE) {
    int font_height = font_get_height(lv_font);
    int raster_count = lv->width/16;
    int i,y;
    int beg = raster_count-N_RASTER_CHOICE;
    uint32_t *bitmap = osd_bitmap+raster_count*font_height*(lv->selected-lv->offset+1);
    for (y=0;y<font_height;++y) {
      for (i=beg;i<raster_count;++i) {
        *(uint16_t*)(bitmap+i) = 0;
      }
      bitmap += raster_count;
    }
  }
}

static void update_pos(ListView *lv, int new_pos) {
  if (new_pos==lv->selected)
    return;
  int i;
  int raster_count = lv->width/16;
  int font_height = font_get_height(lv_font);
  int old_offset = lv->offset;
  int max_display = lv->height/font_get_height(lv_font)-1;
  highlight(lv,lv->selected-lv->offset,0);
  int line_size = raster_count*font_height;
  uint32_t *bitmap = osd_bitmap+line_size;

  // scroll down
  if (new_pos-lv->offset>=max_display) {
    lv->offset = new_pos-max_display+1;
    int n_redisplay = lv->offset - old_offset;
    if (n_redisplay>max_display) n_redisplay = max_display;
    int n_scroll = max_display - n_redisplay;
    memmove(bitmap,bitmap+n_redisplay*line_size,n_scroll*line_size*sizeof(uint32_t));
    memset(bitmap+n_scroll*line_size,0,n_redisplay*line_size*sizeof(uint32_t));
    for (i=n_scroll;i<max_display;++i) {
      display_entry(lv,i);
    }
  }

  // scroll up
  if (new_pos<lv->offset) {
    lv->offset = new_pos;
    int n_redisplay = old_offset - lv->offset;
    if (n_redisplay>max_display) n_redisplay = max_display;
    int n_scroll = max_display - n_redisplay;
    memmove(bitmap+n_redisplay*line_size,bitmap,n_scroll*line_size*sizeof(uint32_t));
    memset(bitmap,0,n_redisplay*line_size*sizeof(uint32_t));
    for (i=0;i<n_redisplay;++i) {
      display_entry(lv,i);
    }
  }

  highlight(lv,new_pos-lv->offset,1);
  lv->selected = new_pos;
}

static void update_choice(ListView *lv, int new_ch) {
  const struct lv_entry *e = lv->entries[lv->selected];
  if (e->type == LV_ENTRY_CHOICE) {
    struct lv_choice *ch = (struct lv_choice*)e;
    *ch->selected = new_ch;
    clear_choice(lv);
    display_entry(lv,lv->selected-lv->offset);
  }
}

int lv_select(ListView *lv, int selected) {
  if (selected>=lv->n_entries) {
    lv->selected = lv->n_entries-1;
  } else if (selected<0) {
    lv->selected = 0;
  } else {
    lv->selected = selected;
  }
  return lv->selected;
}

static int file_select_compar(const struct dirent **a, const struct dirent **b) {
  // directories should come before files
  if ((*a)->d_type==DT_DIR && (*b)->d_type!=DT_DIR) {
    return -1;
  }
  if ((*a)->d_type!=DT_DIR && (*b)->d_type==DT_DIR) {
    return 1;
  }
  return strcasecmp((*a)->d_name,(*b)->d_name);
}

static const char *file_select(int xpos, int ypos, int width, int height, const char *init_file, int (*filter)(const struct dirent *), const uint32_t *palette) {
  char directory[1024];
  char init_file_name[256];
  init_file_name[0] = 0;

  // establish absolute directory location
  if (init_file==NULL) {
    getcwd(directory,sizeof(directory));
  } else if (init_file[0]=='/') {
    char *p = strrchr(init_file,'/');
    strcpy(init_file_name,p+1);
    int len = p-init_file;
    strncpy(directory,init_file,len);
    directory[len] = '\0';
  } else {
    getcwd(directory,sizeof(directory));
    char *p = strrchr(init_file,'/');
    if (p) {
      strcpy(init_file_name,p+1);
      int len = p-init_file;
      strcat(directory,"/");
      strncat(directory,init_file,len);
    } else {
      strcpy(init_file_name,init_file);
    }
  }

  int ret = 0;
  while (ret==0) {
    struct dirent **namelist;
    int n = scandir(directory,&namelist,filter,file_select_compar);

    ListView *fslv = lv_new(xpos, ypos, width, height, directory, palette);
    fslv->align_left = 1;
    int entry_height = lv_entry_height();
    uint32_t gradient_header[entry_height];
    gradient(gradient_header,entry_height,0x79de07,0x488c14);
    int i;
    for (i=0;i<entry_height;++i) {
      lv_set_colour_change(fslv,i,1,gradient_header[i]);
    }
    lv_set_colour_change(fslv,entry_height,1,palette[1]);
    lv_add_action(fslv,"<parent dir>");
    for (i=0;i<n;++i) {
      struct dirent *e = namelist[i];
      char buf[400];
      const char *name = e->d_name;
      if (e->d_type==DT_DIR) {
        sprintf(buf,"[%s]",name);
        name = buf;
      }
      int id = lv_add_action(fslv,name);
      if (!strcmp(e->d_name,init_file_name)) {
        lv_select(fslv,id);
      }
    }
    ret = lv_run(fslv);
    lv_delete(fslv);

    if (ret==0) {
      // parent dir
      char *p = strrchr(directory,'/');
      strcpy(init_file_name,p+1);
      if (p!=directory) {
        *p = '\0';
      } else {
        *++p = '\0';
      }
    } else if (ret>0) {
      if (strcmp(directory,"/")) strcat(directory,"/");
      strcat(directory,namelist[ret-1]->d_name);
      if (namelist[ret-1]->d_type==DT_DIR) ret = 0;
    }

    for (i=0;i<n;++i) {
      free(namelist[i]);
    }
    free(namelist);
  }

  if (ret==-1) return NULL;
  return strdup(directory);
}

static void lv_draw(ListView *lv) {
  if (lv->palette) osd_set_palette(lv->palette);
  osd_set_palette_changes(lv->colour_change,lv->height);
  osd_set_position(lv->xpos,lv->ypos);
  osd_set_size(lv->width,lv->height);

  int font_height = font_get_height(lv_font);
  int raster_count = lv->width/16;
  memset(osd_bitmap,0,raster_count*lv->height*sizeof(uint32_t));
  int offset = raster_count*font_height;
  int max_display = lv->height/font_height-1;
  int i;
  if (lv->align_left) {
    font_render_text(lv_font,osd_bitmap,raster_count,2,font_height,lv->width,0,lv->header);
  } else {
    font_render_text_centered(lv_font,osd_bitmap,raster_count,2,font_height,lv->width,lv->header);
  }
  int n_display = lv->n_entries<max_display ? lv->n_entries : max_display;
  for (i=0;i<n_display;++i) {
    display_entry(lv,i);
    offset += raster_count*font_height;
  }
  highlight(lv,lv->selected-lv->offset,1);
}

int lv_run(ListView *lv) {
  int font_height = font_get_height(lv_font);
  int max_display = lv->height/font_height-1;

  lv->offset = lv->selected-max_display/2;
  if (lv->offset>lv->n_entries-max_display) {
    lv->offset = lv->n_entries-max_display;
  }
  if (lv->offset<0) {
    lv->offset = 0;
  }
  lv_draw(lv);

  osd_show();

  int quit = 0;
  int funcret = -1;
  while (quit == 0 && thr_end == 0) {
    int evtype, evcode, evvalue, joyid;
    int retval = input_event(100,&evtype,&evcode,&evvalue,&joyid);
    int new_pos;
    if (retval < 0) {
      // an error occurred
      break;
    } else if (retval == 0) {
      osd_refresh();
      continue;
    }

    if (evtype == EV_KEY) {
      //printf("evtype=EV_KEY evcode=%d evvalue=%d\n",evcode,evvalue);
      // keyboard event, key is pressed
      if (evvalue >= 1) {
        // key is pressed
        struct lv_entry *e = lv->entries[lv->selected];
        switch (evcode) {
        case KEY_ESC:
          quit = 1;
          break;
        case KEY_DOWN:
          if (lv->selected<lv->n_entries-1) {
            update_pos(lv,lv->selected+1);
          }
          break;
        case KEY_UP:
          if (lv->selected>0) {
            update_pos(lv,lv->selected-1);
          }
          break;
        case KEY_PAGEDOWN:
          new_pos = lv->selected+max_display;
          if (new_pos>lv->n_entries-1) {
            new_pos = lv->n_entries-1;
          }
          update_pos(lv,new_pos);
          break;
        case KEY_PAGEUP:
          new_pos = lv->selected-max_display;
          if (new_pos<0) {
            new_pos = 0;
          }
          update_pos(lv,new_pos);
          break;
        case KEY_HOME:
          update_pos(lv,0);
          break;
        case KEY_END:
          update_pos(lv,lv->n_entries-1);
          break;
        case KEY_LEFT:
        case KEY_RIGHT:
          if (e->type==LV_ENTRY_CHOICE) {
            struct lv_choice *ch = (struct lv_choice*)e;
            if (evcode==KEY_LEFT) {
              update_choice(lv,(*ch->selected+ch->n_choices-1)%ch->n_choices);
            } else {
              update_choice(lv,(*ch->selected+1)%ch->n_choices);
            }
          }
          break;
        //case KEY_F2:
        //  osd_screenshot();
        //  break;
        case KEY_DELETE:
        case KEY_BACKSPACE:
          if (e->type==LV_ENTRY_FILE) {
            const struct lv_file *lf = (struct lv_file*)e;
            if ((lf->flags&LV_FILE_EJECTABLE) && *lf->filename) {
              char *p = (char*)strrchr(*lf->filename,'/');
              if (p) {
                osd_hide();
                p[1] = '\0';
                lv_draw(lv);
                osd_show();
              }
            }
          }
          break;
        case KEY_ENTER:
          if (e->type==LV_ENTRY_ACTION) {
            // struct lv_action *a = (struct lv_action*)e;
            funcret = lv->selected;
            quit = 1;
          }
          else if (e->type==LV_ENTRY_FILE) {
            const struct lv_file *lf = (struct lv_file*)e;
            osd_hide();
            const char *name = file_select(lv->xpos,lv->ypos,lv->width,lv->height,*lf->filename,lf->filter,lv->palette);
            if (name) {
              free((void*)*lf->filename);
              *lf->filename = name;
            }
            lv_draw(lv);
            osd_show();
          }
        }
      }
    }
  }

  osd_hide();

  return funcret;
}
