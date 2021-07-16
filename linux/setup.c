/*
 * setup.c - Setup code for PL / Linux on Z-Turn board
 *
 * Copyright (c) 2020,2021 Francois Galea <fgalea at free.fr>
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
#include <linux/i2c.h>

/* from floppy.c */
void * thread_floppy(void * arg);

/*
 * The slave address to send to and receive from.
 */

#define HDMI_TX_ADDR 0x3b

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

int i2c_read(uint8_t offset, unsigned int size, uint8_t *buffer) {
	struct i2c_msg msgs[2] = {
		{.addr = HDMI_TX_ADDR, .flags = 0, .len = 1, .buf = &offset},
		{.addr = HDMI_TX_ADDR, .flags = 1, .len = size, .buf = buffer}
	};
	struct i2c_rdwr_ioctl_data data = {.msgs = msgs, .nmsgs = 2};
	if (ioctl(i2cfd,I2C_RDWR,&data)<0) {
		printf("I2C RDWR read transaction failed\n");
		return 1;
	}
	return 0;
}

int i2c_write(unsigned int size, uint8_t *buffer) {
	struct i2c_msg msg = {
		.addr = HDMI_TX_ADDR, .flags = 0, .len = size, .buf = buffer
	};
	struct i2c_rdwr_ioctl_data data = {.msgs = &msg, .nmsgs = 1};
	if (ioctl(i2cfd,I2C_RDWR,&data)<0) {
		printf("I2C RDWR write transaction failed\n");
		return 1;
	}
	return 0;
}

int i2c_set(uint8_t offset, uint8_t val) {
	uint8_t buf[2] = { offset, val };
	return i2c_write(2,buf);
}

int i2c_get(uint8_t offset, uint8_t *val) {
	return i2c_read(offset,1,val);
}

int hdmi_init(int pxclock, int vfreq, int pixperline, int nlines) {
	uint8_t tpi_id[3];

	i2c_init();

	/* Initialize TPI mode */
	if (i2c_set(0xc7,0) != 0) return 1;

	/* TPI Identification registers */
	if (i2c_read(0x1b,3,tpi_id) != 0) return 1;

	if (tpi_id[0]!=0xb0			/* Device ID */
		|| tpi_id[1]!=0x02		/* Device Production Revision ID */
		|| tpi_id[2]!=0x03)		/* TPI Revision ID */
	{
		printf("Failed identification of HDMI transmitter\n");
		return 1;
	}

	// No TMDS, enable HDMI output mode
	if (i2c_set(0x1a,0x11) != 0) return 1;

	// External sync, no sync adjust
	if (i2c_set(0x60,0x04) != 0) return 1;
	// Interrupts : hot plug
	if (i2c_set(0x3c,0x01) != 0) return 1;

	// Power State Control, full operation
	if (i2c_set(0x1e,0x00) != 0) return 1;

	uint8_t vmode_pxfmt[12] = {
		// offset: video mode
		0,
		// 0: Pixel clock in multiples of 0.01 MHz e.g. 14850 -> 148.5 MHz
		pxclock, pxclock>>8,
		// 2: VFreq in 0.01 Hz e.g. 5000 -> 50 Hz
		vfreq, vfreq>>8,
		// 4: Pixels per line
		pixperline, pixperline>>8,
		// 6: Total lines
		nlines, nlines>>8,
		// 8: InputBusFmt, 1x1 pixel repetition, rising edge of clock
		0x70,
		// 9: 8-bit color depth, RGB
		0x00,
		// 10: Output format, RGB
		0x00,
	};
	if (i2c_write(12,vmode_pxfmt) != 0) return 1;

	// Audio interface = I2S, 2-channel, Mute on, PCM
	if (i2c_set(0x26,0x91) != 0) return 1;
	// I2S Config, SCK sample at rising edge, 128*?MCLK multiplier, WS low=left,
	// SD justify left, 1st byte is MSB, WS to SD 1st bit shift
	if (i2c_set(0x20,0x80) != 0) return 1;
	// Connect SD0 pin to FIFO #0, no downsampling, no swap
	if (i2c_set(0x1f,0x80) != 0) return 1;
	// 16-bit mode (ignored?), 48 kHz sample frequency
	if (i2c_set(0x27,0x58) != 0) return 1;
	// Stream header settings for I2S

	if (i2c_set(0x21,0) != 0) return 1;
	if (i2c_set(0x22,0) != 0) return 1;
	if (i2c_set(0x23,0) != 0) return 1;
	if (i2c_set(0x24,2) != 0) return 1;
	if (i2c_set(0x25,2) != 0) return 1;

	// InfoFrame Data
	uint8_t audio_infoframe_cmd[16] = {
		0xbf,		// offset
		0xc2,		// 0xbf: IF select = audio, enable, repeat
		0x84,		// 0xc0: IF type
		0x01,		// 0xc1: IF version
		0x0a,		// 0xc2: IF length
		0x00,		// 0xc3: IF checksum
		0x11,		// audio format = PCM, 2 channels
		0x0d,		// 48 kHz, 16 bit
		0x00,		// no audio format code extension
		0x00,		// channel 1 = front left, channel 2 = front right
		0x00,		// 0dB attenuation, downmix inhibit off, no LFE playback info
		0x00,		// data byte 6, reserved
		0x00,		// data byte 7, reserved
		0x00,		// data byte 8, reserved
		0x00,		// data byte 9, reserved
		0x00,		// data byte 10, reserved
	};
	unsigned int checksum = 0;
	int i;
	for (i=2; i<16; ++i) checksum += audio_infoframe_cmd[i];
	audio_infoframe_cmd[5] = 0x100-(checksum&0xff);
	if (i2c_write(16,audio_infoframe_cmd) != 0) return 1;

	// Audio interface = I2S, 2-channel, Mute off, PCM
	if (i2c_set(0x26,0x81) != 0) return 1;

	// TMDS active, enable HDMI output mode
	if (i2c_set(0x1a,0x01) != 0) return 1;

	return 0;
}

int hdmi_stop(void) {
	// Audio interface = I2S, 2-channel, Mute on, PCM
	if (i2c_set(0x26,0x91) != 0) return 1;

	// TMDS down, mute HDMI AV
	if (i2c_set(0x1a,0x19) != 0) return 1;

	return 0;
}

struct input_event {
	struct timeval time;
	unsigned short type;
	unsigned short code;
	unsigned int value;
};

int uiofd;
void * thread_uio(void * arg) {
	uint32_t n;
	int s;
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
		} else {
			printf("ok %d\n",(int)n);
		}
	} while (s!=0);
	printf("out\n");
	return NULL;
}

volatile int thr_end = 0;
void * thread_kbd(void * arg) {
	unsigned int mx=0,my=0;
	int dx=0,dy=0,ox=0,oy=0;
	int timeout = 100;
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

	while (thr_end == 0) {
		int retval = poll(pfd,nfds,timeout);
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
						if (ev->type==EV_SYN || ev->type==EV_KEY || ev->type==EV_REL || ev->type==EV_MSC) continue;
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
							timeout = 0;
							break;
						case EV_KEY:
							key = -1;
							switch (ie[e].code) {
								case KEY_F1:
								case KEY_F2:
								case KEY_F3:
								case KEY_F4:
								case KEY_F5:
								case KEY_F6:
								case KEY_F7:
								case KEY_F8:
								case KEY_F9:
								case KEY_F10: key = ie[e].code-KEY_F1; break;
								case KEY_F11: key = 10; break;		// help
								case KEY_F12: key = 11; break;		// undo
								// key 12 - numeric pad [(] not mapped
								case KEY_KPSLASH: key = 13; break;
								case KEY_ESC: key = 14; break;
								case KEY_2: key = 15; break;
								case KEY_4: key = 16; break;
								case KEY_6: key = 17; break;
								case KEY_8: key = 18; break;
								case KEY_0: key = 19; break;
								case KEY_EQUAL: key = 20; break;
								case KEY_BACKSPACE: key = 21; break;
								case KEY_UP: key = 22; break;
								// key 23 - numeric pad [)] not mapped
								case KEY_KPASTERISK: key = 24; break;
								case KEY_1: key = 25; break;
								case KEY_3: key = 26; break;
								case KEY_5: key = 27; break;
								case KEY_7: key = 28; break;
								case KEY_9: key = 29; break;
								case KEY_MINUS: key = 30; break;
								case KEY_GRAVE: key = 31; break;
								case KEY_DELETE: key = 32; break;
								case KEY_HOME: key = 33; break;
								case KEY_KP7: key = 34; break;
								case KEY_KP9: key = 35; break;
								case KEY_TAB: key = 36; break;
								case KEY_W: key = 37; break;
								case KEY_R: key = 38; break;
								case KEY_Y: key = 39; break;
								case KEY_U: key = 40; break;
								case KEY_O: key = 41; break;
								case KEY_LEFTBRACE: key = 42; break;
								case KEY_INSERT: key = 43; break;
								case KEY_LEFT: key = 44; break;
								case KEY_KP8: key = 45; break;
								case KEY_KPMINUS: key = 46; break;
								case KEY_LEFTCTRL:
								case KEY_RIGHTCTRL: key = 47; break;
								case KEY_Q: key = 48; break;
								case KEY_E: key = 49; break;
								case KEY_T: key = 50; break;
								case KEY_G: key = 51; break;
								case KEY_I: key = 52; break;
								case KEY_P: key = 53; break;
								case KEY_RIGHTBRACE: key = 54; break;
								case KEY_BACKSLASH: key = 55; break;
								case KEY_DOWN: key = 56; break;
								case KEY_KP4: key = 57; break;
								case KEY_KP6: key = 58; break;
								case KEY_LEFTSHIFT: key = 59; break;
								case KEY_A: key = 60; break;
								case KEY_S: key = 61; break;
								case KEY_F: key = 62; break;
								case KEY_H: key = 63; break;
								case KEY_J: key = 64; break;
								case KEY_L: key = 65; break;
								case KEY_SEMICOLON: key = 66; break;
								case KEY_ENTER: key = 67; break;
								case KEY_RIGHT: key = 68; break;
								case KEY_KP5: key = 69; break;
								case KEY_KPPLUS: key = 70; break;
								case KEY_LEFTALT:
								case KEY_RIGHTALT: key = 71; break;
								case KEY_102ND: key = 72; break;
								case KEY_D: key = 73; break;
								case KEY_C: key = 74; break;
								case KEY_B: key = 75; break;
								case KEY_K: key = 76; break;
								case KEY_COMMA: key = 77; break;
								case KEY_DOT: key = 78; break;
								case KEY_APOSTROPHE: key = 79; break;
								case KEY_KP1: key = 80; break;
								case KEY_KP2: key = 81; break;
								case KEY_KP3: key = 82; break;
								case KEY_RIGHTSHIFT: key = 83; break;
								case KEY_Z: key = 84; break;
								case KEY_X: key = 85; break;
								case KEY_V: key = 86; break;
								case KEY_N: key = 87; break;
								case KEY_M: key = 88; break;
								case KEY_SPACE: key = 89; break;
								case KEY_CAPSLOCK: key = 90; break;
								case KEY_SLASH: key = 91; break;
								case KEY_KP0: key = 92; break;
								case KEY_KPDOT: key = 93; break;
								case KEY_KPENTER: key = 94; break;
								case BTN_LEFT: key = 122; break;
								case BTN_RIGHT: key = 127; break;
								// default:
								// 	printf("Key code:%d val:%d\n",(int)ie[e].code,(int)ie[e].value);
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
			timeout = 100;
			if (dx>=2) {
				if (ox==1 && dx>=4) {
					mx = (mx+2)&3;
					dx -= 4;
				}
				else {
					mx = (mx+1)&3;
					dx -= 2;
					ox = 1;
				}
				timeout = 1;
			}
			if (dx<=-2) {
				if (ox==-1 && dx<=-4) {
					mx = (mx+2)&3;
					dx += 4;
				}
				else {
					mx = (mx+3)&3;
					dx += 2;
					ox = -1;
				}
				timeout = 1;
			}
			if (dy>=2) {
				if (oy==1 && dy>=4) {
					my = (my+2)&3;
					dy -= 4;
				}
				else {
					my = (my+1)&3;
					dy -= 2;
					oy = 1;
				}
				timeout = 1;
			}
			if (dy<=-2) {
				if (oy==-1 && dy<=-4) {
					my = (my+2)&3;
					dy += 4;
				}
				else {
					my = (my+3)&3;
					dy += 2;
					oy = -1;
				}
				timeout = 1;
			}
			int x = (mx>>1)^mx;
			int y = (my>>1)^my;
			parmreg[7] = (parmreg[7] & 0xfc3fffff) | x<<22 | y<<24;
		}
	}
	return NULL;
}

int usage(const char *progname) {
	printf("usage: %s [OPTIONS] rom.img [floppy.mfm]\n\n"
		"OPTIONS are:\n"
		" --color     Set video to color mode (default)\n"
		" --mono      Set video to monochrome mode\n"
		" --mem=VAL   Choose memory size\n"
		"             Possible values: 256K, 512K, 1M (default), 2M, 2.5M, 4M\n"
		, progname);
	return 1;
}

int main(int argc, char **argv) {
	int Status;
	int cfg_video = CFG_COLR;
	int cfg_mem = CFG_1M;

	const char *binfilename = NULL;
	const char *floppyfilename = NULL;
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
			} else return usage(argv[0]);
		}
		else if (binfilename == NULL) {
			binfilename = arg;
		} else if (floppyfilename == NULL) {
			floppyfilename = arg;
		} else {
			return usage(argv[0]);
		}
	}
	if (binfilename == NULL) {
		usage(argv[0]);
		return 1;
	}
	int cfg = cfg_mem | cfg_video | 3;		/* end reset */

	uiofd = open("/dev/uio0",O_RDWR);
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
	if (cfg & CFG_MONO) {
		/* Mono */
		Status = hdmi_init(3200,7129,896,501);
	} else {
		/* 576p */
		Status = hdmi_init(3200,5000,1024,625);
	}
	if (Status != 0) {
		printf("HDMI setup Failed\n");
		return 1;
	}

	printf("HDMI setup successful\n");
	memset(mem_array+0xfa0000,0xff,0x20000);
	int c;
	pthread_t kbd_thr;
	pthread_create(&kbd_thr,NULL,thread_kbd,NULL);
	pthread_t floppy_thr;
	pthread_create(&floppy_thr,NULL,thread_floppy,(void*)floppyfilename);
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
	} while (c!='q');
	thr_end = 1;
	pthread_join(kbd_thr,NULL);
	pthread_join(floppy_thr,NULL);
	hdmi_stop();

	return 0;
}
