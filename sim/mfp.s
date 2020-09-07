; mfp.s - test for MFP operation

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
	dc.l	$fc0008

	move.w	#$2700,sr

	move.l	sp,d0
	lsr.w	#8,d0
	move.l	d0,$ffff8200.w

	lea	vbl(pc),a0
	move.l	a0,$70.w
	lea	timer_a(pc),a0
	move.l	a0,$134.w
	lea	timer_b(pc),a0
	move.l	a0,$120.w
	lea	timer_c(pc),a0
	move.l	a0,$114.w
	lea	mono_detect(pc),a0
	move.l	a0,$13c.w
	move.b	#$48,$fffffa17.w	; vr
	move.b	#$a1,$fffffa07.w	; iera
	move.b	#$20,$fffffa09.w	; ierb
	move.b	#$a1,$fffffa13.w	; imra
	move.b	#$20,$fffffa15.w	; imrb
	move.b	#$10,$fffffa1f.w	; tadr
	move.b	#$03,$fffffa19.w	; tacr (2457600/16/16=9600Hz/104.1666us)
	move.b	#$01,$fffffa21.w	; tbdr
	move.b	#$08,$fffffa1b.w	; tbcr
	move.b	#192,$fffffa23.w	; tcdr
	move.b	#$50,$fffffa1d.w	; tcdcr
	move.w	#$2300,sr

	move.w	#$777,$ffff825e.w
	movea.l	sp,a0
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

vbl:
	clr	$ffff8240.w
	rte

timer_a:
	eor	#$700,$ffff8240.w
	bclr.b	#5,$fffffa0f.w		; isra
	rte

timer_b:
	add	#1,$ffff8240.w
	bclr.b	#0,$fffffa0f.w		; isra
	rte

timer_c:
	eor	#$070,$ffff8240.w
	bclr.b	#5,$fffffa11.w		; isrb
	rte

mono_detect:
	addq	#1,$8.w
	move.b	#$7f,$fffffa0f.w	; isra
	rte
