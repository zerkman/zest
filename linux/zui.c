/*
 * zui.c - zeST user interface
 *
 * Copyright (c) 2022 Francois Galea <fgalea at free.fr>
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
#include <linux/input-event-codes.h>

#include "zui.h"
#include "osd.h"

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
  const char *text;
} ZuiText;

typedef struct {
  ZuiWidget widget;
  const char *text;
  void (*onclick)(ZuiWidget *);
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

ZuiWidget * zui_text(int x, int y, const char *text) {
  ZuiText * obj = calloc(1,sizeof(ZuiText));
  obj->widget.type = ZUI_TEXT;
  obj->widget.visible = 1;
  obj->widget.x = x;
  obj->widget.y = y;
  obj->text = text;

  return (ZuiWidget*)obj;
}

ZuiWidget * zui_button(int x, int y, const char *text, void (*onclick)(ZuiWidget*)) {
  ZuiButton * obj = calloc(1,sizeof(ZuiButton));
  obj->widget.type = ZUI_BUTTON;
  obj->widget.visible = 1;
  obj->widget.focusable = 1;
  obj->widget.clickable = 1;
  obj->widget.x = x;
  obj->widget.y = y;
  obj->text = text;
  obj->onclick = onclick;

  return (ZuiWidget*)obj;
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

static void display_text(ZuiText *obj) {
  osd_text(obj->text,obj->widget.x,obj->widget.y,1,0);
}

static void display_button(ZuiButton *obj) {
  int fg = 0;
  int bg = 1;
  if (obj->widget.has_focus) bg = 2;
  if (obj->widget.enabled) bg = 3;
  osd_text(obj->text,obj->widget.x,obj->widget.y,fg,bg);
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

void select_focused(int sel) {
  if (!focused) return;
  focused->enabled = sel;
  if (focused->type==ZUI_BUTTON) {
    ZuiButton *butt = (ZuiButton*)focused;
    if (sel==0 && butt->onclick) {
      butt->onclick(focused);
    }
  }
}

// From ikbd.c
int input_event(int timeout, int *type, int *code, int *value);

extern volatile int thr_end;


void zui_run(int xpos, int ypos, ZuiWidget *obj) {
  static const uint8_t osd_palette[] = {
    0x40,0x40,0x40,
    0xc0,0xc0,0xc0,
    0xff,0xff,0x80,
    0x40,0x40,0xff
  };
  int quit = 0;

  osd_init();
  if (obj->type!=ZUI_PANEL) {
    printf("Root object is not a panel\n");
    return;
  }
  ZuiPanel *panel = (ZuiPanel*)obj;
  osd_set_size(panel->width,panel->height);
  osd_set_position(xpos,ypos);
  osd_set_palette_all(osd_palette);
  display(obj);
  osd_show(1);
  int shift = 0;
  focused = NULL;

  while (quit == 0 && thr_end == 0) {
    int evtype, evcode, evvalue;
    int retval = input_event(100,&evtype,&evcode,&evvalue);
    if (retval < 0) {
      // an error occurred
      break;
    }
    if (retval > 0 && evtype == EV_KEY) {
      // keyboard event, key is pressed
      if (evvalue == 1) {
        // key is pressed
        switch (evcode) {
          case KEY_ESC:
            quit = 1;
            break;
          case KEY_TAB:
            cycle_focus(obj,shift);
            break;
          case KEY_ENTER:
            select_focused(1);
            break;
          case KEY_LEFTSHIFT:
            shift |= 1;
            break;
          case KEY_RIGHTSHIFT:
            shift |= 2;
            break;
          default:
            break;
        }
      }
      else if (evvalue == 0) {
        // key is released
        switch (evcode) {
          case KEY_ENTER:
            select_focused(0);
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

}
