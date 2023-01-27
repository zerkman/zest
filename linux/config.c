/*
 * config.c - zeST configuration
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

#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <stdlib.h>
#include <ctype.h>
#include <ini.h>

#include "config.h"

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

// interpret string str as a memory size setting
static int memorysize(const char *x) {
  static const char *values[] = {"256k","512k","1m","2m","2.5m","4m"};
  int i;
  for (i=0;i<sizeof(values)/sizeof(values[0]);++i) {
    if (strcasecmp(x,values[i])==0)
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
  } else if (MATCH("main","mem_size")) {
    pconfig->mem_size = memorysize(value);
  } else if (MATCH("main", "wakestate")) {
    int ws = atoi(value);
    if (ws<1 || ws>4) {
      printf("invalid wakestate value `%d`\n",ws);
    } else {
      pconfig->wakestate = ws;
    }
  } else if (MATCH("main","rom_file")) {
    if (value) pconfig->rom_file = strdup(value);
  } else if (MATCH("floppy","flopimg_dir")) {
    if (value) pconfig->flopimg_dir = strdup(value);
  } else if (MATCH("floppy","floppy_a")) {
    if (value) pconfig->floppy_a = strdup(value);
  } else if (MATCH("floppy","floppy_b")) {
    if (value) pconfig->floppy_b = strdup(value);
  }
  else {
    return 0;  /* unknown section/name, error */
  }
  return 1;
}

void config_load(const char *filename) {
  config.mono = 0;
  config.mem_size = CFG_1M;
  config.wakestate = 3;
  config.rom_file = NULL;
  config.flopimg_dir = NULL;
  config.floppy_a = NULL;
  config.floppy_b = NULL;

  if (ini_parse(filename,handler,&config) < 0) {
    printf("Can't load `%s`\n",filename);
    return;
  }
}

