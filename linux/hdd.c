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

#include "hdd.h"
#include "config.h"

static volatile uint32_t *acsireg;
static volatile uint32_t *iobuf;

static int img_fd;

static void openimg(const char *filename) {

}

void hdd_init(volatile uint32_t *parmreg) {
  acsireg = (void*)(((uint8_t*)parmreg)+0x4000);
  iobuf = acsireg + (0x2000/4);
  openimg(config.hdd_image);
}

static unsigned char command[6];
static int cmd_rd_idx = 0;

void hdd_interrupt(void) {
  unsigned int reg = *acsireg;
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
    if (cmd!=8) return;
  }
  command[cmd_rd_idx++] = d;
  if (cmd_rd_idx==6) {
    int i;
    cmd_rd_idx = 0;
    printf("cmd:");
    for (i=0;i<6;++i) printf(" %02x",command[i]);
    printf("\n");
  }
  *acsireg = 0;



}
