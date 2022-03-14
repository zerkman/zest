/*
 * floppy_img.c - floppy disk image file management
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
#include <string.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/types.h>
#include <unistd.h>

#include "floppy_img.h"

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

Flopimg * flopimg_open(const char *filename, int rdonly) {
  Flopimg *img = malloc(sizeof(Flopimg));
  if (img==NULL) return NULL;
  memset(img,0,sizeof(Flopimg));

  img->fd = open(filename,rdonly?O_RDONLY:O_RDWR);
  if (img->fd == -1) return NULL;

  int sectors = 0;
  img->rdonly = rdonly;
  img->ntracks = 0;
  img->nsides = 0;
  img->wrb = 0;
  int size = read(img->fd,img->buf,6250*2*MAXTRACK);

  if (size > 0) {
    // find first sector
    const uint8_t *p = img->buf;
    const uint8_t *p_end = img->buf+6250;
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
    if (ok==1) {
      p += 16;
      sectors = p[0x19]<<8|p[0x18];
      img->nsides = p[0x1b]<<8|p[0x1a];
      img->ntracks = (p[0x14]<<8|p[0x13])/(sectors*img->nsides);
    } else {
      int pos = lseek(img->fd,0,SEEK_CUR);
      if (pos>6250*100) {
        img->nsides = 2;
        img->ntracks = pos/(6250*2);
      } else {
        img->nsides = 1;
        img->ntracks = pos/6250;
      }
    }
  }

  return img;
}

void flopimg_writeback(Flopimg *img) {
  img->wrb = 1;
}

uint8_t * flopimg_trackpos(Flopimg *img, int track, int side) {
  if (track>=img->ntracks) {
    img->ntracks = track+1;
  }
  if (side>=img->nsides) {
    img->nsides = side+1;
  }
  return img->buf+(track*img->nsides+side)*6250;
}

void flopimg_close(Flopimg *img) {
  if (img->wrb) {
    lseek(img->fd,0,SEEK_SET);
    write(img->fd,img->buf,6250*img->nsides*img->ntracks);
  }
  close(img->fd);
  free(img);
}
