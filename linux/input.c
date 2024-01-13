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

#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <poll.h>
#include <sys/inotify.h>

#include <linux/input-event-codes.h>

#include "input.h"

struct input_event {
  struct timeval time;
  unsigned short type;
  unsigned short code;
  unsigned int value;
};

// device identifier
struct _dev_info {
  char *name;          // name
  unsigned int cap;    // capabilities
  int joyid;           // joystick id (-1 if no joystick)
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
  if (strncmp(name,"event",5)==0) {
    char buf[267];
    sprintf(buf,"/dev/input/%s",name);
    pfd[nfds].fd = open(buf,O_RDONLY);
    pfd[nfds].events = POLLIN;
    dev_info[nfds].name = strdup(name);
    dev_info[nfds].cap = 0;
    dev_info[nfds].joyid = -1;
    sprintf(buf,"/sys/class/input/event%s/device/capabilities/ev",name+5);
    int fd = open(buf,O_RDONLY);
    if (fd==-1) {
      printf("error: %s is not accessible\n",buf);
    } else {
      int sz = read(fd,buf,sizeof(buf)-1);
      close(fd);
      buf[sz] = 0;
      dev_info[nfds].cap = strtoul(buf,NULL,16);
      if (dev_info[nfds].cap&1<<EV_ABS) {
        dev_info[nfds].joyid = njs++;
      }
    }
    ++nfds;
  }
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

void input_init(void) {
  struct dirent *e;
  DIR *dd = opendir("/dev/input");
  nfds = 0;

  while ((e=readdir(dd))!=NULL) {
    add_device(e->d_name);
  }
  closedir(dd);

  inotify_fd = inotify_init1(IN_NONBLOCK);
  inotify_add_watch(inotify_fd,"/dev/input",IN_CREATE|IN_DELETE);
}

int input_event(int timeout, int *type, int *code, int *value, int *joyid) {
  char inbuf[sizeof(struct inotify_event)+NAME_MAX+1];
  if (ie_i < ie_count) {
    *type = ie[ie_i].type;
    *code = ie[ie_i].code;
    *value = (int)ie[ie_i].value;
    if (joyid) *joyid = dev_info[fd_i-1].joyid;
    ++ie_i;
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
