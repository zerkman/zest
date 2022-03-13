/*
 * floppy.c - floppy drive emulation (software part)
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

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <pthread.h>
#include <dirent.h>
#include <poll.h>
#include <sys/time.h>

extern volatile uint32_t *parmreg;
extern int parmfd;
extern volatile int thr_end;

#define MAXTRACK 84

static const uint8_t * findam(const uint8_t *p, const uint8_t *buf_end) {
  static const uint8_t head[] = {0,0,0,0,0,0,0,0,0,0,0,0,0xa1,0xa1,0xa1};
  buf_end -= sizeof(head);
  while (p<buf_end) {
    if (memcmp(p,head,sizeof(head))==0) {
      return p;
    }
    p++;
  }
  return NULL;
}

static int open_image(const char *filename, void *buf, int *ntracks, int *nsides) {
  int fd = open(filename,O_RDWR);
  if (fd == -1) return -1;

  *ntracks = 0;
  *nsides = 0;
  read(fd,buf,6250*2*MAXTRACK);

  // find first sector
  const uint8_t *p = buf;
  const uint8_t *p_end = buf+6250;
  int ok = 0;
  while (!ok) {
    p = findam(p,p_end);
    if (p==NULL || p[15]!=0xfe || p[16]!=0 || p[17]!=0) {
      printf("wrong ID address mark\n");
      ok = 2;
      break;
    }
    else {
      ok = p[18]==1?1:0;
    }

    p += 20;
    p = findam(p,p_end);
    if (p==NULL || p[15]!=0xfb) {
      printf("wrong data address mark\n");
      ok = 2;
      break;
    }
    if (!ok) p += 514;
  }

  int sectors = 0;
  if (ok==1) {
    p += 16;
    sectors = p[0x19]<<8|p[0x18];
    *nsides = p[0x1b]<<8|p[0x1a];
    *ntracks = (p[0x14]<<8|p[0x13])/(sectors**nsides);
  } else {
    int pos = lseek(fd,0,SEEK_CUR);
    if (pos>6250*100) {
      *nsides = 2;
      *ntracks = pos/(6250*2);
    } else {
      *nsides = 1;
      *ntracks = pos/6250;
    }
  }

  printf("Successfully opened image file '%s', %d tracks, %d sides, %d sectors\n",filename,*ntracks,*nsides,sectors);

  return fd;
}

void * thread_floppy(void * arg) {
  uint32_t n,oldn=0;
  unsigned int oldaddr=2000;
  uint8_t buf[6250*2*MAXTRACK];
  int ntracks,nsides;

  int fd = open_image(arg,buf,&ntracks,&nsides);
  if (fd==-1) {
    printf("Error opening floppy image file\n");
    return NULL;
  }
  unsigned int tks = nsides==1;
  unsigned int pos=0,pos1=0,posw=0;
  int wrb = 0;

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
      perror("UIO interrupts");
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

    if (r) {
      uint8_t *trkp = buf+(track>>tks)*6250;
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

        wrb = 1;
      }
    }
  }

  if (wrb) {
    lseek(fd,0,SEEK_SET);
    write(fd,buf,6250*nsides*ntracks);
  }
  close(fd);

  return NULL;
}
