/*
 * setup.h - Setup code for PL / Linux on Z-Turn board
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

#ifndef __SETUP_H__
#define __SETUP_H__

// Cold reset
void cold_reset();

// Warm Reset
void warm_reset();

// Set wakestate (ws=1-4)
void set_wakestate(int ws);

// Get current wakestate (1-4)
int get_wakestate(void);

// Load ROM file
// returns 0 on success
int load_rom(const char *filename);


#endif

