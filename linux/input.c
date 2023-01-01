/*
 * input.c - input event management
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

#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <poll.h>
#include <sys/inotify.h>

#include "input.h"

struct input_event {
  struct timeval time;
  unsigned short type;
  unsigned short code;
  unsigned int value;
};

static char *devname[256];
static struct pollfd pfd[256];
static int nfds = 0;
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
    devname[nfds] = strdup(name);
    ++nfds;
  }
}

static void rm_device(const char *name) {
  if (strncmp(name,"event",5)==0) {
    int i;
    for (i=0;i<nfds;++i) {
      if (strcmp(devname[i],name)==0) {
        close(pfd[i].fd);
        free(devname[i]);
        pfd[i] = pfd[nfds-1];
        devname[i] = devname[nfds-1];
        --nfds;
        break;
      }
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

int input_event(int timeout, int *type, int *code, int *value) {
  char inbuf[sizeof(struct inotify_event)+NAME_MAX+1];
  if (ie_i < ie_count) {
    *type = ie[ie_i].type;
    *code = ie[ie_i].code;
    *value = (int)ie[ie_i].value;
    ++ie_i;
    return 1;
  }
  for (; fd_i<nfds; ++fd_i) {
    if ((pfd[fd_i].revents&POLLIN) != 0) {
      ssize_t sz = read(pfd[fd_i].fd,ie,sizeof(ie));
      ie_count = sz/sizeof(struct input_event);
      ie_i = 0;
      ++fd_i;
      return input_event(timeout,type,code,value);
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
    return input_event(timeout,type,code,value);
  }
  // timeout occurred
  return 0;
}
