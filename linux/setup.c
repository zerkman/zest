/*
 * setup.c - Setup code for PL / Linux on Z-Turn board
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

#include <linux/input-event-codes.h>
#include <linux/i2c-dev.h>

/*
 * The slave address to send to and receive from.
 */

#define IIC_SLAVE_ADDR 0x3b

#define ST_MEM_ADDR 0x10000000
#define ST_MEM_SIZE 0x1000000

volatile uint32_t *parmreg;

// IIC device file descriptor
int i2cfd;

int i2c_init(void) {
	i2cfd = open("/dev/i2c-0",O_RDWR);
	if (i2cfd < 0) {
		printf("Cannot open the I2C device\n");
		return 1;
	}

	return 0;
}

int i2c_set(uint8_t addr, uint8_t val) {
	uint8_t buffer[2] = {addr,val};

	if (ioctl(i2cfd,I2C_SLAVE_FORCE,IIC_SLAVE_ADDR) < 0) {
		printf("Could not set the I2C slave address\n");
		return 1;
	}

	if (write(i2cfd,buffer,2) != 2) {
		printf("I2C write error\n");
		return 1;
	}

	return 0;
}

int i2c_get(uint8_t addr, uint8_t *val) {
	if (ioctl(i2cfd,I2C_SLAVE_FORCE,IIC_SLAVE_ADDR) < 0) {
		printf("Could not set the I2C slave address\n");
		return 1;
	}

	if (write(i2cfd,&addr,1) != 1) {
		printf("I2C write address error\n");
		return 1;
	}
	if (read(i2cfd,val,1) != 1) {
		printf("I2C read error\n");
		return 1;
	}

	return 0;
}

int hdmi_init(int pxclock, int vfreq, int pixperline, int nlines) {
	uint8_t buffer[4];

	i2c_init();

	/* Initialize TPI mode */
	if (i2c_set(0xc7,0) != 0) return 1;

	/* TPI Identification registers */
	/* Device ID */
	if (i2c_get(0x1b,&buffer[0]) != 0) return 1;
	/* Device Production Revision ID */
	if (i2c_get(0x1c,&buffer[1]) != 0) return 1;
	/* TPI Revision ID */
	if (i2c_get(0x1d,&buffer[2]) != 0) return 1;
	/* HDCP Revision */
	if (i2c_get(0x30,&buffer[3]) != 0) return 1;

	if (buffer[0]!=0xb0 || buffer[1]!=0x02 || buffer[2]!=0x03 || buffer[3]!=0x00) {
		printf("Failed identification of HDMI transmitter\n");
		return 1;
	}

	// Power State Control, full operation
	if (i2c_set(0x1e,0x00) != 0) return 1;
	// InputBusFmt, 1x1 pixel repetition, rising edge of clock
	if (i2c_set(0x08,0x70) != 0) return 1;

	// 8-bit color depth, RGB
	if (i2c_set(0x09,0x00) != 0) return 1;
	// Output format, RGB
	if (i2c_set(0x0a,0x00) != 0) return 1;

	// External sync, no sync adjust
	if (i2c_set(0x60,0x04) != 0) return 1;
	// Interrupts : hot plug
	if (i2c_set(0x3c,0x01) != 0) return 1;
	// No TMDS, enable HDMI output mode
	if (i2c_set(0x1a,0x11) != 0) return 1;

	// Pixel clock in multiples of 0.01 MHz e.g. 14850 -> 148.5 MHz
	if (i2c_set(0x00,pxclock) != 0) return 1;
	if (i2c_set(0x01,pxclock>>8) != 0) return 1;
	// VFreq in 0.01 Hz e.g. 5000 -> 50 Hz
	if (i2c_set(0x02,vfreq) != 0) return 1;
	if (i2c_set(0x03,vfreq>>8) != 0) return 1;
	// Pixels per line
	if (i2c_set(0x04,pixperline) != 0) return 1;
	if (i2c_set(0x05,pixperline>>8) != 0) return 1;
	// Total lines
	if (i2c_set(0x06,nlines) != 0) return 1;
	if (i2c_set(0x07,nlines>>8) != 0) return 1;
	// InputBusFmt, 1x1 pixel repetition, rising edge of clock
	if (i2c_set(0x08,0x70) != 0) return 1;
	// TMDS active, enable HDMI output mode
	if (i2c_set(0x1a,0x01) != 0) return 1;

	return 0;
}

struct input_event {
	struct timeval time;
	unsigned short type;
	unsigned short code;
	unsigned int value;
};

volatile int thr_kbd_end = 0;
void * thread_kbd(void * arg) {
	unsigned int mx=0,my=0;
	int dx=0,dy=0;
	struct pollfd pfd[256];
	DIR *dd = opendir("/dev/input");
	int nfds = 0;
	struct dirent *e;

	while ((e=readdir(dd))!=NULL) {
		if (strncmp(e->d_name,"event",5)==0) {
			char buf[267];
			sprintf(buf,"/dev/input/%s",e->d_name);
			pfd[nfds].fd = open(buf,O_RDONLY);
			pfd[nfds].events = POLLIN;
			++nfds;
		}
	}

	static const char *ev_type_names[] = { "EV_SYN", "EV_KEY", "EV_REL", "EV_ABS", "EV_MSC", "EV_SW" };

	while (thr_kbd_end == 0) {
		int retval = poll(pfd,nfds,1);
		if (retval == -1) {
			break;
		} else if (retval>0) {
			int i;
			for (i=0; i<nfds; ++i) {
				if ((pfd[i].revents&POLLIN) != 0) {
					struct input_event ie[256];
					ssize_t sz = read(pfd[i].fd,ie,sizeof(ie));
					int count = sz/sizeof(struct input_event);
					int e;
					for (e=0; e<count; ++e) {
						struct input_event *ev = &ie[e];
						char buf[64];
						const char *type;
						if (ev->type<=5) {
							type = ev_type_names[ev->type];
						} else {
							sprintf(buf,"%d",ev->type);
							type = buf;
						}
						printf("Type:%s code:%d val:%d\n",type,(int)ev->code,(int)ev->value);
					}
					for (e=0; e<count; ++e) {
						int val = (int)ie[e].value;
						int key;
						switch (ie[e].type) {
						case EV_REL:
							if (ie[e].code == 0) {
								dx -= val;
							} else {
								dy -= val;
							}
							break;
						case EV_KEY:
							key = -1;
							switch (ie[e].code) {
								case BTN_LEFT: key = 122; break;
								case BTN_RIGHT: key = 127; break;
							}
							if (key!=-1) {
								parmreg[4+key/32] = (parmreg[4+key/32] & ~(1<<key%32)) | (!val)<<(key%32);
							}
						}
					}
				}
			}
		} else {
			// timeout
			if (dx>=2) { mx=(mx+1)&3; dx-=2; }
			if (dx<=-2) { mx=(mx+3)&3; dx+=2; }
			if (dy>=2) { my=(my+1)&3; dy-=2; }
			if (dy<=-2) { my=(my+3)&3; dy+=2; }
			int x = (mx>>1)^mx;
			int y = (my>>1)^my;
			parmreg[7] = (parmreg[7] & 0xfc3fffff) | x<<22 | y<<24;
		}
	}
	return NULL;
}

int main(int argc, char **argv) {
	int Status;

	printf("Shifter + HDMI + DDR + CPU test\n");
	if (argc != 2) {
		printf("usage: %s boot68k.bin\n",argv[0]);
		return 1;
	}
	const char *binfilename = argv[1];

	int uiofd = open("/dev/uio0",O_RDWR);
	if (uiofd < 0) {
		printf("Cannot open UIO device\n");
		return 1;
	}
	parmreg = mmap(0,0x20,PROT_READ|PROT_WRITE,MAP_SHARED,uiofd,0);
	if (parmreg == MAP_FAILED) {
		printf("Cannot map UIO device\n");
		return 1;
	}
	parmreg[0] = 0;	/* software reset signal */

	int memfd = open("/dev/mem",O_RDWR|O_SYNC);
	if (memfd < 0) {
		printf("Cannot open memory device\n");
		return 1;
	}
	uint8_t *mem_array = mmap(NULL,ST_MEM_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,memfd,ST_MEM_ADDR);
	parmreg[1] = ST_MEM_ADDR;

	/* Initialize HDMI, set up 1080p50 RGB mode */
	// Status = hdmi_init(14850,5000,2200,1350);
	/* 1080p60 */
	// Status = hdmi_init(14850,6000,2200,1125);
	/* 576p */
	Status = hdmi_init(3200,5000,1024,625);
	if (Status != 0) {
		printf("HDMI setup Failed\n");
		return 1;
	}

	printf("HDMI setup successful\n");
	memset(mem_array+0xfa0000,0xff,0x20000);
	int cfg = 3;		/* end reset */
	int c;
	pthread_t kbd_thr;
	pthread_create(&kbd_thr,NULL,thread_kbd,NULL);
	do {
		memset(mem_array,0,0x20000);
		FILE *bootfd = fopen(binfilename,"rb");
		fread(mem_array+0xfc0000,1,0x30000,bootfd);
		fclose(bootfd);
		memcpy(mem_array,mem_array+0xfc0000,8);
		int i;
		for (i=4; i<8; ++i) {
			parmreg[i] = 0xffffffff;
		}

		parmreg[0] = cfg;
		c = getchar();
		printf("new reset\n");
		parmreg[0] = 0;
		usleep(10000);
		cfg = 4^cfg;
	} while (c!='q');
	thr_kbd_end = 1;
	pthread_join(kbd_thr,NULL);

	return 0;
}
