/*
 * zui.c - zeST user interface
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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <linux/input-event-codes.h>

#include "zui.h"
#include "osd.h"
#include "input.h"

// widget types
#define ZUI_PANEL   1
#define ZUI_TEXT    2
#define ZUI_BUTTON  3

struct _zui_widget {
  int visible    : 1;
  int focusable  : 1;
  int has_focus  : 1;
  int clickable  : 1;
  int enabled    : 1;
  int type;
  int x;
  int y;
  struct _zui_widget *first;    // first child widget (NULL if no children)
  struct _zui_widget *next;     // next in children list (NULL if last)
  struct _zui_widget *parent;   // parent widget (NULL if root widget)
};

typedef struct {
  ZuiWidget widget;
  int width;
  int height;
} ZuiPanel;

typedef struct {
  ZuiWidget widget;
  char *text;
  int fgcol;
  int bgcol;
} ZuiText;

typedef struct {
  ZuiText text;
  int fccol;    // focused background colour
  int encol;    // enabled background colour
  int (*onclick)(ZuiWidget *);
} ZuiButton;


ZuiWidget * zui_panel(int x, int y, int width, int height) {
  ZuiPanel * obj = calloc(1,sizeof(ZuiPanel));
  if (obj==NULL) return NULL;
  obj->widget.type = ZUI_PANEL;
  obj->widget.visible = 1;
  obj->widget.x = x;
  obj->widget.y = y;
  obj->width = width;
  obj->height = height;

  return (ZuiWidget*)obj;
}

static void zui_text_init(ZuiText *obj, int x, int y, const char *text, int fgcol, int bgcol) {
  memset(obj,0,sizeof(*obj));
  obj->widget.type = ZUI_TEXT;
  obj->widget.visible = 1;
  obj->widget.x = x;
  obj->widget.y = y;
  obj->text = strdup(text);
  obj->fgcol = fgcol;
  obj->bgcol = bgcol;
}

ZuiWidget * zui_text_ext(int x, int y, const char *text, int fgcol, int bgcol) {
  ZuiText * obj = malloc(sizeof(ZuiText));
  zui_text_init(obj,x,y,text,fgcol,bgcol);
  return (ZuiWidget*)obj;
}

ZuiWidget * zui_text(int x, int y, const char *text) {
  return zui_text_ext(x,y,text,1,0);
}

static void zui_button_init(ZuiButton *obj, int x, int y, const char *text, int (*onclick)(ZuiWidget*), int fgcol, int bgcol, int fccol, int encol) {
  ZuiWidget *w = (ZuiWidget*)obj;
  zui_text_init(&obj->text,x,y,text,fgcol,bgcol);
  w->type = ZUI_BUTTON;
  w->focusable = 1;
  w->clickable = 1;
  obj->fccol = fccol;
  obj->encol = encol;
  obj->onclick = onclick;
}

ZuiWidget * zui_button_ext(int x, int y, const char *text, int (*onclick)(ZuiWidget*), int fgcol, int bgcol, int fccol, int encol) {
  ZuiButton * obj = malloc(sizeof(ZuiButton));
  zui_button_init(obj,x,y,text,onclick,fgcol,bgcol,fccol,encol);
  return (ZuiWidget*)obj;
}

ZuiWidget * zui_button(int x, int y, const char *text, int (*onclick)(ZuiWidget*)) {
  return zui_button_ext(x,y,text,onclick,0,1,2,3);
}

void zui_add_child(ZuiWidget * parent, ZuiWidget * child) {
  ZuiWidget *w = parent->first;
  if (w==NULL) {
    parent->first = child;
  } else {
    ZuiWidget *pw;
    while (w!=NULL) {
      pw = w;
      w = w->next;
    }
    pw->next = child;
  }
  child->parent = parent;
}

void zui_free(ZuiWidget * root) {
  ZuiWidget *obj = root->first;
  while (obj!=NULL) {
    ZuiWidget *next = obj->next;
    zui_free(obj);
    obj = next;
  }
  if (root->type==ZUI_TEXT || root->type==ZUI_BUTTON) {
    ZuiText *t = (ZuiText*)root;
    free(t->text);
  }
  free(root);
}

static void display_panel(ZuiPanel *obj) {
  int i,j;
  int x = obj->widget.x;
  int y = obj->widget.y;
  for (j=0; j<obj->height; ++j) {
    for (i=0; i<obj->width; ++i) {
      osd_putchar(' ',i+x,j+y,1,0);
    }
  }
}

//static void display_text(ZuiText *obj) {
void display_text(ZuiText *obj) {
  osd_text(obj->text,obj->widget.x,obj->widget.y,obj->fgcol,obj->bgcol);
}

static void display_button(ZuiButton *obj) {
  ZuiWidget *w = (ZuiWidget*)obj;
  ZuiText *t = (ZuiText*)obj;
  int fg = t->fgcol;
  int bg = t->bgcol;
  if (w->has_focus) bg = obj->fccol;
  if (w->enabled) bg = obj->encol;
  osd_text(t->text,w->x,w->y,fg,bg);
}


static void display(ZuiWidget *obj) {
  if (!obj->visible) return;
  switch (obj->type) {
    case ZUI_PANEL:  display_panel((ZuiPanel*)obj); break;
    case ZUI_TEXT:   display_text((ZuiText*)obj); break;
    case ZUI_BUTTON: display_button((ZuiButton*)obj); break;
  }
  ZuiWidget *child = obj->first;
  while (child!=NULL) {
    display(child);
    child = child->next;
  }
}

void zui_set_text(ZuiWidget *obj, const char *text) {
  if (obj->type==ZUI_TEXT || obj->type==ZUI_BUTTON) {
    ZuiText *t = (ZuiText*)obj;
    osd_text(t->text,obj->x,obj->y,0,0);
    free(t->text);
    t->text = strdup(text);
    display(obj);
  }
}

// static void debug_disp(ZuiWidget *obj) {
//   printf("Object type:");
//   switch (obj->type) {
//     case ZUI_PANEL:  printf("ZUI_PANEL"); break;
//     case ZUI_TEXT:   printf("ZUI_TEXT text=%s", ((ZuiText*)obj)->text); break;
//     case ZUI_BUTTON: printf("ZUI_BUTTON text=%s", ((ZuiButton*)obj)->text); break;
//   }
//   printf("\n");
// }

ZuiWidget *focused = NULL;

// Return next widget in depth first spanning order
ZuiWidget *next_widget(ZuiWidget *w) {
  if (w->first) return w->first;
  if (w->next) return w->next;
  do {
    w = w->parent;
  } while (w && !w->next);
  if (w) return w->next;
  return NULL;
}

// Return next focusable widget, cycle the hyerarchy at the end
// Return NULL if no widget is focusable
ZuiWidget *next_focusable(ZuiWidget *root, ZuiWidget *obj) {
  if (obj==NULL) obj = root;
  ZuiWidget *w = obj;
  int loop = 0;
  do {
    w = next_widget(w);
    if (!w && !loop) {
      w = root;
      loop = 1;
    }
  } while (w && !w->focusable);
  return w;
}

// Return previous focusable widget, cycle the hyerarchy at the beginning
// Return NULL if no widget is focusable
ZuiWidget *prev_focusable(ZuiWidget *root, ZuiWidget *obj) {
  if (obj==NULL) obj = root;
  ZuiWidget *prev = NULL;
  ZuiWidget *w = NULL;

  while (w!=obj || !prev) {
    prev = w;
    w = next_focusable(root,w);
  }
  return prev;
}

// Cycle the focus to the next widget
// if direction==0: search forward, otherwise backward
void cycle_focus(ZuiWidget *root, int direction) {
  ZuiWidget *next = direction ? prev_focusable(root,focused) : next_focusable(root,focused);

  if (next!=focused) {
    if (focused) {
      focused->has_focus = 0;
      display(focused);
    }
    focused = next;
    focused->has_focus = 1;
    display(focused);
  }
}

int select_focused(int sel) {
  if (!focused) return 0;
  focused->enabled = sel;
  if (focused->type==ZUI_BUTTON) {
    ZuiButton *butt = (ZuiButton*)focused;
    if (sel==0 && butt->onclick) {
      return butt->onclick(focused);
    }
  }
  return 0;
}

extern volatile int thr_end;
extern uint8_t osd_palette[3][24];
extern volatile uint32_t *parmreg;
extern int _xchars;
extern int _ychars;

int zui_run(int xpos, int ypos, ZuiWidget *obj) {
  int quit = 0;

  osd_init();
  if (obj->type!=ZUI_PANEL) {
    printf("Root object is not a panel\n");
    return -1;
  }
  ZuiPanel *panel = (ZuiPanel*)obj;
  osd_set_size(panel->width,panel->height);
  osd_set_position(xpos,ypos);
  display(obj);
  osd_show(1);
  int shift = 0;
  focused = next_focusable(obj,NULL);
  if (focused) {
    focused->has_focus=1;
    display(focused);
  }

  while (quit == 0 && thr_end == 0) {
    int evtype, evcode, evvalue;
    int retval = input_event(100,&evtype,&evcode,&evvalue);
    if (retval < 0) {
      // an error occurred
      break;
    }

    // TODO: - This is copypasta from thread_floppy()
    //       - This will have "interesting" effects if _xchars is less than 10
    //       - Make this into a special OSD menu in some corner of the screen so it will be always visible?
    uint32_t in = parmreg[0];
    unsigned int r = in>>31;
    unsigned int w = in>>30&1;
    unsigned int track = in>>13&0xff;
    char floppy_osd_info[10];
    if (r) {
      sprintf(floppy_osd_info,"R T%02d S%d", track>> 1, track&1);
      osd_text(floppy_osd_info, _xchars-10, _ychars-1, 3, 0);
    }
    if (w) {
      sprintf(floppy_osd_info,"W T%02d S%d", track>> 1, track&1);
      osd_text(floppy_osd_info, _xchars-10, _ychars-1, 3, 0);
    }

    if (retval > 0 && evtype == EV_KEY) {
      // keyboard event, key is pressed
      if (evvalue == 1) {
        // key is pressed
        switch (evcode) {
          case KEY_ESC:
            quit = 1;
            break;
          case KEY_UP:
            cycle_focus(obj,1);
            break;
          case KEY_DOWN:
            cycle_focus(obj,0);
            break;
          case KEY_TAB:
            cycle_focus(obj,shift);
            break;
          case KEY_ENTER:
            select_focused(1);
            //quit = 1;
            break;
          case KEY_LEFTSHIFT:
            shift |= 1;
            break;
          case KEY_RIGHTSHIFT:
            shift |= 2;
            break;
          case KEY_1:
            osd_set_palette_all(osd_palette[0]);
            break;
          case KEY_2:
            osd_set_palette_all(osd_palette[1]);
            break;
          case KEY_3:
            osd_set_palette_all(osd_palette[2]);
            break;
          default:
            break;
        }
      }
      else if (evvalue == 0) {
        // key is released
        switch (evcode) {
          case KEY_ENTER:
            quit = select_focused(0);
            break;
          case KEY_LEFTSHIFT:
            shift &= ~1;
            break;
          case KEY_RIGHTSHIFT:
            shift &= ~2;
            break;
        }
      }
    }
  }

  osd_hide();
  return quit;
}
