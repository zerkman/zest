/*
 * hdd.c - hard disk drive emulation (software part)
 *
 * Copyright (c) 2023 Francois Galea <fgalea at free.fr>
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
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include "hdd.h"
#include "config.h"

static volatile uint32_t *acsireg;
static volatile uint32_t *iobuf;

static int img_fd = -1;
static int img_sectors;

static void openimg(const char *filename) {
  img_fd = open(filename,O_RDWR);
  if (img_fd==-1) {
    printf("could not open HDD image file `%s`\n",filename);
    return;
  }
  off_t size = lseek(img_fd,0,SEEK_END);
  img_sectors = size/512;
  lseek(img_fd,0,SEEK_SET);
}

static void closeimg(void) {
  if (img_fd!=-1) {
    close(img_fd);
  }
  img_fd = -1;
}

void hdd_init(volatile uint32_t *parmreg) {
  acsireg = (void*)(((uint8_t*)parmreg)+0x4000);
  iobuf = acsireg + (0x800/4);
  openimg(config.hdd_image);
}

void hdd_exit(void) {
  closeimg();
}

static unsigned char command[6];
static int cmd_rd_idx = 0;
static int dma_on = 0;
static int dma_buf_id = 0;
static int dma_rem_sectors = 0;

static void read_next(int bsize) {
  if (dma_rem_sectors==0) {
    // finish command
    *acsireg = 0;
    dma_on = 0;
  } else {
    // initiate DMA read
    int nbs = (bsize-1)/16;
    *acsireg = 0x100 | nbs<<3 | dma_buf_id;
    if (--dma_rem_sectors>0) {
      dma_buf_id ^= 1;
      int offset = dma_buf_id*512;
      read(img_fd,((char*)iobuf)+offset,512);
    }
  }
}

static void write_first(void) {
  // initiate initial DMA write
  int nbs = 31;
  *acsireg = 0x200 | nbs<<3 | dma_buf_id;
}

static void write_next(void) {
  // initiate next DMA write
  int nbs = 31;
  if (--dma_rem_sectors>0) {
    *acsireg = 0x200 | nbs<<3 | (1-dma_buf_id);
  }
  write(img_fd,((char*)iobuf)+dma_buf_id*512,512);
  dma_buf_id ^= 1;
  if (dma_rem_sectors==0) {
    // finish command
    *acsireg = 0;
    dma_on = 0;
  }
}

void hdd_interrupt(void) {
  unsigned int reg = *acsireg;

  // if no hard drive image is set, don't respond to commands
  if (img_fd==-1) return;

  if (dma_on) {
    // a DMA command is running
    if (command[0]==8 || command[0]==0x12) {
      // read or inquiry
      read_next(512);
    }
    else if (command[0]==0x0a) {
      // write
      write_next();
    }
    return;
  }

  int d = reg&0xff;
  int a1 = (reg>>8)&1;
  //printf("received: d=%d, a1=%d\n",d,a1);

  if ((cmd_rd_idx==0)!=(a1==0)) {
    printf("ACSI error: cmd byte #%d, A1=%d\n",cmd_rd_idx,a1);
    cmd_rd_idx = 0;
    return;
  }

  if (cmd_rd_idx==0) {
    // get command byte
    int ctrl_num = d>>5;
    // only controller ID 0 is supported
    if (ctrl_num!=0) return;
    int cmd = d&0x1f;
    if (cmd!=0 && cmd!=8 && cmd!=0x0a && cmd!=0x12) return;
  }
  command[cmd_rd_idx++] = d;
  if (cmd_rd_idx==6) {
    int i;
    cmd_rd_idx = 0;
    printf("cmd:");
    for (i=0;i<6;++i) printf(" %02x",command[i]);
    printf("\n");
    if (command[0]==0) {
      // send response, no error
      *acsireg = 0;
      return;
    }
    else if (command[0]==8) {
      // read
      dma_on = 1;
      dma_buf_id = 0;
      int sector = (command[1]<<8|command[2])<<8|command[3];
      dma_rem_sectors = command[4];
      lseek(img_fd,sector*512,SEEK_SET);
      read(img_fd,(void*)iobuf,512);
      read_next(512);
      return;
    }
    else if (command[0]==0x0a) {
      // write
      dma_on = 1;
      dma_buf_id = 0;
      int sector = (command[1]<<8|command[2])<<8|command[3];
      dma_rem_sectors = command[4];
      lseek(img_fd,sector*512,SEEK_SET);
      write_first();
      return;
    }
    else if (command[0]==0x12) {
      // inquiry
      static const uint8_t data[48] =
        "\x00\x00\x01\x00\x1f\x00\x00\x00"
        "zeST    "
        "EmulatedHarddisk"
        "0100" "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
      dma_on = 1;
      dma_buf_id = 0;
      int alloc = command[3]<<8 | command[4];
      if (alloc>48) alloc = 48;
      dma_rem_sectors = 1;
      memcpy((void*)iobuf,data,48);
      read_next(alloc);
      return;
    }

  }
  // send immediate response for non-DMA commands
  *acsireg = 0;
}
