/*
 * floppy.h - floppy drive emulation (software part)
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


#ifndef __FLOPPY_H__
#define __FLOPPY_H__

// change or eject the floppy disk
// if filename is NULL, eject the disk
// drive = 0 (drive A) or 1 (drive B)
void change_floppy(const char *filename, int drive);

void get_floppy_status(unsigned int *r, unsigned int *w, unsigned int *track, unsigned int *side);

#endif
