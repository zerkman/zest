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

static const uint8_t *findam(const uint8_t *p, const uint8_t *buf_end) {
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

static const uint8_t *find_sector(const uint8_t *p, int track, int side, int sector) {
  const uint8_t *p_end = p + 6250;
  int ok = 0;
  while (!ok) {
    p = findam(p,p_end);
    if (p==NULL || p[15]!=0xfe || p[16]!=track || p[17]!=side) {
      printf("wrong ID address mark\n");
      ok = 2;
      break;
    }
    else {
      ok = p[18]==sector?1:0;
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
    return p;
  }
  return NULL;
}

static uint16_t crc16_table[256];

static void crc16_init(void) {
  unsigned int i,j;
  for (i=0; i<256; ++i) {
     unsigned int w = i<<8;
     for (j=0; j<8; ++j)
       w = (w<<1) ^ (0x1021&-((w>>15)&1));
     crc16_table[i] = w;
  }
}

static unsigned int crc16(const void *buf,size_t size) {
  const uint8_t *p = buf;
  unsigned int crc = 0xffff;
  while (size-->0)
    crc = crc16_table[crc>>8^*p++]^(crc&0xff)<<8;
  return crc;
}

static unsigned int readw(const unsigned char *ptr) {
  unsigned int v;
  v = ((unsigned int)ptr[1])<<8;
  v |= ((unsigned int)ptr[0]);
  return v;
}

static void load_mfm(Flopimg *img) {
  int size = read(img->fd,img->buf,6250*2*MAXTRACK);
  int sectors = 0;

  if (size > 0) {
    const uint8_t *p = img->buf;
    p = find_sector(p,0,0,1);
    if (p) {
      sectors = readw(p+0x18);
      img->nsides = readw(p+0x1a);
      img->ntracks = readw(p+0x13)/(sectors*img->nsides);
    } else {
      int pos = lseek(img->fd,0,SEEK_END);
      if (pos>6250*100) {
        img->nsides = 2;
        img->ntracks = pos/(6250*2);
      } else {
        img->nsides = 1;
        img->ntracks = pos/6250;
      }
    }
  }
}

static void save_mfm(Flopimg *img) {
  lseek(img->fd,0,SEEK_SET);
  write(img->fd,img->buf,6250*img->nsides*img->ntracks);
}

static void load_st(Flopimg *img, int skew) {
  unsigned int bps;
  int track,side;
  uint8_t buf[512*11];

  crc16_init();

  read(img->fd,buf,32);

  int sectors = readw(buf+0x18);
  img->nsides = readw(buf+0x1a);
  img->ntracks = readw(buf+0x13)/(sectors*img->nsides);
  printf("tracks:%u sides:%u sectors:%u\n",img->ntracks,img->nsides,sectors);

  bps = readw(buf+0x0b);
  if (bps!=512) {
    printf("invalid sector size:%u\n",bps);
    return;
  }

  if (sectors<9 || sectors>11) {
    printf("unsupported number of sectors per track:%u\n",sectors);
    return;
  }

  lseek(img->fd,0,SEEK_SET);

  int gap1,gap2,gap4,gap5;
  if (sectors==11) {
    gap1 = 10;
    gap2 = 3;
    gap4 = 1;
    gap5 = 14;
  } else {
    gap1 = 60;
    gap2 = 12;
    gap4 = 40;
    if (sectors==10) {
      gap5 = 50;
    } else {
      gap5 = 664;
    }
  }

  crc16_init();

  int sec_shift = skew ? sectors-1 : 0;
  for (track=0; track<img->ntracks; ++track) {
    for (side=0; side<img->nsides; ++side) {
      int sector,i;
      uint8_t *p0 = flopimg_trackpos(img,track,side);
      uint8_t *p = p0;
      unsigned int crc;
      read(img->fd,buf,512*sectors);
      for (i=0; i<gap1; ++i) *p++ = 0x4E;
      for (sector=0; sector<sectors; ++sector) {
        int sec_no = sector+sec_shift;
        if (sec_no>=sectors) sec_no -= sectors;
        for (i=0; i<gap2; ++i) *p++ = 0x00;
        for (i=0; i<3; ++i) *p++ = 0xA1;
        *p++ = 0xFE;
        *p++ = track;
        *p++ = side;
        *p++ = sec_no+1;
        *p++ = 2;
        crc = crc16(p-5,5);
        *p++ = crc>>8;
        *p++ = crc;
        for (i=0; i<22; ++i) *p++ = 0x4E;
        for (i=0; i<12; ++i) *p++ = 0x00;
        for (i=0; i<3; ++i) *p++ = 0xA1;
        *p++ = 0xFB;
        memcpy(p,buf+512*sec_no,512);
        p += 512;
        crc = crc16(p-513,513);
        *p++ = crc>>8;
        *p++ = crc;
        for (i=0; i<gap4; ++i) *p++ = 0x4E;
      }
      for (i=0; i<gap5; ++i) *p++ = 0x4E;
      if (p-p0 != 6250) {
        printf("format error\n");
      }
    }
    sec_shift += sectors-skew;
    if (sec_shift>=sectors) sec_shift -= sectors;
  }

}

static void save_st(Flopimg *img) {
  int track;
  lseek(img->fd,0,SEEK_SET);

  // Read sectors, tracks, sides from the buffer, in case the disk has been reformatted
  const uint8_t *p = find_sector(img->buf,0,0,1);
  int sectors = readw(p+0x18);
  int nsides = readw(p+0x1a);
  int ntracks = readw(p+0x13)/(sectors*nsides);

  for (track=0; track<ntracks; ++track) {
    int side;
    for (side=0; side<nsides; ++side) {
      int sector;
      p = flopimg_trackpos(img,track,side);
      for (sector=0; sector<sectors; ++sector) {
        const uint8_t *sp = find_sector(p,track,side,sector+1);
        if (sp==NULL) {
          printf("sector not found\n");
          return;
        }
        write(img->fd,sp,512);
      }
    }
  }
}

Flopimg * flopimg_open(const char *filename, int rdonly, int skew) {
  int format = -1;
  char *rpp = strrchr(filename,'.');
  if (rpp && (strcmp(rpp,".mfm")==0 || strcmp(rpp,".MFM")==0)) {
    format = 0;
  } else if (rpp && (strcmp(rpp,".st")==0 || strcmp(rpp,".ST")==0)) {
    format = 1;
  } else {
    printf("Could not determine the floppy image file format\n");
    return NULL;
  }
  Flopimg *img = malloc(sizeof(Flopimg));
  if (img==NULL) return NULL;
  memset(img,0,sizeof(Flopimg));

  img->fd = open(filename,rdonly?O_RDONLY:O_RDWR);
  if (img->fd == -1) return NULL;

  img->format = format;
  img->rdonly = rdonly;

  if (format==0) {
    load_mfm(img);
  } else {
    load_st(img,3);
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

void flopimg_sync(Flopimg *img) {
  if (img->wrb) {
    if (img->format==0) {
      save_mfm(img);
    } else {
      save_st(img);
    }
    img->wrb = 0;
  }
}

void flopimg_close(Flopimg *img) {
  flopimg_sync(img);
  close(img->fd);
  free(img);
}
