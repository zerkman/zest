; display_checker.s - setup video to display a checker pattern

; Copyright (c) 2020 Francois Galea <fgalea at free.fr>
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.

	dc.l	$1234
	dc.l	$fc0008

	lea	$0300.w,sp
	movea.l	sp,a0
	move.l	a0,d0
	lsr.w	#8,d0
	move.l	d0,$ffff8200.w
	move.w	#$777,$ffff8240.w
	clr.w	$ffff825e.w

	move.l	#$ff00ff,d0
	moveq	#$18,d1
loop1:
	moveq	#7,d2
loop2:
	moveq	#9,d3
loop3:
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	dbra	d3,loop3
	dbra	d2,loop2
	not.l	d0
	dbra	d1,loop1
loop4:
	bra.s	loop4
