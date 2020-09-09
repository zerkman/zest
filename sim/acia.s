; acia.s - test for ACIA access

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

	dc.l	$300
	dc.l	$8

	move.w	#$2700,sr

	lea	$fffffc00.w,a0
	move.b	#$3,(a0)
	move.b	#$18,(a0)

	move.b	#$96,2(a0)
ts	move.b	(a0),d0
	btst	#1,d0
	beq.s	ts

lp	bra.s	lp
