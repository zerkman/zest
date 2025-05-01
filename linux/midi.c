/*
 * midi.c - MIDI I/O management
 *
 * Copyright (c) 2025 Francois Galea <fgalea at free.fr>
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
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <sys/inotify.h>
#include <dirent.h>

#include "midi.h"

extern volatile uint32_t *parmreg;
extern volatile int thr_end;

static int midifd = -1;


// called from floppy interrupt manager if the midi flag is on
// If a character is available from the ACIA, send it to MIDI
void midi_interrupt(void) {
  unsigned int st = parmreg[12];
  int txd_full = st&0x200;
  if (txd_full) {
    unsigned char v = st&0xff;
    // printf("recv 0x%02x\n",(int)v);
    write(midifd,&v,1);
  }
}

// send a character to the MIDI ACIA
void midi_send(int c) {
  unsigned int st;
  int txd_full;
  int rxd_full;
  do {
    st = parmreg[12];
    txd_full = st&0x200;
    rxd_full = st&0x100;
    if (txd_full) {
      unsigned char v = st&0xff;
      // printf("recv 0x%02x\n",(int)v);
      write(midifd,&v,1);
    }
  } while (rxd_full);
  parmreg[12] = c;
}

static int is_midi(const struct dirent *e) {
  return strncmp(e->d_name,"midi",4)==0;
}

void * thread_midi(void * arg) {
  unsigned char buf[1024];
  struct dirent **namelist;
  int i;

  int ndev = scandir("/dev/snd",&namelist,is_midi,versionsort);
  if (ndev<0) return;

  nfds = 0;

  for (i=0; i<ndev; ++i) {
    add_device(namelist[i]->d_name);
    free(namelist[i]);
  }
  free(namelist);

  int inotify_fd = inotify_init1(IN_NONBLOCK);
  inotify_add_watch(inotify_fd,"/dev/snd",IN_CREATE|IN_DELETE);

  midifd = open(MIDI_DEVICE,O_RDWR);

  struct pollfd pfd = { .fd=midifd, .events=POLLIN };

  for (;;) {
    int status = poll(&pfd,1,5);
    if (thr_end) break;
    if (status==-1) {
      perror("MIDI interface");
      break;
    } else if (status==0) {
      continue;
    }
    int n = read(midifd,buf,1024);
    int i;
    for (i=0;i<n;++i) {
      // printf("send 0x%02x\n",(int)buf[i]);
      midi_send(buf[i]);
    }
  }

  close(midifd);
  midifd = -1;
  return NULL;
}
