/*
 * setup.c - Setup code for PL / Linux on Z-Turn board
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
#include <errno.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <pthread.h>
#include <limits.h> // for PATH_MAX
#include <signal.h>

#include "menu.h"
#include "config.h"

#include "sil9022a.h"

/* from floppy.c */
void * thread_floppy(void * arg);

/* from ikbd.c */
void * thread_ikbd(void * arg);

/* from infomsg.c */
void * thread_infomsg(void * arg);

#define ST_MEM_ADDR 0x10000000
#define ST_MEM_SIZE 0x1000000

volatile uint32_t *parmreg;
int parmfd;

volatile int thr_end = 0;

static int sound_mute = 0;
static int sound_vol = 16;

static void setup_cfg(int reset) {
  static const int mem_cfg[] = {0,1,3,7,9,15};
  static const int ws_cfg[] = {2,3,1,0};
  int cfg = reset;
  cfg |= config.mono?4:0;
  cfg |= mem_cfg[config.mem_size]<<4;
  cfg |= ws_cfg[config.wakestate-1]<<8;
  if (sound_mute==0)
    cfg |= sound_vol<<10;
  cfg |= config.floppy_a_write_protect<<15;
  cfg |= config.floppy_b_write_protect<<16;
  cfg |= config.extended_video_modes<<17;
  parmreg[0] = cfg;
}

void *uio_map(const char *file, size_t length, int *fd) {
  void *p;
  *fd = open(file,O_RDWR);
  if (*fd < 0) {
    printf("Cannot open UIO device '%s'\n", file);
    return NULL;
  }
  p = mmap(0,length,PROT_READ|PROT_WRITE,MAP_SHARED,*fd,0);
  if (p == MAP_FAILED) {
    printf("Cannot map UIO device\n");
    return NULL;
  }
  return p;
}

#define FPGA_RST_CTRL (0x00000240/4)
void pl_reset(void) {
  int fd = open("/dev/mem",O_RDWR|O_SYNC);
  if (fd < 0) {
    printf("pl_reset: Cannot open memory device\n");
    return;
  }
  volatile uint32_t *slcr = mmap(NULL,0x1000,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0xF8000000);
  slcr[FPGA_RST_CTRL] = 0xf;  // all 4 PL resets
  usleep(10);
  slcr[FPGA_RST_CTRL] = 0;
  munmap((void*)slcr,0x1000);
  close(fd);
}

int usage(const char *progname) {
  printf("usage: %s [OPTIONS] config.cfg\n"
    , progname);
  return 1;
}

static uint8_t *mem_array;

void cold_reset() {
  setup_cfg(2); // Bit 0 clear=reset
  memset(mem_array+8,0,0x1fff8);
  setup_cfg(3); // end reset
}

void warm_reset() {
  setup_cfg(2); // Bit 0 clear=reset
  setup_cfg(3); // |3="end reset"
}

void set_wakestate(int ws) {
  config.wakestate = ws;
  setup_cfg(3);
}

int get_wakestate(void) {
  return config.wakestate;
}

int get_sound_vol(void) {
  return sound_vol;
}

void set_sound_vol(int x) {
  sound_vol = x;
  setup_cfg(3);
}

int get_sound_mute(void) {
  return sound_mute;
}

void set_sound_mute(int x) {
  sound_mute = x?1:0;
  setup_cfg(3);
}

int load_rom(const char *filename) {
  FILE *bootfd = fopen(filename,"rb");
  if (!bootfd) {
    printf("Could not open ROM file `%s`\n",filename);
    return 1;
  }
  fread(mem_array+0xfc0000,1,0x30000,bootfd);
  fclose(bootfd);
  memcpy(mem_array,mem_array+0xfc0000,8);
  return 0;
}

static void signal_handler(int sig) {
  thr_end = 1;
}

int main(int argc, char **argv) {
  int has_sil;

  const char *configfilename = NULL;
  int a = 0;
  while (++a<argc) {
    const char *arg = argv[a];
    if (configfilename == NULL) {
      configfilename = arg;
    } else {
      return usage(argv[0]);
    }
  }
  if (configfilename == NULL) {
    usage(argv[0]);
    return 1;
  }

  config_load(configfilename);

  if (config.rom_file==NULL) {
    printf("Fatal: no ROM file configured in config file\n");
    return 1;
  }

  menu_init();

  pl_reset();

  parmreg = uio_map("/dev/uio0",0x8000,&parmfd);
  if (parmreg == NULL) {
    return 1;
  }
  parmreg[0] = 0;  /* software reset signal */
  int i;
  for (i=4; i<8; ++i) {
      parmreg[i] = 0xffffffff;
  }

  int memfd = open("/dev/mem",O_RDWR|O_SYNC);
  if (memfd < 0) {
    printf("Cannot open memory device\n");
    return 1;
  }
  mem_array = mmap(NULL,ST_MEM_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,memfd,ST_MEM_ADDR);
  if (mem_array == MAP_FAILED) {
    printf("Could not allocate the shared memory block: %s\n", strerror(errno));
  }

  has_sil = !hdmi_init();
  if (has_sil) {
    int status;
    /* Initialize HDMI, set up 1080p50 RGB mode */
    // status = hdmi_init(14850,5000,2200,1350);
    /* 1080p60 */
    // status = hdmi_init(14850,6000,2200,1125);
    if (config.mono) {
      /* Mono */
      status = hdmi_set_mode(3200,7129,896,501);
    } else {
      /* 576p */
      status = hdmi_set_mode(3200,5000,1024,625);
    }
    if (status != 0) {
      printf("HDMI setup Failed\n");
      return 1;
    }
    printf("HDMI setup successful\n");
  }

  memset(mem_array+0xfa0000,0xff,0x20000);
  if (load_rom(config.rom_file)!=0) return 1;

  pthread_t kbd_thr;
  pthread_create(&kbd_thr,NULL,thread_ikbd,NULL);
  pthread_t floppy_thr;
  pthread_create(&floppy_thr,NULL,thread_floppy,NULL);
  pthread_t infomsg_thr;
  pthread_create(&infomsg_thr,NULL,thread_infomsg,NULL);

  struct sigaction sa = {0};
  sa.sa_handler = signal_handler;
  sigaction(SIGTERM,&sa,NULL);
  sigaction(SIGINT,&sa,NULL);

  cold_reset();
  while (thr_end==0) {
    usleep(10000);
  }
  parmreg[0] = 0;
  pthread_join(kbd_thr,NULL);
  pthread_join(floppy_thr,NULL);
  pthread_join(infomsg_thr,NULL);
  if (has_sil) {
    hdmi_stop();
  }

  return 0;
}
