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

#include "zui.h"
#include "osd.h"

extern volatile uint32_t *parmreg;  // From setup.c
extern int cfg;                     // From setup.c
extern void do_reset();             // From setup.c
extern int disk_image_changed;      // From floppy.c
extern void *disk_image_filename;   // From floppy.c
extern char current_directory[PATH_MAX]; // From setup.c

// Stuff that would be nice for the UI lib:
// - Changable text widgets (example: file selector text widgets that display the files)
// - Editable text widgets (example: filename entering)
// - Assign unique values to buttons so zui_run can return that (example: user clicked Ok? Cancel?)
// - Mouse cursor
// - Coloured text widgets (example: currently selected file)
// - Text effects (bold, underline)
// - When selecting an item (using Return) the button's called action to instruct zui_run() to close the panel and exit after executing
// - Set palette per form/dialogue?
// - Some callbacks when form exits with Ok or Cancel? (example: change floppy image when Ok pressed in file selector, or load different TOS image)

// General file selector TODOs:
// - Implement moving with arrows
// - Generally, keyboard control for all functions would be neat (dir up, ok, cancel)
// - Typing letters should search for a filename (maybe partial matches, i.e. not from the start of the filename?)
// - Some UI code to be enhanced:
//   - For now, we have to press ESC to exit the form. So to enter the file selector we have to press "Disk A", then press ESC :)
//   - Same for pressing Ok/Cancel
//   - File listing isn't initially coloured, and the palette isn't the desired one. That's because widgets don't accept colour as parameter, nor palette can be set up

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

ZuiWidget *lolwidget;

static int buttonclick_lol(ZuiWidget* obj) {
  printf("lol\n");
  return 0;
}

static int buttonclick_warm_reset(ZuiWidget* obj)
{
  parmreg[0]=cfg&0xfffffffe;    // Bit 0 clear=reset
  parmreg[0]=cfg|3;  // |3="end reset"
  return 0;
}

static int buttonclick_cold_reset(ZuiWidget* obj) {
  parmreg[0]=0;
  usleep(10000);
  do_reset();
  return 0;
}

// File selector state
char file_selector_list[FSEL_YCHARS-2][FSEL_XCHARS];
int file_selector_current_top=0;
int file_selector_selected_file=0;
#define MAX_FILENAME_CHARS 127
#define MAX_FILENAMES 128
char directory_filenames[MAX_FILENAMES][MAX_FILENAME_CHARS];
int total_listing_files=0;
int file_selector_cursor_position;

void update_file_listing() {
  // TODO: Setting the palette here because I have no idea how to set the
  //       palette when form initially displays (and there's a hardcoded palette there)

  static const uint8_t file_selector_palette[]={
    6,40,38,
    176-20,224-20,230-20,
    (176-20)/2,(224-20)/2,(230-20)/2,
    0,184,128
  };
  osd_set_palette_all(file_selector_palette);

  // TODO: maybe we could keep a second array with all the processed filenames?

  int i;
  int first_colour=file_selector_current_top&1;    // This is done in order when the list scrolls, the odd/even lines will maintain their colour
  for (i=0; i < FSEL_YCHARS-2; i++)
  {
    // strcpy, but also fill the rest of the horizontal characters with spaces
    int j=0;
    char *s=directory_filenames[file_selector_current_top + i];
    int len = strlen(s);
    char *d=file_selector_list[i];
    if (len > FSEL_XCHARS-1)
    {
        // Filename is too big to fit in one line, so copy as much as we can
        // from the left hand side, put a "[...]" at the middle, and then
        // copy as much as we can from the right hand side. That way
        // we can both see the start of the filename and the extension,
        // as well as stuff like "Disk X of Y"
        char *s2 = s + len-((FSEL_XCHARS-1) / 2-2);
        for (; j < (FSEL_XCHARS-1) / 2-2; j++)
        {
            *d++ = *s++;
        }
        *d++ = '[';
        *d++ = '.';
        *d++ = '.';
        *d++ = '.';
        *d++ = ']';
        j += 5;

        for (; j < (FSEL_XCHARS-1) / 1; j++)
        {
            *d++ = *s2++;
        }
        *d = 0;
    }
    else
    {
        while (*s) {
            *d++ = *s++;
            j++;
        }
        for (; j < FSEL_XCHARS-1; j++) {
            *d++ = ' ';
        }
        *d = 0;
    }
    int c=((i + first_colour) & 1) + 1;
    if (i==file_selector_cursor_position) {
      c=3;
    }
    osd_text(file_selector_list[i],0,i + 1,c,0);
  }
}

static int buttonclick_fsel_up_arrow(ZuiWidget* obj) {
  if (file_selector_cursor_position) {
    file_selector_cursor_position--;
    update_file_listing();
  } else {
    if (file_selector_current_top) {
      file_selector_current_top--;
      update_file_listing();
    }
  }
  return 0;
}

static int buttonclick_fsel_down_arrow(ZuiWidget* obj) {
  if (file_selector_cursor_position < FSEL_YCHARS-3 && (file_selector_cursor_position + file_selector_current_top-1) < total_listing_files) {
    file_selector_cursor_position++;
    update_file_listing();
  } else {
    if (file_selector_current_top + FSEL_YCHARS-2 < total_listing_files)
    {
      file_selector_current_top++;
      update_file_listing();
    }
  }
  return 0;
}

void read_directory(char *path) {
  char path_wildcard[128];
  strcpy(path_wildcard,path);
  strcat(path_wildcard,"*");

  int bytes_to_skip=strlen(path); // AKA the number of bytes to trim from the left hand side of the returned filenames, those contain the path

  char **current_glob;
  glob_t glob_info;
  int i;

  // Get directories and place them at the beginning on the list
  // (so they won't get mixed up with the actual files)
  glob(path_wildcard,GLOB_MARK | GLOB_ONLYDIR,NULL,&glob_info);
  int number_of_files=glob_info.gl_pathc;

  if (number_of_files > MAX_FILENAMES) {
    // TODO: decide what to do with large directories
    number_of_files=MAX_FILENAMES;
  }

  current_glob=glob_info.gl_pathv;
  total_listing_files=0;

  for (i=0; i < number_of_files; i++) {
    // TODO: decide on how to deal with larger filenames
    strncpy(directory_filenames[total_listing_files++],*current_glob + bytes_to_skip,MAX_FILENAME_CHARS-1);
    current_glob++;
  }

  glob(path_wildcard,GLOB_MARK,NULL,&glob_info); // GLOB_MARK=Append '/' to directories so we can filter them out too

  number_of_files += glob_info.gl_pathc;
  if (!number_of_files) {
    // TODO: Directory has no files or dirs. Could be an invalid path?
    //return;
  }

  if (number_of_files > MAX_FILENAMES) {
    // TODO: decide what to do with large directories
    //       but for now we clamp the amount of files shown to MAX_FILENAMES
    number_of_files=MAX_FILENAMES;
  }

  // Get file listing, filter for the extensions we care about and add them to the list.
  // Gave up trying to understand whether glob() supports multiple wildcards and how, so here we are
  current_glob=glob_info.gl_pathv;
  for (; i < number_of_files; i++) {
    if (total_listing_files > MAX_FILENAMES) {
      break;
    }
    if (strlen(*current_glob) > 4) {
      char extension[4];
      int k;
      for (k=0; k < 4; k++) {
        // TODO: c'mon bro,that's crap
        extension[k]=tolower(*(*current_glob + strlen(*current_glob)-3 + k));
      }

      if (strcmp(extension,"msa")==0 || strcmp(extension,".st")==0 || strcmp(extension,"mfm")==0) {
        // TODO: decide on how to deal with larger filenames
        strncpy(directory_filenames[total_listing_files++],*current_glob + bytes_to_skip,MAX_FILENAME_CHARS-1);
      }
    }
    current_glob++;
  }
  globfree(&glob_info);
}

static int buttonclick_fsel_dir_up(ZuiWidget* obj) {
  int i=strlen(current_directory);
  if (i==1) {
    // We're at /
    return 0;
  }
  char *p=current_directory + i-2;
  while (*p != '/') {
    p--;
  }
  p[1]=0;   // Just null terminate after the /, this will remove the rightmost directory name

  // Update the form
  read_directory(current_directory);
  file_selector_cursor_position=0;
  update_file_listing();
  return 0;
}

static int buttonclick_fsel_ok(ZuiWidget* obj) {
  // TODO: Since the file selector will be called by multiple sites
  //       (like disk image A, disk image B, TOS image, etc) there should
  //       probably be no logic here (unless we have a global variable that
  //       mentions the caller).
  char *selected_item=directory_filenames[file_selector_current_top + file_selector_cursor_position];
  if (selected_item[strlen(selected_item)-1]=='/') {
    // Enter directory
    // Append the selected item (AKA directory name) to the global path (it already has a trailing slash and all)
    strcat(current_directory,selected_item);
    read_directory(current_directory);
    file_selector_cursor_position=0;
    update_file_listing();
  } else {
    // TODO: for now we have to press ESC to exit the form :/
    disk_image_filename=selected_item;
    disk_image_changed=1;
  }
  return 0;
}

static int buttonclick_fsel_cancel(ZuiWidget* obj) {
  // TODO: for now we have to press ESC to exit the form :/
  return 0;
}

static int buttonclick_eject_floppy_a(ZuiWidget* obj) {
  // TODO: call save image + change disk_image_filename to empty (I guess?)
  return 0;
}

ZuiWidget * menu_file_selector(void) {
  ZuiWidget * form=zui_panel(0,0,FSEL_XCHARS,FSEL_YCHARS);
  zui_add_child(form,zui_text(0,0,"\x5         Pick a file, any file        \x7"));
  zui_add_child(form,zui_text(FSEL_XCHARS-1,FSEL_YCHARS-1,"\x6"));                                // "window resize" glyph on ST font
  zui_add_child(form,zui_button(FSEL_XCHARS-1,1,"\x1",buttonclick_fsel_up_arrow));               // up arrow glyph on ST font
  zui_add_child(form,zui_button(FSEL_XCHARS-1,FSEL_YCHARS-2,"\x2",buttonclick_fsel_down_arrow)); // down arrow on ST font
  zui_add_child(form,zui_button(1,FSEL_YCHARS-1,"Dir up",buttonclick_fsel_dir_up));
  zui_add_child(form,zui_button(10,FSEL_YCHARS-1,"Ok",buttonclick_fsel_ok));
  zui_add_child(form,zui_button(20,FSEL_YCHARS-1,"Cancel",buttonclick_fsel_cancel));
  int i;
  for (i=0; i < FSEL_YCHARS-2; i++) {
    zui_add_child(form,zui_text(0,i + 1,file_selector_list[i]));
    // TODO: if filename is bigger than displayed text, either right trim it
    //       or "eat" characters in the middle
    strncpy(file_selector_list[i],directory_filenames[file_selector_current_top + i],FSEL_XCHARS-1);
  }
  return form;
}

static int buttonclick_insert_floppy_a(ZuiWidget* obj) {
  read_directory(current_directory);

  // Reset file selector variables
  file_selector_cursor_position=0;
  return 2;
}

static int buttonclick_select_tos(ZuiWidget* obj) {
  zui_set_text(lolwidget, " NYAN ");
  return 0;
}

static int buttonclick_change_ram_size(ZuiWidget* obj) {
  zui_set_text(lolwidget, "~=[,,_,,]:3");
  return 0;
}

static int buttonclick_exit_menu(ZuiWidget* obj) {
  return 1;
}

ZuiWidget * menu_form(void) {
  ZuiWidget * form=zui_panel(0,0,XCHARS,YCHARS);
  zui_add_child(form,zui_text(0,0,"~=[,,_,,]:3 ~=[,,_,,]:3 ~=[,,_,,]:3 ~=[,,_,,]:3  ~=[,,_,,]:3"));
  //zui_add_child(form,zui_text(4,5,"This is a larger text"));
  //zui_add_child(form,zui_button(10,16,"  Ok  ",buttonclick_ok));
  //zui_add_child(form,zui_button(18,16,"Ignore",buttonclick_ignore));
  //zui_add_child(form,zui_button(26,16,"Cancel",buttonclick_cancel));
  zui_add_child(form,zui_button(1,1,"Warm reset",buttonclick_warm_reset));
  zui_add_child(form,zui_button(1,2,"Cold reset",buttonclick_cold_reset));
  zui_add_child(form,zui_button(1,3,"Disk A",buttonclick_insert_floppy_a));
  zui_add_child(form,zui_button(1,4,"Eject A",buttonclick_eject_floppy_a));
  zui_add_child(form,zui_button_ext(1,5,"TOS image",buttonclick_select_tos,1,3,2,1));
  zui_add_child(form,zui_button(1,6,"RAM size",buttonclick_change_ram_size));
  lolwidget = zui_button(1,7," LOL  ",buttonclick_lol);
  zui_add_child(form,lolwidget);
  zui_add_child(form,zui_button(1,9,"Exit menu",buttonclick_exit_menu));
  return form;
}

void menu(void) {
  static const uint8_t osd_palette[] = {
    0x40,0x40,0x40,
    0xc0,0xc0,0xc0,
    0xff,0xff,0x80,
    0x40,0x40,0xff
  };
  static const uint8_t colour1[8*3] = {
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
  osd_set_palette_all(osd_palette);
  int i;
  for (i=0; i<8; ++i) {
    memcpy(osd_palette0[i],osd_palette,12);
    memcpy(&osd_palette0[i][3],&colour1[i*3],3);
  }
  osd_set_palette(0,8,osd_palette0);

  ZuiWidget *form=menu_form();

  int retval = zui_run(XPOS,YPOS,form);

  zui_free(form);

  if (retval==2) {
    // The 'Insert floppy A' button has been pushed
    ZuiWidget *form=menu_file_selector();
    zui_run(FSEL_XPOS,FSEL_YPOS,form);
    zui_free(form);
  }
}
