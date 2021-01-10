/*
 * floppy.c - floppy drive emulation (software part)
 *
 * Copyright (c) 2020 Francois Galea <fgalea at free.fr>
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

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <pthread.h>
#include <dirent.h>
#include <poll.h>
#include <sys/time.h>

extern volatile uint32_t *parmreg;
extern int uiofd;
extern volatile int thr_end;

#define MAXTRACK 84

int fd;

static void * findam(void *p, unsigned int size) {
	static const uint8_t head[] = {0,0,0,0,0,0,0,0,0,0,0,0,0xa1,0xa1,0xa1};
	size -= sizeof(head);
	while (size-->=0) {
		if (memcmp(p,head,sizeof(head))==0) {
			return p;
		}
		p++;
	}
	return NULL;
}

static int open_image(const char *filename, void *buf, int *ntracks, int *nsides) {
	fd = open(filename,O_RDWR);
	if (fd == -1) return -1;

	*ntracks = 0;
	*nsides = 0;
	read(fd,buf,6250*2*MAXTRACK);

	// find first sector
	uint8_t *p = findam(buf,6250);
	if (p==NULL || p[15]!=0xfe || p[16]!=0 || p[17]!=0 || p[18]!=1)
		return -1;

	p += 20;
	p = findam(p,6250-(p-(uint8_t*)buf));
	if (p==NULL || p[15]!=0xfb)
		return -1;

	p += 16;
	int sectors = p[0x19]<<8|p[0x18];
	*nsides = p[0x1b]<<8|p[0x1a];
	*ntracks = (p[0x14]<<8|p[0x13])/(sectors**nsides);

	printf("Successfully opened image file '%s', %d tracks, %d sides, %d sectors\n",filename,*ntracks,*nsides,sectors);

	return 0;
}

void * thread_floppy(void * arg) {
	uint32_t n,oldn=0;
	unsigned int oldaddr=2000;
	uint8_t buf[6250*2*MAXTRACK];
	int s;
	int ntracks,nsides;

	if (open_image(arg,buf,&ntracks,&nsides) == -1) {
		printf("Error opening floppy image file\n");
		return NULL;
	}
	unsigned int tks = nsides==1;
	unsigned int pos=0,pos1=0,pos2=0,posw=0;
	int wrb = 0;

	do {
		// unmask interrupt
		uint32_t unmask = 1;
		ssize_t rv = write(uiofd, &unmask, sizeof(unmask));
		if (rv != (ssize_t)sizeof(unmask)) {
			perror("unmask interrupt");
		}
		s = read(uiofd,&n,4);
		if (s==0) {
			printf("nok\n");
		}

		// read host values
		uint32_t in = parmreg[0];
		unsigned int r = in>>31;
		unsigned int w = in>>30&1;
		unsigned int addr = in>>19&0x7ff;
		unsigned int track = in>>11&0xff;
		if (oldn!=0 && n!=oldn+1) {
			printf("it=%u r=%u w=%u track=%u addr=%u\n",(unsigned)n,r,w,track,addr);
			fflush(stdout);
		}
		oldn = n;
		unsigned int newaddr = oldaddr==1562?0:(oldaddr+1);
		if (oldaddr<=1562 && addr!=newaddr) {
			printf("missed addr=%u\n",newaddr);
			fflush(stdout);
		}
		oldaddr = addr;

		if (r) {
			uint8_t *trkp = buf+(track>>tks)*6250;
			posw = pos2;
			pos2 = pos1;
			pos1 = pos;
			pos = addr*4+4;
			if (pos>=6250) {
				pos -= 6250;
			}
			uint8_t *p = trkp+pos;
			uint32_t d;
			d = *p++<<24;
			d |= *p++<<16;
			if (pos==6248) {
				d |= 0x00004e4e;
			} else {
				d |= *p++<<8;
				d |= *p++;
			}
			parmreg[2] = d;
			if (w) {
				d = parmreg[1];
				uint8_t *p = trkp+posw;
				*p++ = d>>24;
				*p++ = d>>16;
				if (posw<6248) {
					*p++ = d>>8;
					*p++ = d;
				}
				wrb = 1;
			}
		}
	} while (s!=0 && thr_end==0);

	if (wrb) {
		lseek(fd,0,SEEK_SET);
		write(fd,buf,6250*nsides*ntracks);
	}
	close(fd);

	return NULL;
}
