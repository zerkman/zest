/*
 * ikbd.c - intelligent keyboard emulation (software part)
 *
 * Copyright (c) 2020-2024 Francois Galea <fgalea at free.fr>
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
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

#include <linux/input-event-codes.h>

#include "config.h"
#include "input.h"
#include "menu.h"
#include "infomsg.h"

#define JOY_EMU_LED_FILE "/sys/class/leds/led1/brightness"

extern volatile uint32_t *parmreg;

extern volatile int thr_end;


static void led_status(int fd,int st) {
  if (fd>=0) {
    char val = st?'1':'0';
    write(fd,&val,1);
  }
}

static int joy_emu = 0;
static int joyemufd = 0;

static void set_joy_emu(int v) {
  joy_emu = v;
  led_status(joyemufd,v);
}

void * thread_ikbd(void * arg) {
  unsigned int mx=0,my=0;
  int dx=0,dy=0,ox=0,oy=0;
  int timeout = 100;
  int tp_x=-1,tp_y=-1;

  int meta = 0;
  joyemufd = open(JOY_EMU_LED_FILE,O_WRONLY|O_SYNC);

  input_init();

  while (thr_end == 0) {
    int evtype, evcode, evvalue, joyid;
    int retval = input_event(timeout,&evtype,&evcode,&evvalue,&joyid);
    if (retval < 0) {
      // an error occurred
      break;
    }

    else if (retval > 0) {
      // an event has been received
      int key;
      switch (evtype) {
        case EV_REL:
          if (evcode == 0) {
            dx -= evvalue;
          } else {
            dy -= evvalue;
          }
          timeout = 0;
          break;
        case EV_KEY:
          if (evcode==KEY_LEFTMETA || evcode==KEY_RIGHTMETA) {
            meta = evvalue;
            break;
          }
          if (meta) {
            // Meta toggles that do not trigger actual keypresses
            switch (evcode) {
              case KEY_J:
                if (evvalue == 1) {
                  set_joy_emu(!joy_emu);
                }
                break;
              case KEY_ENTER:
                if (evvalue == 0) {
                  meta = 0;
                  menu();
                }
                break;
            }
            break;
          }
          key = -1;
          switch (evcode) {
            case KEY_F1:
            case KEY_F2:
            case KEY_F3:
            case KEY_F4:
            case KEY_F5:
            case KEY_F6:
            case KEY_F7:
            case KEY_F8:
            case KEY_F9:
            case KEY_F10: key = evcode-KEY_F1; break;
            case KEY_F11: key = 10; break;    // help
            case KEY_F12: key = 11; break;    // undo
            // key 12 - numeric pad [(] not mapped
            case KEY_KPSLASH: key = 13; break;
            case KEY_ESC: key = 14; break;
            case KEY_2: key = 15; break;
            case KEY_4: key = 16; break;
            case KEY_6: key = 17; break;
            case KEY_8: key = 18; break;
            case KEY_0: key = 19; break;
            case KEY_EQUAL: key = 20; break;
            case KEY_BACKSPACE: key = 21; break;
            case KEY_UP: key = joy_emu?123:22; break;
            // key 23 - numeric pad [)] not mapped
            case KEY_KPASTERISK: key = 24; break;
            case KEY_1: key = 25; break;
            case KEY_3: key = 26; break;
            case KEY_5: key = 27; break;
            case KEY_7: key = 28; break;
            case KEY_9: key = 29; break;
            case KEY_MINUS: key = 30; break;
            case KEY_GRAVE: key = 31; break;
            case KEY_DELETE: key = meta?43:32; break;
            case KEY_HOME: key = 33; break;
            case KEY_KP7: key = 34; break;
            case KEY_KP9: key = 35; break;
            case KEY_TAB: key = 36; break;
            case KEY_W: key = 37; break;
            case KEY_R: key = 38; break;
            case KEY_Y: key = 39; break;
            case KEY_U: key = 40; break;
            case KEY_O: key = 41; break;
            case KEY_LEFTBRACE: key = 42; break;
            case KEY_INSERT: key = 43; break;
            case KEY_LEFT: key = joy_emu?125:44; break;
            case KEY_KP8: key = 45; break;
            case KEY_KPMINUS: key = 46; break;
            case KEY_LEFTCTRL:
            case KEY_RIGHTCTRL: key = 47; break;
            case KEY_Q: key = 48; break;
            case KEY_E: key = 49; break;
            case KEY_T: key = 50; break;
            case KEY_G: key = 51; break;
            case KEY_I: key = 52; break;
            case KEY_P: key = 53; break;
            case KEY_RIGHTBRACE: key = 54; break;
            case KEY_BACKSLASH: key = 55; break;
            case KEY_DOWN: key = joy_emu?124:56; break;
            case KEY_KP4: key = 57; break;
            case KEY_KP6: key = 58; break;
            case KEY_LEFTSHIFT: key = joy_emu?127:59; break;
            case KEY_A: key = 60; break;
            case KEY_S: key = 61; break;
            case KEY_F: key = 62; break;
            case KEY_H: key = 63; break;
            case KEY_J: key = 64; break;
            case KEY_L: key = 65; break;
            case KEY_SEMICOLON: key = 66; break;
            case KEY_ENTER: key = 67; break;
            case KEY_RIGHT: key = joy_emu?126:68; break;
            case KEY_KP5: key = 69; break;
            case KEY_KPPLUS: key = 70; break;
            case KEY_LEFTALT: key = 71; break;
            case KEY_102ND: key = 72; break;
            case KEY_D: key = 73; break;
            case KEY_C: key = 74; break;
            case KEY_B: key = 75; break;
            case KEY_K: key = 76; break;
            case KEY_COMMA: key = 77; break;
            case KEY_DOT: key = 78; break;
            case KEY_APOSTROPHE: key = 79; break;
            case KEY_KP1: key = 80; break;
            case KEY_KP2: key = 81; break;
            case KEY_KP3: key = 82; break;
            case KEY_RIGHTSHIFT: key = 83; break;
            case KEY_Z: key = 84; break;
            case KEY_X: key = 85; break;
            case KEY_V: key = 86; break;
            case KEY_N: key = 87; break;
            case KEY_M: key = 88; break;
            case KEY_SPACE: key = 89; break;
            case KEY_CAPSLOCK: key = 90; break;
            case KEY_SLASH: key = 91; break;
            case KEY_KP0: key = 92; break;
            case KEY_KPDOT: key = 93; break;
            case KEY_KPENTER: key = 94; break;
            case KEY_RIGHTALT: key = config.right_alt_is_altgr?95:71; break;
            case BTN_LEFT: key = 122; break;
            case BTN_NORTH: key = 122; break;
            case BTN_RIGHT: key = 127; break;
            case BTN_GAMEPAD:
              if (joyid==0) key = 127;
              if (joyid==1) key = 122;
              break;
            case KEY_NUMLOCK:
              if (evvalue == 1) {
                set_joy_emu(!joy_emu);
              }
              break;
            case KEY_PAGEUP:
            case KEY_SCROLLLOCK:
            case BTN_START:
              menu();
              break;
            case KEY_MUTE:
              if (evvalue) vol_mute();
              break;
            case KEY_VOLUMEDOWN:
              if (evvalue) vol_down();
              break;
            case KEY_VOLUMEUP:
              if (evvalue) vol_up();
              break;
            case BTN_TOUCH:
              // finger removed from touch pad: stop coordinate tracking
              if (evvalue==0) tp_x = tp_y = -1;
              break;
            // default:
            //   printf("Key code:%d val:%d\n",evcode,evvalue);
          }
          // printf("Key code:%#x joyid:%d key:%d val:%d\n",evcode,joyid,key,evvalue);
          if (key!=-1) {
            parmreg[4+key/32] = (parmreg[4+key/32] & ~(1<<key%32)) | (!evvalue)<<(key%32);
          }
          break;
        case EV_ABS:
          // absolute direction event

          // touch pad event
          if (evcode==ABS_MT_POSITION_X||evcode==ABS_MT_POSITION_Y) {
            if (evcode==ABS_MT_POSITION_X) {
              if (tp_x!=-1) dx += tp_x-evvalue;
              tp_x = evvalue;
            }
            if (evcode==ABS_MT_POSITION_Y) {
              if (tp_y!=-1) dy += tp_y-evvalue;
              tp_y = evvalue;
            }
            timeout = 0;
          }

          // consider only the first two joysticks
          if (joyid>=0 && joyid<2) {
            unsigned int val = 3;
            key = -1;
            // game controller events
            if (evcode==ABS_X||evcode==ABS_Y) {
              if (evvalue==-1) val = 2;
              if (evvalue==1) val = 1;
              if (evcode==ABS_X) key = 125;  // left/right axis
              if (evcode==ABS_Y) key = 123;  // up/down axis
            }
            if (key!=-1) {
              if (joyid==1) {
                // second joystick goes to the mouse port
                key -= 5;
              }
              // printf("evcode:%d joyid:%d key:%d val:%d\n",evcode,joyid,key,evvalue);
              parmreg[4+key/32] = (parmreg[4+key/32] & ~(3<<key%32)) | val<<(key%32);
            }
          }
          break;
      }
    }

    else {
      // a timeout occurred
      timeout = 100;

      // Decompose mouse events (dx,dy) into a series of 2-bit Gray code pairs.
      // Those Gray codes must ideally be sent at about the frequency at which the
      // HD6301 keyboard processor reads its mouse input pins.
      // This frequency is typically much higher than the frequency of USB mouse
      // events.
      int mx0 = mx;
      int my0 = my;
      if (dx>=2) {
        if (ox==1 && dx>=4) {
          mx = (mx+2)&3;
          dx -= 4;
        }
        else {
          mx = (mx+1)&3;
          dx -= 2;
          ox = 1;
        }
        timeout = 1;
      }
      if (dx<=-2) {
        if (ox==-1 && dx<=-4) {
          mx = (mx+2)&3;
          dx += 4;
        }
        else {
          mx = (mx+3)&3;
          dx += 2;
          ox = -1;
        }
        timeout = 1;
      }
      if (dy>=2) {
        if (oy==1 && dy>=4) {
          my = (my+2)&3;
          dy -= 4;
        }
        else {
          my = (my+1)&3;
          dy -= 2;
          oy = 1;
        }
        timeout = 1;
      }
      if (dy<=-2) {
        if (oy==-1 && dy<=-4) {
          my = (my+2)&3;
          dy += 4;
        }
        else {
          my = (my+3)&3;
          dy += 2;
          oy = -1;
        }
        timeout = 1;
      }
      if (mx!=mx0 || my!=my0) {
        int x = (mx>>1)^mx;
        int y = (my>>1)^my;
        parmreg[7] = (parmreg[7] & 0xfc3fffff) | x<<22 | y<<24;
      }
    }
  }

  if (joyemufd!=-1) close(joyemufd);

  return NULL;
}
