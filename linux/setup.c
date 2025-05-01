/*
 * setup.c - Setup code for PL / Linux on Z-Turn board
 *
 * Copyright (c) 2020-2025 Francois Galea <fgalea at free.fr>
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
void * thread_jukebox(void * arg);

/* from ikbd.c */
void * thread_ikbd(void * arg);

/* from midi.c */
void * thread_midi(void * arg);

/* from infomsg.c */
void * thread_infomsg(void * arg);

#define ST_MEM_ADDR 0x10000000
#define ST_MEM_SIZE 0x1000000

volatile uint32_t *parmreg;
int parmfd;

volatile int thr_end = 0;

static int sound_mute = 0;
static int sound_vol = 16;

static int cfg_romsize = 0;	// 0:192k 1:256k 2:512k 3:1M

static unsigned long read_u32(const unsigned char *p) {
  unsigned long a = *p++;
  unsigned long b = *p++;
  unsigned long c = *p++;
  unsigned long d = *p++;
  return a<<24 | b<<16 | c<<8 | d;
}

static unsigned long read_u16(const unsigned char *p) {
  unsigned long a = *p++;
  unsigned long b = *p++;
  return a<<8 | b;
}

static void setup_cfg(unsigned int reset) {
  static const unsigned int mem_cfg[] = {0,1,3,7,9,15,31,55};
  static const unsigned int ws_cfg[] = {2,3,1,0};
  unsigned int cfg = reset;
  cfg |= config.mono?4:0;
  cfg |= mem_cfg[config.mem_size]<<4;
  if (sound_mute==0)
    cfg |= sound_vol<<10;
  cfg |= config.floppy_a_enable<<15;
  cfg |= config.floppy_a_write_protect<<16;
  cfg |= config.floppy_b_enable<<17;
  cfg |= config.floppy_b_write_protect<<18;
  cfg |= config.extended_video_modes<<19;
  cfg |= ws_cfg[config.wakestate]<<20;
  cfg |= cfg_romsize<<22;
  cfg |= config.shifter_wakestate<<24;
  cfg |= config.scan_doubler_mode<<25;
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
  // "press" the reset button
  setup_cfg(2); // Bit 0 clear=reset
  // clear memory
  memset(mem_array+8,0,0xe00000-8);
  // reset the FPGA logic (invalidates the RAM cache)
  pl_reset();
  // release the reset button
  setup_cfg(3); // end reset
}

void warm_reset() {
  // "press" the reset button
  setup_cfg(2); // Bit 0 clear=reset
  // release the reset button
  setup_cfg(3); // |3="end reset"
}

void setup_update() {
  setup_cfg(3);
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
  unsigned char buf[0x40];
  unsigned long rom_addr;
  unsigned int rom_size;
  int is_emutos = 0;
  int tos_version = 0;
  FILE *bootfd = fopen(filename,"rb");
  if (!bootfd) {
    printf("Could not open ROM file `%s`\n",filename);
    return 1;
  }
  fread(buf,1,0x40,bootfd);
  if (buf[0]!=0x60 || buf[1]!=0x2e) {
    printf("%s: invalid header\n",filename);
    return 1;
  }
  if (read_u32(buf+0x2c)==0x45544F53) {
    // magic value 'ETOS' found => system is EmuTOS
    is_emutos = 1;
  } else {
    // we are not running EmuTOS but plain TOS
    is_emutos = 0;
    tos_version = read_u16(buf+2);
    if ((tos_version<0x100 || tos_version>0x104) && tos_version!=0x206) {
      // supported TOS versions are 1.00-1.04 / TOS 2.06
      printf("%s: unsupported TOS version\n",filename);
      return 1;
    }
  }
  rom_addr = read_u32(buf+8);
  memcpy(mem_array+rom_addr,buf,0x40);
  rom_size = 0x40+fread(mem_array+rom_addr+0x40,1,0x100000-0x40,bootfd);
  fclose(bootfd);
  if (rom_size==0x30000 && rom_addr==0xFC0000)
    cfg_romsize = 0;
  else if (rom_size==0x40000 && rom_addr==0xE00000)
    cfg_romsize = 1;
  else if (rom_size==0x80000 && rom_addr==0xE00000)
    cfg_romsize = 2;
  else if (rom_size==0x100000 && rom_addr==0xE00000)
    cfg_romsize = 3;
  else {
    printf("%s: unsupported ROM size/address\n",filename);
    return 1;
  }
  memcpy(mem_array,mem_array+rom_addr,8);
  // Remove CRC check from TOS 2.06
  if (!is_emutos && tos_version==0x206) {
    // bcc $e00894 => bra $e00894
    mem_array[0xe007f6] = 0x60;
  }

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

  config_set_file(configfilename);
  config_load();

  if (config.rom_file==NULL) {
    printf("Fatal: no ROM file configured in config file\n");
    return 1;
  }

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

  menu_init("/usr/share/fonts/gelly.pcf");

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
  if (load_rom(config.rom_file)!=0) {
    // in case the ROM could not be loaded, fall back to default ROM
    if (load_rom("/usr/share/zest/rom.img")!=0) return 1;
  }

  pthread_t kbd_thr;
  pthread_create(&kbd_thr,NULL,thread_ikbd,NULL);
  pthread_t floppy_thr;
  pthread_create(&floppy_thr,NULL,thread_floppy,NULL);
  pthread_t midi_thr;
  pthread_create(&midi_thr,NULL,thread_midi,NULL);
  pthread_t infomsg_thr;
  pthread_create(&infomsg_thr,NULL,thread_infomsg,NULL);
  pthread_t jukebox_thr;
  pthread_create(&jukebox_thr,NULL,thread_jukebox,NULL);

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
  pthread_join(midi_thr,NULL);
  pthread_join(infomsg_thr,NULL);
  if (has_sil) {
    hdmi_stop();
  }

  return 0;
}
