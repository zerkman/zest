/*
 * menu.c - Setup menu
 *
 * Copyright (c) 2020-2023 Francois Galea <fgalea at free.fr>
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
#include "setup.h"
#include "config.h"
#include "floppy.h"

#define FILE_SELECTOR_VIEWS 3

typedef struct _file_selector_state {
  int total_listing_files;
  int file_selector_current_top;
  int file_selector_cursor_position;
  char selected_file[PATH_MAX];
  char current_directory[PATH_MAX];
} FILE_SELECTOR_STATE;

enum {
  FILE_SELECTOR_DISK_A,
  FILE_SELECTOR_DISK_B,
  FILE_SELECTOR_TOS_IMAGE
};

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
#define YCHARS 20   // XCHARS*YCHARS must not exceed 1624
#define XPOS 176
#define YPOS 116
#define FSEL_XCHARS 40
#define FSEL_YCHARS 24 // TODO: no idea why yet, but setting this value any higher some garbage appears on screen
#define FSEL_XPOS 200
#define FSEL_YPOS 40
#if (FSEL_XCHARS*FSEL_YCHARS)>1624
#error Too many characters (FSEL_XCHARS*FSEL_YCHARS)
#endif
#if (XCHARS*YCHARS)>1624
#error Too many characters (XCHARS*YCHARS)
#endif

static const int file_selector_filename_lines=FSEL_YCHARS-2;
static FILE_SELECTOR_STATE file_selector_state[FILE_SELECTOR_VIEWS];
static FILE_SELECTOR_STATE *current_view;
int view;

static int buttonclick_warm_reset(ZuiWidget* obj)
{
  warm_reset();
  return 0;
}

static int buttonclick_cold_reset(ZuiWidget* obj) {
  cold_reset();
  return 0;
}


// File selector state
char file_selector_list[FSEL_YCHARS-2][FSEL_XCHARS];
glob_t glob_info;
char *directory_filenames[1024];  // Holds pointers to filtered directory items inside the glob struct
char blank_line[FSEL_XCHARS]="                                       "; // TODO: this should idealy be resized depending on FSEL_XCHARS

void populate_file_array()
{
  int i;
  for (i=0;i<file_selector_filename_lines;i++) {
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
  for (;i<file_selector_filename_lines;i++) {
    char *d=file_selector_list[i];
    strcpy(d, blank_line);
  }
}

void update_file_listing() {
  populate_file_array();
  int i;
  for (i=0;i<file_selector_filename_lines;i++) {
    int c=1;
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
    if (current_view->file_selector_current_top+file_selector_filename_lines<current_view->total_listing_files) {
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

static void update_file_selector_when_entering_new_directory()
{
  globfree(&glob_info);
  read_directory(current_view->current_directory);
  current_view->file_selector_cursor_position=current_view->file_selector_current_top=0;
  update_file_listing();
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
  update_file_selector_when_entering_new_directory();

  return 0;
}

static int buttonclick_fsel_cancel(ZuiWidget* obj) {
  globfree(&glob_info);
  return 1;
}

static int buttonclick_fsel_ok(ZuiWidget* obj) {
  if (current_view->total_listing_files==0)
  {
    // Someone pressed Ok in an empty directory, let's cancel
    return buttonclick_fsel_cancel(obj);
  }
  char *selected_item=directory_filenames[current_view->file_selector_current_top+current_view->file_selector_cursor_position];
  if (selected_item[strlen(selected_item)-1]=='/') {
    // Enter directory
    // Append the selected item (AKA directory name) to the global path (it already has a trailing slash and all)
    strcat(current_view->current_directory,selected_item);
    update_file_selector_when_entering_new_directory();
    return 0;   // Don't exit the dialog yet
  }
  if (view==FILE_SELECTOR_DISK_A||view==FILE_SELECTOR_DISK_B) {
    int drive = view==FILE_SELECTOR_DISK_B;
    strcpy(current_view->selected_file, selected_item-strlen(current_view->current_directory));
    change_floppy(selected_item-strlen(current_view->current_directory),drive);
  } else if (view==FILE_SELECTOR_TOS_IMAGE) {
    load_rom(selected_item);
    cold_reset();
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

static int buttonclick_eject_floppy_a(ZuiWidget* obj) {
  change_floppy(NULL,0);
  return 0;
}

static int buttonclick_eject_floppy_b(ZuiWidget* obj) {
  change_floppy(NULL,1);
  return 0;
}

ZuiWidget * menu_file_selector() {
  ZuiWidget * form=zui_panel(0, 0, FSEL_XCHARS, FSEL_YCHARS);
  if (view==FILE_SELECTOR_DISK_A) {
    zui_add_child(form, zui_text(0, 0, "\x5    Select a disk image for drive A   \x7"));
  } else if (view==FILE_SELECTOR_DISK_B) {
    zui_add_child(form, zui_text(0, 0, "\x5    Select a disk image for drive B   \x7"));
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
  for (i=0;i<file_selector_filename_lines;i++) {
    int c=1;
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
    // TODO: Initially read_directory() was modified to have a return value. That value in turn depended on the return value of
    //       glob() call. For some reason, when storing the glob return value (instead of ignoring it as it is currently)
    //       some paths return GLOB_NOMATCH (even though the pathname exists and you can 'ls' it) and corrupt-o-rama starts
    //       happening. There's probably a workaround for this, but for now we're going to blindly assume that things went
    //       okay inside read_directory()
    read_directory(current_view->current_directory);
    if (1) { //if (read_directory(path)) {
      // Search the results for the filename and point the file selector cursor at it
      int l=0;
      char *i=directory_filenames[0];
      char *p=current_view->selected_file+strlen(current_view->current_directory);
      while (i) {
        if (strcmp(i, p)==0) {
          // Initially we try center the cursor position
          current_view->file_selector_current_top=l-file_selector_filename_lines/2;
          current_view->file_selector_cursor_position=file_selector_filename_lines/2;
          if (current_view->file_selector_current_top<0) {
            // Oops, our centering sent us above the top most item, so clamp
            current_view->file_selector_current_top=0;
            current_view->file_selector_cursor_position=l;
          } else if (current_view->file_selector_current_top>current_view->total_listing_files-file_selector_filename_lines) {
            // Oops, our centering sent us below the bottom most item, so clamp
            current_view->file_selector_current_top=current_view->total_listing_files-file_selector_filename_lines;
            current_view->file_selector_cursor_position=l-(current_view->total_listing_files-file_selector_filename_lines);
          } else if (current_view->total_listing_files<file_selector_filename_lines) {
            // We don't have enough files in the directory to fill the entire view, so reset everything
            current_view->file_selector_current_top=0;
            current_view->file_selector_cursor_position=l;
          }
          break;
        }
        l++;
        i=directory_filenames[l];
      }
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
  set_wakestate(1);
  return 1;
}

static int buttonclick_ws2(ZuiWidget* obj) {
  set_wakestate(2);
  return 1;
}

static int buttonclick_ws3(ZuiWidget* obj) {
  set_wakestate(3);
  return 1;
}

static int buttonclick_ws4(ZuiWidget* obj) {
  set_wakestate(4);
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
  int ws = get_wakestate();
  int bg[4]={ 1, 1, 1, 1 };
  bg[ws-1] = 3;
  zui_add_child(form,zui_button_ext(1,9,"WS1",buttonclick_ws1,0,bg[0],2,3));
  zui_add_child(form,zui_button_ext(5,9,"WS2",buttonclick_ws2,0,bg[1],2,3));
  zui_add_child(form,zui_button_ext(9,9,"WS3",buttonclick_ws3,0,bg[2],2,3));
  zui_add_child(form,zui_button_ext(13,9,"WS4",buttonclick_ws4,0,bg[3],2,3));
  zui_add_child(form,zui_button(1,10,"Exit menu",buttonclick_exit_menu));
  return form;
}

const uint8_t osd_palette[3][24]={
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

static void setup_file_selector(const char *filename, int state_id)
{
  FILE_SELECTOR_STATE *state = &file_selector_state[state_id];
  if (filename==NULL) {
    sprintf(state->current_directory,"%s/",config.flopimg_dir);
    return;
  }
  if (*filename==0) {
    return; // Already initialised at the start of main
  }
  if (*filename!='/') {
    getcwd(state->selected_file,PATH_MAX);
    strcat(state->selected_file,"/");
  }
  strcat(state->selected_file,filename);
  strcpy(state->current_directory,state->selected_file);
  char *p = &state->current_directory[strlen(state->current_directory)];
  while (p[-1]!='/'&&p!=state->current_directory) p--;
  *p=0;
}

// Menu initialization
void menu_init(void) {
  setup_file_selector(config.rom_file,FILE_SELECTOR_TOS_IMAGE);
  setup_file_selector(config.floppy_a,FILE_SELECTOR_DISK_A);
  setup_file_selector(config.floppy_b,FILE_SELECTOR_DISK_B);
}

static uint8_t gradient[MAX_SCANLINES][3];
static const uint8_t gradient1_col1[3] = { 0xB1, 0x2B, 0x7F };
static const uint8_t gradient1_col2[3] = { 0x72, 0xA1, 0xDF };
static const uint8_t gradients[12][2][3]={
  {{0x80,0xc0,0xff},{0x88,0x88,0x88}},  // Light blue->Gray
  {{0x00,0xcc,0xcc},{0x88,0x88,0x88}},  // Cyan->Gray
  {{245,177,97},  {236,54,110},  },
  {{33,103,43},   {117,162,61},  },
  {{174,68,223},  {246,135,135}, },
  {{216,27,96},   {237,107,154}, },
  {{255,166,0},   {255,99,97},   },
  {{7,121,222},   {20,72,140},   },
  {{0x32, 0x8B, 0x31}, {0x96, 0xCF, 0x24},},            //#328B31 -> #96CF24
  {{0x99, 0x45, 0xFF}, {0x19, 0xFB, 0x9B},},            //#9945FF -> #19FB9B
  {{0x06, 0xEB, 0x5B}, {0x00, 0x78, 0xE6},},            //#06EB5B -> #0078E6
  {{0xFE, 0x37, 0xAF}, {0xFE, 0x07, 0x9C},},            //#FE37AF -> #FE079C
};

//extern void osd_calculate_gradient(uint8_t col1[3], uint8_t col2[3], int steps, uint8_t *output);
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
  uint8_t osd_palette0[8][24];

  osd_init();
  osd_set_palette_all(osd_palette[0]);
  int i;
  for (i=0;i<8;++i) {
    memcpy(osd_palette0[i],osd_palette[0],24);
    memcpy(&osd_palette0[i][3],&colour1[i*3],3);
  }
  osd_set_palette(0,8,osd_palette0);

  ZuiWidget *form=menu_form();

  int retval=zui_run(XPOS,YPOS,form);

  zui_free(form);

  if (retval>=2&&retval<=4) {
    // The 'Insert floppy A/floppy B/TOS' button has been pushed
    ZuiWidget *form=menu_file_selector();
    static const uint8_t file_selector_main_cols[1][8*3]={{255,255,255, 0,0,0, 218,155,66, 192,61,10, 0,0,0, 0,0,0, 0,0,0, 0,0,0,}};
    osd_calculate_gradient(gradient1_col1,gradient1_col2,MAX_SCANLINES,(uint8_t *)gradient);

    osd_set_palette_with_one_gradient(file_selector_main_cols[0],gradient,1);

    zui_run(FSEL_XPOS,FSEL_YPOS,form);
    zui_free(form);
  }
}
