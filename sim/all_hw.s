; all_hw.s - general hardware test

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

	move.l	sp,d0
	lsr.w	#8,d0
	move.l	d0,$ffff8200.w

	move.b	#5,$ffff8001.w

	lea	$fffffc00.w,a0
	move.b	#$3,(a0)
	move.b	#$96,(a0)

	move.b	#$00,$fffffa03.w	; aer
	move.b	#$00,$fffffa05.w	; ddr
	move.b  #$48,$fffffa17.w        ; vr
	move.b  #$40,$fffffa09.w        ; ierb
	move.b  #$40,$fffffa15.w        ; imrb

	lea	acia_itr(pc),a0
	move.l	a0,$118.w

	move.w	#$2500,sr

	moveq	#0,d0

	move.b	d0,$ffff8800.w
	move.b	d0,$ffff8802.w

	move	d0,$ffff8240.w
	move.b	#2,$ffff820a.w


lp	bra.s	lp

acia_itr:
	move.b	$fffffc02.w,8.w
	move.b	#$bf,$fffffa11.w	; isrb
	rte
