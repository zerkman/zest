/*
 * input.c - input event management
 *
 * Copyright (c) 2022-2024 Francois Galea <fgalea at free.fr>
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

#define _GNU_SOURCE    // versionsort
#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <poll.h>
#include <sys/inotify.h>
#include <sys/ioctl.h>

#include <linux/input.h>
#include <linux/input-event-codes.h>

#include "input.h"

#define BFELTBITS (sizeof(unsigned long)*8)
#define BFSIZE(nbits) ((nbits+BFELTBITS-1)/BFELTBITS)
#define BFTEST(bf,x) (bf[x/BFELTBITS]>>(x%BFELTBITS)&1)

// device identifier
struct _dev_info {
  // name
  char *name;
  // joystick id (-1 if no joystick)
  int joyid;
  // joystick X axis - Y is joy_axis+1
  int joy_axis;
} dev_info[256];

static struct pollfd pfd[256];
static int nfds = 0;
static int njs = 0;
static int fd_i = 0;
static struct input_event ie[256];
static int ie_count = 0;
static int ie_i = 0;
static int inotify_fd;

static void add_device(const char *name) {
  unsigned long evtypes[BFSIZE(EV_CNT)];
  unsigned long cap[EV_CNT][BFSIZE(KEY_CNT)];
  char buf[256];
  int fd;
  int evtype,evcode;
  sprintf(buf,"/dev/input/%s",name);
  fd = open(buf,O_RDONLY);
  pfd[nfds].fd = fd;
  pfd[nfds].events = POLLIN;
  dev_info[nfds].name = strdup(name);
  dev_info[nfds].joyid = -1;
  // scan device capabilities
  memset(evtypes,0,sizeof(evtypes));
  memset(cap,0,sizeof(cap));
  ioctl(fd,EVIOCGBIT(0,EV_CNT),evtypes);
  for (evtype=1; evtype<EV_CNT; ++evtype) {
    if (BFTEST(evtypes,evtype)) {
      // scan possible codes
      ioctl(fd,EVIOCGBIT(evtype,KEY_CNT),cap[evtype]);
    }
  }
  // if device supports EV_ABS, and it has a button, test if it has joystick capabilities
  if (BFTEST(evtypes,EV_ABS) && BFTEST(cap[EV_KEY],BTN_GAMEPAD)) {
    int axis = -1;
    for (evcode=0;evcode<KEY_CNT;++evcode) {
      if (BFTEST(cap[EV_ABS],evcode)) {
        int abs[6] = {0};
        // If we find two consecutive axes with minval=-1 and maxval=1
        // then it's a joystick
        ioctl(fd,EVIOCGABS(evcode),abs);
        if (abs[1]==-1 && abs[2]==1) {
          if (axis!=-1) {
            // joystick found
            dev_info[nfds].joyid = njs++;
            dev_info[nfds].joy_axis = axis;
            break;
          }
          axis = evcode;
        } else {
          axis = -1;
        }
      }
    }

  }
  ++nfds;
}

static void rm_device(const char *name) {
  if (strncmp(name,"event",5)==0) {
    int i;
    int joyid = -1;
    for (i=0;i<nfds;++i) {
      if (strcmp(dev_info[i].name,name)==0) {
        joyid = dev_info[i].joyid;
        close(pfd[i].fd);
        free(dev_info[i].name);
        pfd[i] = pfd[nfds-1];
        dev_info[i] = dev_info[nfds-1];
        --nfds;
        break;
      }
    }
    if (joyid>=0) {
      for (i=0;i<nfds;++i) {
        if (dev_info[i].joyid>joyid) --dev_info[i].joyid;
      }
      --njs;
    }
  }
}

static int is_event(const struct dirent *e) {
  return strncmp(e->d_name,"event",5)==0;
}

void input_init(void) {
  struct dirent **namelist;
  int i;

  int ndev = scandir("/dev/input",&namelist,is_event,versionsort);
  if (ndev<=0) return;

  nfds = 0;

  for (i=0; i<ndev; ++i) {
    add_device(namelist[i]->d_name);
    free(namelist[i]);
  }
  free(namelist);

  inotify_fd = inotify_init1(IN_NONBLOCK);
  inotify_add_watch(inotify_fd,"/dev/input",IN_CREATE|IN_DELETE);
}

int input_event(int timeout, int *type, int *code, int *value, int *joyid) {
  char inbuf[sizeof(struct inotify_event)+NAME_MAX+1];
  if (ie_i < ie_count) {
    const struct _dev_info *devinfo = &dev_info[fd_i-1];
    *type = ie[ie_i].type;
    *code = ie[ie_i].code;
    *value = (int)ie[ie_i].value;
    if (joyid) *joyid = devinfo->joyid;
    ++ie_i;
    if (*type==EV_ABS && devinfo->joyid>=0) {
      // special treatment for identified joysticks
      if (*code<devinfo->joy_axis || *code>devinfo->joy_axis+1) {
        // ignore EV_ABS events from other axes
        return input_event(timeout,type,code,value,joyid);
      }
      // remap the axis to ABS_X and ABS_Y
      *code = *code-devinfo->joy_axis+ABS_X;
    };
    return 1;
  }
  for (; fd_i<nfds; ++fd_i) {
    if ((pfd[fd_i].revents&POLLIN) != 0) {
      ssize_t sz = read(pfd[fd_i].fd,ie,sizeof(ie));
      ie_count = sz/sizeof(struct input_event);
      ie_i = 0;
      ++fd_i;
      return input_event(timeout,type,code,value,joyid);
    }
  }
  // All poll events have been processed. We may now scan for new and removed
  // devices and modify the poll list if necessary.
  int in_size = read(inotify_fd,inbuf,sizeof(inbuf));
  while (in_size>0) {
    struct inotify_event *ine = (struct inotify_event *)&inbuf;
    if (ine->mask&IN_DELETE) {
      // a device file has been removed
      rm_device(ine->name);
    }
    if (ine->mask&IN_CREATE) {
      // a device file has been created
      add_device(ine->name);
    }
    int size = (ine->name+ine->len)-(char*)ine;
    in_size -= size;
    if (in_size>0) {
      memmove(inbuf,inbuf+size,in_size);
    }
    in_size += read(inotify_fd,inbuf+in_size,sizeof(inbuf)-in_size);
  }
  // Poll for new input events
  int retval = poll(pfd,nfds,timeout);
  if (retval == -1) {
    return -1;
  } else if (retval>0) {
    fd_i = 0;
    return input_event(timeout,type,code,value,joyid);
  }
  // timeout occurred
  return 0;
}
