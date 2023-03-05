/*
 * floppy.c - floppy drive emulation (software part)
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

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <sys/ioctl.h>
#include <sys/mman.h>
#include <pthread.h>
#include <dirent.h>
#include <poll.h>
#include <sys/time.h>
#include <unistd.h>

#include "config.h"
#include "floppy_img.h"

extern volatile uint32_t *parmreg;
extern int parmfd;
extern volatile int thr_end;

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static Flopimg *img[2] = {NULL,NULL};

// change or eject the floppy disk
void change_floppy(const char *filename, int drive) {
  // critical section so we don't deallocate anything while accessing data
  pthread_mutex_lock(&mutex);
  if (img[drive]!=NULL) {
    flopimg_close(img[drive]);
    img[drive] = NULL;
  }
  if (filename!=NULL) {
    img[drive] = flopimg_open(filename,0,3,1);
    if (img[drive]==NULL) {
      printf("Error opening floppy image file: '%s'\n",filename);
    }
  }
  pthread_mutex_unlock(&mutex);
}

void * thread_floppy(void * arg) {
  uint32_t n,oldn=0;
  unsigned int oldaddr=2000;

  change_floppy(config.floppy_a,0);
  change_floppy(config.floppy_b,1);

  unsigned int pos=0,pos1=0,posw=0;

  struct pollfd pfd = { .fd=parmfd, .events=POLLIN };

  for(;;) {
    // unmask interrupt
    uint32_t unmask = 1;
    ssize_t rv = write(parmfd, &unmask, sizeof(unmask));
    if (rv != (ssize_t)sizeof(unmask)) {
      perror("unmask interrupt");
      break;
    }
    int status = poll(&pfd,1,5);
    if (thr_end) break;
    if (status==-1) {
      perror("UIO interrupts");
      break;
    } else if (status==0) {
      continue;
    }
    if (read(parmfd,&n,4)==0) {
      printf("nok\n");
      break;
    }

    // read host values
    uint32_t in = parmreg[0];
    unsigned int r = in>>31;
    unsigned int w = in>>30&1;
    unsigned int addr = in>>21&0x1ff;
    unsigned int track = in>>13&0xff;
    unsigned int drive = in>>12&1;
    if (oldn!=0 && n!=oldn+1) {
      printf("it=%u r=%u w=%u track=%u addr=%u\n",(unsigned)n,r,w,track,addr);
      fflush(stdout);
    }
    oldn = n;
    unsigned int newaddr = oldaddr==390?0:(oldaddr+1);
    if (oldaddr<=390 && addr!=newaddr) {
      printf("missed addr=%u\n",newaddr);
      fflush(stdout);
    }
    oldaddr = addr;

    // start a critical section so the image is not changed during access
    pthread_mutex_lock(&mutex);
    if (img[drive] && r) {
      uint8_t *trkp = flopimg_trackpos(img[drive],track>>1,track&1);

      posw = pos1;
      pos1 = pos;
      pos = addr*16+16;
      if (pos>=6250) {
        pos = 0;
      }
      uint8_t *p = trkp+pos;
      int count = pos<6240?16:10;
      memcpy((void*)&parmreg[8],p,count);

      if (w) {
        p = trkp+posw;
        int count = posw<6240?16:10;
        memcpy(p,(void*)&parmreg[8],count);

        flopimg_writeback(img[drive]);
      }
    }
    pthread_mutex_unlock(&mutex);
  }

  change_floppy(NULL,0);
  change_floppy(NULL,1);

  return NULL;
}
