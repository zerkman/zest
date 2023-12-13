/*
 * hdd.h - hard disk drive emulation (software part)
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

#ifndef __HDD_H__
#define __HDD_H__

void hdd_init(volatile uint32_t *parmreg);

void hdd_exit(void);

void hdd_interrupt(void);

void hdd_changeimg(char *full_pathname);

#endif

