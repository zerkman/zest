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

#include "sil9022a.h"

/* from floppy.c */
void * thread_floppy(void * arg);

/* from ikbd.c */
void * thread_ikbd(void * arg);


#define ST_MEM_ADDR 0x10000000
#define ST_MEM_SIZE 0x1000000

#define CFG_COLR 0x0000
#define CFG_MONO 0x0004

#define CFG_256K 0x0000
#define CFG_512K 0x0010
#define CFG_1M   0x0030
#define CFG_2M   0x0070
#define CFG_2_5M 0x0090
#define CFG_4M   0x00f0

#define CFG_WS1  0x0200
#define CFG_WS2  0x0300
#define CFG_WS3  0x0100
#define CFG_WS4  0x0000
#define CFG_WSMK 0x0300


volatile uint32_t *parmreg;
int parmfd;

volatile int thr_end = 0;

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
  printf("usage: %s [OPTIONS] rom.img [floppy.mfm]\n\n"
    "OPTIONS are:\n"
    " --color     Set video to color mode (default)\n"
    " --mono      Set video to monochrome mode\n"
    " --mem=VAL   Choose memory size\n"
    "             Possible values: 256K, 512K, 1M (default), 2M, 2.5M, 4M\n"
    " --ws=X      Set wakestate\n"
    "             Possible values: 1, 2, 3, 4 (default)\n"
    , progname);
  return 1;
}

static uint8_t *mem_array;
static int cfg;

void cold_reset() {
  parmreg[0] = cfg|2; // Bit 0 clear=reset
  memset(mem_array+8,0,0x1fff8);
  int i;
  for (i=4; i<8; ++i) {
      parmreg[i] = 0xffffffff;
  }
  parmreg[0] = cfg|3; // end reset
}

void warm_reset() {
  parmreg[0] = cfg|2; // Bit 0 clear=reset
  parmreg[0] = cfg|3; // |3="end reset"
}

void set_wakestate(int ws) {
  switch (ws) {
    case 1: cfg = (cfg&~CFG_WSMK) | CFG_WS1; break;
    case 2: cfg = (cfg&~CFG_WSMK) | CFG_WS2; break;
    case 3: cfg = (cfg&~CFG_WSMK) | CFG_WS3; break;
    case 4: cfg = (cfg&~CFG_WSMK) | CFG_WS4; break;
  }
}

int get_wakestate(void) {
  switch (cfg&CFG_WSMK) {
    case CFG_WS1: return 1;
    case CFG_WS2: return 2;
    case CFG_WS3: return 3;
    case CFG_WS4: return 4;
  }
  return 0;
}

void load_rom(const char *filename) {
  FILE *bootfd = fopen(filename,"rb");
  fread(mem_array+0xfc0000,1,0x30000,bootfd);
  fclose(bootfd);
  memcpy(mem_array,mem_array+0xfc0000,8);
}

static void signal_handler(int sig) {
  thr_end = 1;
}

void setup_file_selector(const char *filename, int state_id)
{
  FILE_SELECTOR_STATE *state = &file_selector_state[state_id];
  if (*filename==0) {
    return; // Already initialised at the start of main
  }
  if (*filename!='/') {
    getcwd(state->selected_file,PATH_MAX);
    strcat(state->selected_file,"/");
  }
  strcat(state->selected_file,filename);
  strcpy(state->current_directory,state->selected_file);
  char *p = &state->current_directory[strlen(state->current_directory)];
  while (p[-1]!='/'&&p!=state->current_directory) p--;
  *p=0;
}

int main(int argc, char **argv) {
  int cfg_video = CFG_COLR;
  int cfg_mem = CFG_1M;
  int cfg_ws = CFG_WS4;
  int has_sil;
  memset(file_selector_state, 0, sizeof(FILE_SELECTOR_STATE)*FILE_SELECTOR_VIEWS);
  getcwd(file_selector_state[0].current_directory, PATH_MAX);
  strcat(file_selector_state[0].current_directory, "/");
  for (int i=1;i<FILE_SELECTOR_VIEWS;i++) {
    strcpy(file_selector_state[i].current_directory,file_selector_state[0].current_directory);
  }

  const char *binfilename = NULL;
  const char *floppy1filename = NULL;
  const char *floppy2filename = NULL;
  int a = 0;
  while (++a<argc) {
    const char *arg = argv[a];
    if (arg[0]=='-') {
      if (!strcmp(arg,"--color")) {
        cfg_video = CFG_COLR;
      } else if (!strcmp(arg,"--mono")) {
        cfg_video = CFG_MONO;
      } else if (!strncmp(arg,"--mem=",6)) {
        arg += 6;
        if (!strcmp(arg,"256K")) {
          cfg_mem = CFG_256K;
        } else if (!strcmp(arg,"512K")) {
          cfg_mem = CFG_512K;
        } else if (!strcmp(arg,"1M")) {
          cfg_mem = CFG_1M;
        } else if (!strcmp(arg,"2M")) {
          cfg_mem = CFG_2M;
        } else if (!strcmp(arg,"2.5M")) {
          cfg_mem = CFG_2_5M;
        } else if (!strcmp(arg,"4M")) {
          cfg_mem = CFG_4M;
        } else return usage(argv[0]);
      } else if (!strncmp(arg,"--ws=",5)) {
        switch(arg[5]) {
          case '1': cfg_ws = CFG_WS1; break;
          case '2': cfg_ws = CFG_WS2; break;
          case '3': cfg_ws = CFG_WS3; break;
          case '4': cfg_ws = CFG_WS4; break;
          default:
            return usage(argv[0]);
        }
      }
       else return usage(argv[0]);
    }
    else if (binfilename==NULL) {
      binfilename = arg;
      setup_file_selector(arg,FILE_SELECTOR_TOS_IMAGE);
    } else if (floppy1filename==NULL) {
      floppy1filename = arg;
      setup_file_selector(arg,FILE_SELECTOR_DISK_A);
    } else if (floppy2filename==NULL) {
      floppy1filename = arg;
      setup_file_selector(arg,FILE_SELECTOR_DISK_B);
    } else {
      return usage(argv[0]);
    }
  }
  if (binfilename == NULL) {
    usage(argv[0]);
    return 1;
  }
  cfg = cfg_ws | cfg_mem | cfg_video;

  pl_reset();

  parmreg = uio_map("/dev/uio0",0x40,&parmfd);
  if (parmreg == NULL) {
    return 1;
  }
  parmreg[0] = 0;  /* software reset signal */

  int memfd = open("/dev/mem",O_RDWR|O_SYNC);
  if (memfd < 0) {
    printf("Cannot open memory device\n");
    return 1;
  }
  mem_array = mmap(NULL,ST_MEM_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,memfd,ST_MEM_ADDR);
  if (mem_array == MAP_FAILED) {
    printf("Could not allocate the shared memory block: %s\n", strerror(errno));
  }
  parmreg[1] = ST_MEM_ADDR;

  has_sil = !hdmi_init();
  if (has_sil) {
    int status;
    /* Initialize HDMI, set up 1080p50 RGB mode */
    // status = hdmi_init(14850,5000,2200,1350);
    /* 1080p60 */
    // status = hdmi_init(14850,6000,2200,1125);
    if (cfg & CFG_MONO) {
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
  pthread_t kbd_thr;
  pthread_create(&kbd_thr,NULL,thread_ikbd,NULL);
  pthread_t floppy_thr;
  pthread_create(&floppy_thr,NULL,thread_floppy,(void*)floppy1filename);

  struct sigaction sa = {0};
  sa.sa_handler = signal_handler;
  sigaction(SIGTERM,&sa,NULL);
  sigaction(SIGINT,&sa,NULL);

  /*
  int c;
  do {
    do_reset();
    c = getchar();
    printf("new reset\n");
    parmreg[0] = 0;
    usleep(10000);
  } while (c!='q');
  thr_end = 1;
  */
  load_rom(binfilename);
  cold_reset();
  while (thr_end==0) {
    usleep(10000);
  }
  parmreg[0] = 0;
  pthread_join(kbd_thr,NULL);
  pthread_join(floppy_thr,NULL);
  if (has_sil) {
    hdmi_stop();
  }

  return 0;
}
