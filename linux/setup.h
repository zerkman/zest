/*
 * setup.h - Setup code for PL / Linux on Zynq board
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

#ifndef __SETUP_H__
#define __SETUP_H__

// Cold reset
void cold_reset();

// Warm Reset
void warm_reset();

// Update hardware flags (wakestates, ext. video mode) according to config
void setup_update();

// Load ROM file
// returns 0 on success
int load_rom(const char *filename);

// get sound volume (0-31)
int get_sound_vol(void);

// set sound volume (x=0-31)
void set_sound_vol(int x);

// get sound mute state (0:unmuted, 1:muted)
int get_sound_mute(void);

// set sound mute state (0:unmute, other:mute)
void set_sound_mute(int x);


#endif
