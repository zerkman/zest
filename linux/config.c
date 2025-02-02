/*
 * config.c - zeST configuration
 *
 * Copyright (c) 2023-2025 Francois Galea <fgalea at free.fr>
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
#include <string.h>
#include <strings.h>
#include <stdlib.h>
#include <inttypes.h>
#include <ctype.h>
#include <ini.h>

#include "config.h"

static const char *config_file = NULL;
ZestConfig config;


// interpret string str as a boolean value
static int truefalse(const char *x) {
  if (strcasecmp(x,"true")==0) return 1;
  if (strcasecmp(x,"yes")==0) return 1;
  if (strcasecmp(x,"on")==0) return 1;
  if (strcmp(x,"1")==0) return 1;
  if (strcasecmp(x,"false")==0) return 0;
  if (strcasecmp(x,"no")==0) return 0;
  if (strcasecmp(x,"off")==0) return 0;
  if (strcmp(x,"0")==0) return 0;

  printf("could not interpret boolean value `%s`, returning false\n",x);
  return 0;
}

static const char *memsize_values[] = {"256K","512K","1M","2M","2.5M","4M","8M","14M"};

// interpret string str as a memory size setting
static int memorysize(const char *x) {
  int i;
  for (i=0;i<sizeof(memsize_values)/sizeof(memsize_values[0]);++i) {
    if (strcasecmp(x,memsize_values[i])==0)
      return i;
  }

  printf("invalid size setting `%s`\n",x);
  return CFG_1M;   // 1 MB
}

static int handler(void* user, const char* section, const char* name, const char* value) {
  ZestConfig* pconfig = user;

  if (strlen(value)==0) {
    // empty setting -> set NULL value
    value = NULL;
  }

  #define MATCH(s, n) strcmp(section, s) == 0 && strcmp(name, n) == 0
  if (MATCH("main","mono")) {
    pconfig->mono = truefalse(value);
  } else if (MATCH("main","extended_video_modes")) {
    pconfig->extended_video_modes = truefalse(value);
  } else if (MATCH("main","mem_size")) {
    pconfig->mem_size = memorysize(value);
  } else if (MATCH("main", "wakestate")) {
    int ws = atoi(value);
    if (ws<1 || ws>4) {
      printf("invalid wakestate value `%d`\n",ws);
    } else {
      pconfig->wakestate = ws-1;
    }
  } else if (MATCH("main", "shifter_wakestate")) {
    int ws = atoi(value);
    if (ws<0 || ws>1) {
      printf("invalid shifter wakestate value `%d`\n",ws);
    } else {
      pconfig->shifter_wakestate = ws;
    }
  } else if (MATCH("main","rom_file")) {
    if (value) pconfig->rom_file = strdup(value);
  } else if (MATCH("floppy","floppy_a")) {
    if (value) pconfig->floppy_a = strdup(value);
  } else if (MATCH("floppy","floppy_a_enable")) {
    if (value) pconfig->floppy_a_enable = truefalse(value);
  } else if (MATCH("floppy","floppy_a_write_protect")) {
    if (value) pconfig->floppy_a_write_protect = truefalse(value);
  } else if (MATCH("floppy","floppy_b")) {
    if (value) pconfig->floppy_b = strdup(value);
  } else if (MATCH("floppy","floppy_b_enable")) {
    if (value) pconfig->floppy_b_enable = truefalse(value);
  } else if (MATCH("floppy","floppy_b_write_protect")) {
    if (value) pconfig->floppy_b_write_protect = truefalse(value);
  } else if (MATCH("hdd","image")) {
    if (value) pconfig->hdd_image = strdup(value);
  } else if (MATCH("keyboard","right_alt_is_altgr")) {
    if (value) pconfig->right_alt_is_altgr = truefalse(value);
  } else if (MATCH("jukebox","enabled")) {
    if (value) pconfig->jukebox_enabled = truefalse(value);
  } else if (MATCH("jukebox","path")) {
    if (value) pconfig->jukebox_path = strdup(value);
  } else if (MATCH("jukebox","timeout")) {
    uint64_t t = atoi(value)*1000000ULL;
    if (t < 1)
    {
      printf("Invalid jukebox timeout value '%lld'\n", t);
    } else {
      pconfig->jukebox_timeout_duration = t;
    }
  }
  else {
    return 0;  /* unknown section/name, error */
  }
  return 1;
}

void config_set_file(const char *filename) {
  if (config_file) {
    free((void*)config_file);
  }
  config_file = strdup(filename);
}

void config_load(void) {
  config.mono = 0;
  config.extended_video_modes = 0;
  config.mem_size = CFG_1M;
  config.wakestate = 2;
  config.shifter_wakestate = 0;
  config.rom_file = NULL;
  config.floppy_a = NULL;
  config.floppy_a_enable = 1;
  config.floppy_a_write_protect = 0;
  config.floppy_b = NULL;
  config.floppy_b_enable = 0;
  config.floppy_b_write_protect = 0;
  config.hdd_image = NULL;
  config.right_alt_is_altgr = 0;
  config.jukebox_enabled = 0;
  config.jukebox_timeout_duration = 90000000;
  config.jukebox_path = NULL;

  if (ini_parse(config_file,handler,&config) < 0) {
    printf("Can't load `%s`\n",config_file);
    return;
  }
}

void config_save(void) {
  FILE *fd = fopen(config_file,"w");
  if (!fd) {
    perror(config_file);
    return;
  }
  fprintf(fd,"[main]\n");
  fprintf(fd,"mono = %s\n",config.mono?"true":"false");
  fprintf(fd,"extended_video_modes = %s\n",config.extended_video_modes?"on":"off");
  fprintf(fd,"mem_size = %s\n",memsize_values[config.mem_size]);
  fprintf(fd,"wakestate = %d\n",config.wakestate+1);
  fprintf(fd,"shifter_wakestate = %d\n",config.shifter_wakestate);
  fprintf(fd,"rom_file = %s\n",config.rom_file?config.rom_file:"");

  fprintf(fd,"\n[floppy]\n");
  fprintf(fd,"floppy_a = %s\n",config.floppy_a?config.floppy_a:"");
  fprintf(fd,"floppy_a_enable = %s\n",config.floppy_a_enable?"true":"false");
  fprintf(fd,"floppy_a_write_protect = %s\n",config.floppy_a_write_protect?"true":"false");
  fprintf(fd,"floppy_b = %s\n",config.floppy_b?config.floppy_b:"");
  fprintf(fd,"floppy_b_enable = %s\n",config.floppy_b_enable?"true":"false");
  fprintf(fd,"floppy_b_write_protect = %s\n",config.floppy_b_write_protect?"true":"false");

  fprintf(fd,"\n[hdd]\n");
  fprintf(fd,"image = %s\n",config.hdd_image?config.hdd_image:"");

  fprintf(fd,"\n[keyboard]\n");
  fprintf(fd,"right_alt_is_altgr = %s\n",config.right_alt_is_altgr?"true":"false");

  fprintf(fd,"\n[jukebox]\n");
  fprintf(fd,"enabled = %s\n",config.jukebox_enabled?"true":"false");
  fprintf(fd,"path = %s\n",config.jukebox_path?config.jukebox_path:"");
  fprintf(fd,"timeout = %d\n",(int)(config.jukebox_timeout_duration/1000000ULL));

  fclose(fd);
}
