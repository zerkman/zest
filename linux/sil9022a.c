/*
 * sil9022a.c - Setup code for the sil9022a HDMI transmitter
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

#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>

#include <linux/i2c-dev.h>
#include <linux/i2c.h>
#define HDMI_TX_ADDR 0x3b


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

int i2c_set_timeout(int timeout) {
  if (ioctl(i2cfd,I2C_TIMEOUT,timeout)<0) {
    printf("I2C set timeout failed\n");
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
    // printf("I2C RDWR read transaction failed\n");
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
    // printf("I2C RDWR write transaction failed\n");
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

int hdmi_init(void) {
  uint8_t tpi_id[3];

  if (i2c_init()) return 1;

  if (i2c_set_timeout(10)) return 1;

  /* Initialize TPI mode */
  if (i2c_set(0xc7,0) != 0) return 1;

  /* TPI Identification registers */
  if (i2c_read(0x1b,3,tpi_id) != 0) return 1;

  if (tpi_id[0]!=0xb0      /* Device ID */
    || tpi_id[1]!=0x02     /* Device Production Revision ID */
    || tpi_id[2]!=0x03)    /* TPI Revision ID */
  {
    /* Wrong identification = failed to identify the sil9022a chip */
    return 1;
  }

  if (i2c_set_timeout(100)) return 1;

  return 0;
}

int hdmi_set_mode(int pxclock, int vfreq, int pixperline, int nlines) {
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
    0xbf,    // offset
    0xc2,    // 0xbf: IF select = audio, enable, repeat
    0x84,    // 0xc0: IF type
    0x01,    // 0xc1: IF version
    0x0a,    // 0xc2: IF length
    0x00,    // 0xc3: IF checksum
    0x11,    // audio format = PCM, 2 channels
    0x0d,    // 48 kHz, 16 bit
    0x00,    // no audio format code extension
    0x00,    // channel 1 = front left, channel 2 = front right
    0x00,    // 0dB attenuation, downmix inhibit off, no LFE playback info
    0x00,    // data byte 6, reserved
    0x00,    // data byte 7, reserved
    0x00,    // data byte 8, reserved
    0x00,    // data byte 9, reserved
    0x00,    // data byte 10, reserved
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
