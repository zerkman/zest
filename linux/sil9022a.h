/*
 * sil9022a.h - Setup code for the sil9022a HDMI transmitter
 *
 * Copyright (c) 2020-2022 Francois Galea <fgalea at free.fr>
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


#ifndef __SIL9022A_H__
#define __SIL9022A_H__


int hdmi_init(int pxclock, int vfreq, int pixperline, int nlines);


int hdmi_stop(void);


#endif
