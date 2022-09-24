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
#include <dirent.h>
#include <glob.h> // For read_directory()
//#include <ctype.h>  // Needed for tolower(), but produces a ton of compiler errors, so let us declare it implicitly for now...
extern int tolower (int __c);
#include <unistd.h>
#include <limits.h> // for PATH_MAX

#include "menu.h"
#include "zui.h"
#include "osd.h"

extern volatile uint32_t *parmreg;  // From setup.c
extern int cfg;                     // From setup.c
extern void do_reset();             // From setup.c
extern int disk_image_changed;      // From floppy.c
extern void *disk_image_filename;   // From floppy.c

// From setup.c:
#define CFG_WS1  0x0000
#define CFG_WS2  0x0300
#define CFG_WS3  0x0100
#define CFG_WS4  0x0200
#define WS_MASK  0x0300

// Stuff that would be nice for the UI lib:
// - Changable text widgets (example: file selector text widgets that display the files)
// - Editable text widgets (example: filename entering)
// - Assign unique values to buttons so zui_run can return that (example: user clicked Ok? Cancel?)
// - Mouse cursor
// - Coloured text widgets (example: currently selected file)
// - Text effects (bold, underline)
// - When selecting an item (using Return) the button's called action to instruct zui_run() to close the panel and exit after executing
// - Some callbacks when form exits with Ok or Cancel? (example: change floppy image when Ok pressed in file selector, or load different TOS image)

// General file selector TODOs:
// - Implement moving with arrows
// - Generally, keyboard control for all functions would be neat (dir up, ok, cancel)
// - Typing letters should search for a filename (maybe partial matches, i.e. not from the start of the filename?)
// - Vertical (scroll) bar between ^ and v buttons
// - <@tInBot> and a history of last images comes to mind (does not need to be saved neccessarily)

// - At the moment zeST does not have support for two floppies.

#define XCHARS 60
#define YCHARS 20   // XCHARS*YCHARS must not exceed 1248
#define XPOS 176
#define YPOS 116
#define FSEL_XCHARS 40
#define FSEL_YCHARS 24 // TODO: no idea why yet, but setting this value any higher some garbage appears on screen
#define FSEL_XPOS 200
#define FSEL_YPOS 40
#if (FSEL_XCHARS*FSEL_YCHARS)>1248
#error Too many characters (FSEL_XCHARS*FSEL_YCHARS)
#endif
#if (XCHARS*YCHARS)>1248
#error Too many characters (XCHARS*YCHARS)
#endif

static int buttonclick_warm_reset(ZuiWidget* obj)
{
  parmreg[0]=cfg&0xfffffffe;    // Bit 0 clear=reset
  parmreg[0]=cfg|3;             // |3="end reset"
  return 0;
}

static int buttonclick_cold_reset(ZuiWidget* obj) {
  parmreg[0]=0;
  usleep(10000);
  do_reset();
  return 0;
}

FILE_SELECTOR_STATE file_selector_state[FILE_SELECTOR_VIEWS];
FILE_SELECTOR_STATE *current_view;
int view;

// File selector state
char file_selector_list[FSEL_YCHARS-2][FSEL_XCHARS];
glob_t glob_info;
char *directory_filenames[1024];  // Holds pointers to filtered directory items inside the glob struct
char blank_line[FSEL_XCHARS-1]="                                       "; // TODO: this should idealy be resized depending on FSEL_XCHARS

void populate_file_array()
{
  int i;
  for (i=0;i<FSEL_YCHARS-2;i++) {
    int j=0;
    char *s=directory_filenames[current_view->file_selector_current_top+i];
    if (!s) {
      break;
    }
    int len=strlen(s);
    char *d=file_selector_list[i];
    if (len>FSEL_XCHARS-1) {
      // Filename is too big to fit in one line, so copy as much as we can
      // from the left hand side, put a "[...]" at the middle, and then
      // copy as much as we can from the right hand side. That way
      // we can both see the start of the filename and the extension,
      // as well as stuff like "Disk X of Y"
      char *s2=s+len-((FSEL_XCHARS-1)/2-2);
      for (;j<(FSEL_XCHARS-1)/2-2;j++) {
        *d++=*s++;
      }

      *d++='['; *d++='.'; *d++='.'; *d++='.'; *d++=']';
      j += 5;

      for (;j<(FSEL_XCHARS-1)/1;j++) {
        *d++=*s2++;
      }
      *d=0;
    } else {
      // strcpy, but also fill the rest of the horizontal characters with spaces
      while (*s) {
        *d++=*s++;
        j++;
      }
      for (;j<FSEL_XCHARS-1;j++) {
        *d++=' ';
      }
      *d=0;
    }
  }
  // If we have too few filenames to fill the list, just fill the rest with blanks
  for (; i < FSEL_YCHARS-2; i++) {
    char *d=file_selector_list[i];
    strcpy(d, blank_line);
  }
}

void update_file_listing() {
  populate_file_array();
  int i;
  int first_colour=current_view->file_selector_current_top&1;    // This is done in order when the list scrolls, the odd/even lines will maintain their colour
  for (i=0;i<FSEL_YCHARS-2;i++) {
    int c=((i+first_colour)&1)+1;
    if (i==current_view->file_selector_cursor_position) {
      c=3;
    }
    osd_text(file_selector_list[i],0,i+1,c,0);
  }
}

static int buttonclick_fsel_up_arrow(ZuiWidget* obj) {
  if (current_view->file_selector_cursor_position) {
    current_view->file_selector_cursor_position--;
    update_file_listing();
  } else {
    if (current_view->file_selector_current_top) {
      current_view->file_selector_current_top--;
      update_file_listing();
    }
  }
  return 0;
}

static int buttonclick_fsel_down_arrow(ZuiWidget* obj) {
  if (current_view->file_selector_cursor_position<FSEL_YCHARS-3&&(current_view->file_selector_cursor_position+current_view->file_selector_current_top+1)<current_view->total_listing_files) {
    current_view->file_selector_cursor_position++;
    update_file_listing();
  } else {
    if (current_view->file_selector_current_top+FSEL_YCHARS-2<current_view->total_listing_files) {
      current_view->file_selector_current_top++;
      update_file_listing();
    }
  }
  return 0;
}

void read_directory(char *path) {
  char path_wildcard[128];
  strcpy(path_wildcard,path);
  strcat(path_wildcard,"*");

  int pathname_bytes_to_skip=strlen(path); // AKA the number of bytes to trim from the left hand side of the returned filenames, those contain the path
  char **current_glob;
  int i;

  // Get directories and place them at the beginning on the list
  // (so they won't get mixed up with the actual files)
  glob(path_wildcard,GLOB_MARK|GLOB_ONLYDIR,NULL,&glob_info);
  int number_of_files=glob_info.gl_pathc;
  current_view->total_listing_files=number_of_files;
  current_glob=glob_info.gl_pathv;

  for (i=0; i < number_of_files; i++) {
    directory_filenames[i] = *current_glob + pathname_bytes_to_skip;
    current_glob++;
  }

  glob(path_wildcard,GLOB_MARK|GLOB_APPEND,NULL,&glob_info); // GLOB_MARK=Append '/' to directories so we can filter them out too

  number_of_files += glob_info.gl_pathc;
  if (!number_of_files) {
    // TODO: Directory has no files or dirs. Could be an invalid path?
    //return;
  }

  // Get file listing, filter for the extensions we care about and add them to the list.
  // Turns out that uclibc doesn't support GLOB_BRACES by defalut, so we can't have a fancy
  // "{*.msa,*.st,*.mfm,*.MSA,*.ST,*.MFM}" pattern here. So we have to do the filtering by hand.
  // Maybe if we change the compilation options of uclibc we can switch to the above.
  current_glob=glob_info.gl_pathv;
  for (;i<number_of_files;i++) {
    if (strlen(*current_glob)>4) {
      char extension[4];
      char *p_three_chars=(*current_glob + strlen(*current_glob)-3);
      char *p_extension=extension;
      int k;
      for (k=0;k<4;k++) {
        *p_extension++=tolower(*p_three_chars++);
      }
      // TODO: this is terrible!
      if (view==FILE_SELECTOR_DISK_A||view==FILE_SELECTOR_DISK_B) {
        if (strcmp(extension, "msa")==0||strcmp(extension, ".st")==0||strcmp(extension, "mfm")==0) {
          directory_filenames[current_view->total_listing_files]=*current_glob + pathname_bytes_to_skip;
          current_view->total_listing_files++;
        }
      } else if (view==FILE_SELECTOR_TOS_IMAGE) {
        if (strcmp(extension, "img")==0||strcmp(extension, "rom")==0) {
          directory_filenames[current_view->total_listing_files]=*current_glob + pathname_bytes_to_skip;
          current_view->total_listing_files++;
        }
      }
    }
    current_glob++;
  }
  directory_filenames[current_view->total_listing_files]=0; // Terminate list
}

static int buttonclick_fsel_dir_up(ZuiWidget* obj) {
  int i=strlen(current_view->current_directory);
  if (i==1) {
    // We're at /
    return 0;
  }
  char *p=current_view->current_directory+i-2;
  while (*p!='/') {
    p--;
  }
  p[1]=0;   // Just null terminate after the /, this will remove the rightmost directory name

  // Update the form
  globfree(&glob_info);
  read_directory(current_view->current_directory);
  current_view->file_selector_cursor_position=0;
  update_file_listing();
  return 0;
}

extern const char *binfilename;
static int buttonclick_fsel_ok(ZuiWidget* obj) {
  char *selected_item=directory_filenames[current_view->file_selector_current_top+current_view->file_selector_cursor_position];
  if (selected_item[strlen(selected_item)-1]=='/') {
    // Enter directory
    // Append the selected item (AKA directory name) to the global path (it already has a trailing slash and all)
    strcat(current_view->current_directory,selected_item);
    globfree(&glob_info);
    read_directory(current_view->current_directory);
    current_view->file_selector_cursor_position=0;
    update_file_listing();
    return 0;   // Don't exit the dialog yet
  }
  if (view==FILE_SELECTOR_DISK_A||view==FILE_SELECTOR_DISK_B) {
    disk_image_filename=selected_item-strlen(current_view->current_directory);  // TODO: support for drive B?
    disk_image_changed=1;               // TODO: support for drive B?
  } else if (view==FILE_SELECTOR_TOS_IMAGE) {
    binfilename=selected_item;
  }
  return 1;
}

static int buttonclick_fsel_ok_reset(ZuiWidget* obj) {
  int ret=buttonclick_fsel_ok(obj);
  if (ret) {
    buttonclick_cold_reset(obj);
  }
  return ret;
}

static int buttonclick_fsel_cancel(ZuiWidget* obj) {
  globfree(&glob_info);
  return 1;
}

static void eject_floppy(int drive)
{
  disk_image_filename=0;
}

static int buttonclick_eject_floppy_a(ZuiWidget* obj) {
  eject_floppy(0);
  return 0;
}

static int buttonclick_eject_floppy_b(ZuiWidget* obj) {
  eject_floppy(1);
  return 0;
}

ZuiWidget * menu_file_selector() {
  ZuiWidget * form=zui_panel(0, 0, FSEL_XCHARS, FSEL_YCHARS);
  if (view==FILE_SELECTOR_DISK_A) {
    zui_add_child(form, zui_text(0, 0, "\x5    Select a disk image for drive A   \x7"));
  } else if (view==FILE_SELECTOR_DISK_B) {
    zui_add_child(form, zui_text(0, 0, "\x5Select a disk image for drive B (dud) \x7"));
  } else if (view==FILE_SELECTOR_TOS_IMAGE) {
    zui_add_child(form, zui_text(0, 0, "\x5          Select a TOS image          \x7"));
  }
  zui_add_child(form,zui_text(FSEL_XCHARS-1,FSEL_YCHARS-1,"\x6"));                               // "window resize" glyph on ST font
  zui_add_child(form,zui_button(FSEL_XCHARS-1,1,"\x1",buttonclick_fsel_up_arrow));               // up arrow glyph on ST font
  zui_add_child(form,zui_button(FSEL_XCHARS-1,FSEL_YCHARS-2,"\x2",buttonclick_fsel_down_arrow)); // down arrow on ST font
  zui_add_child(form,zui_button(1,FSEL_YCHARS-1,"Dir up",buttonclick_fsel_dir_up));
  if (view!=FILE_SELECTOR_TOS_IMAGE) {
    zui_add_child(form, zui_button(8, FSEL_YCHARS-1, "Ok", buttonclick_fsel_ok));
  }
  zui_add_child(form,zui_button(11,FSEL_YCHARS-1,"Ok (reset)",buttonclick_fsel_ok_reset));
  zui_add_child(form,zui_button(22,FSEL_YCHARS-1,"Cancel",buttonclick_fsel_cancel));
  int i;
  populate_file_array();
  for (i=0;i<FSEL_YCHARS-2;i++) {
    int first_colour=current_view->file_selector_current_top&1;    // This is done in order when the list scrolls, the odd/even lines will maintain their colour
    int c=((i+first_colour)&1)+1;
    if (i==current_view->file_selector_cursor_position) {
      c=3;
    }
    zui_add_child(form,zui_text_ext(0,i+1,file_selector_list[i],c,0));
  }
  return form;
}

static void setup_item_selector(int selector_view) {
  current_view=&file_selector_state[selector_view];
  if (current_view->selected_file) {
    char *p=&current_view->selected_file[strlen(current_view->selected_file)];
    while (p[-1]!='/'&&p!=current_view->selected_file) p--;
    int path_size=p-current_view->selected_file;
    char path[PATH_MAX];
    memcpy(path, current_view->selected_file, path_size);
    path[path_size]=0;
    // TODO: Initially read_directory() was modified to have a return value. That value in turn depended on the return value of
    //       glob() call. For some reason, when storing the glob return value (instead of ignoring it as it is currently)
    //       some paths return GLOB_NOMATCH (even though the pathname exists and you can 'ls' it) and corrupt-o-rama starts
    //       happening. There's probably a workaround for this, but for now we're going to blindly assume that things went
    //       okay inside read_directory()
    read_directory(path);
    if (1) { //if (read_directory(path)) {
      // Search the results for the filename and point the file selector cursor at it
      int l=0;
      char *i=directory_filenames[0];
      while (i) {
        if (strcmp(i, p)==0) {
          // TODO: check if this works when the directory listing is smaller than the file selector visible lines
          current_view->file_selector_current_top=l;
          current_view->file_selector_cursor_position=0;
          break;
        }
        l++;
        i=directory_filenames[l];
      }
      strcpy(current_view->current_directory,path);
      return;
    } else {
      globfree(&glob_info);
    }
  }
  read_directory(current_view->current_directory);
}

static int buttonclick_insert_floppy_a(ZuiWidget* obj) {
  view=FILE_SELECTOR_DISK_A;
  setup_item_selector(FILE_SELECTOR_DISK_A);
  return 2;
}

static int buttonclick_insert_floppy_b(ZuiWidget* obj) {
  view=FILE_SELECTOR_DISK_B;
  setup_item_selector(FILE_SELECTOR_DISK_B);
  return 3;
}

static int buttonclick_select_tos(ZuiWidget* obj) {
  view=FILE_SELECTOR_TOS_IMAGE;
  setup_item_selector(FILE_SELECTOR_TOS_IMAGE);
  return 4;
}

static int buttonclick_change_ram_size(ZuiWidget* obj) {
  return 0;
}

static int buttonclick_exit_menu(ZuiWidget* obj) {
  return 1;
}

static int buttonclick_ws1(ZuiWidget* obj) {
  cfg=(cfg& 0xfffffcff) | CFG_WS1;
  buttonclick_cold_reset(obj);
  return 1;
}

static int buttonclick_ws2(ZuiWidget* obj) {
  cfg=(cfg& 0xfffffcff) | CFG_WS2;
  buttonclick_cold_reset(obj);
  return 1;
}

static int buttonclick_ws3(ZuiWidget* obj) {
  cfg=(cfg& 0xfffffccf) | CFG_WS3;
  buttonclick_cold_reset(obj);
  return 1;
}

static int buttonclick_ws4(ZuiWidget* obj) {
  cfg=(cfg& 0xfffffcff) | CFG_WS4;
  buttonclick_cold_reset(obj);
  return 1;
}

ZuiWidget * menu_form(void) {
  ZuiWidget * form=zui_panel(0,0,XCHARS,YCHARS);
  zui_add_child(form,zui_text(0,0,"~=[,,_,,]:3 ~=[,,_,,]:3 ~=[,,_,,]:3 ~=[,,_,,]:3  ~=[,,_,,]:3"));
  zui_add_child(form,zui_button(1,1,"Warm reset",buttonclick_warm_reset));
  zui_add_child(form,zui_button(1,2,"Cold reset",buttonclick_cold_reset));
  zui_add_child(form,zui_button(1,3,"Disk A",buttonclick_insert_floppy_a));
  zui_add_child(form,zui_button(1,4,"Disk B",buttonclick_insert_floppy_b));
  zui_add_child(form,zui_button(1,5,"Select TOS image",buttonclick_select_tos));
  zui_add_child(form,zui_button(1,6,"Eject A",buttonclick_eject_floppy_a));
  zui_add_child(form,zui_button(1,7,"Eject B",buttonclick_eject_floppy_b));
  zui_add_child(form,zui_button(1,8,"RAM size",buttonclick_change_ram_size));
  int ws=cfg&0x300;
  int bg[4]={ 1, 1, 1, 1 };
  if (ws==CFG_WS1) bg[0]=3;
  if (ws==CFG_WS2) bg[1]=3;
  if (ws==CFG_WS3) bg[2]=3;
  if (ws==CFG_WS4) bg[3]=3;
  zui_add_child(form,zui_button_ext(1,9,"WS1",buttonclick_ws1,0,bg[0],2,3));
  zui_add_child(form,zui_button_ext(5,9,"WS2",buttonclick_ws2,0,bg[1],2,3));
  zui_add_child(form,zui_button_ext(9,9,"WS3",buttonclick_ws3,0,bg[2],2,3));
  zui_add_child(form,zui_button_ext(13,9,"WS4",buttonclick_ws4,0,bg[3],2,3));
  zui_add_child(form,zui_button(1,10,"Exit menu",buttonclick_exit_menu));
  return form;
}

const uint8_t osd_palette[3][12]={
  {
    0x40,0x40,0x40,
    0xc0,0xc0,0xc0,
    0xff,0xff,0x80,
    0x40,0x40,0xff
  },
  {
    6, 40, 38,
    176-20, 224-20, 230-20,
    (176-20) / 2, (224-20) / 2, (230-20) / 2,
    0, 184, 128
  },
  {
    255, 255, 255,
    0, 0, 0,
    127, 127, 127,
    255, 0, 0
  },
};

void menu(void) {
  static const uint8_t colour1[8*3]={
    253,0,0,
    253,0,0,
    253,151,0,
    253,253,0,
    47,253,0,
    0,152,253,
    102,51,254,
    102,51,254
  };
  uint8_t osd_palette0[8][12];

  osd_init();
  osd_set_palette_all(osd_palette[0]);
  int i;
  for (i=0;i<8;++i) {
    memcpy(osd_palette0[i],osd_palette[0],12);
    memcpy(&osd_palette0[i][3],&colour1[i*3],3);
  }
  osd_set_palette(0,8,osd_palette0);

  ZuiWidget *form=menu_form();

  int retval=zui_run(XPOS,YPOS,form);

  zui_free(form);

  if (retval>=2&&retval<=4) {
    // The 'Insert floppy A/floppy B/TOS' button has been pushed
    ZuiWidget *form=menu_file_selector();
    osd_set_palette_all(osd_palette[1]);
    zui_run(FSEL_XPOS,FSEL_YPOS,form);
    zui_free(form);
  }
}
