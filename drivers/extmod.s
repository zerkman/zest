; extmod.s - Extended modes - Enable zeST's extended video modes on the GEM desktop
;
; Copyright (c) 2023-2025 Francois Galea <fgalea at free.fr>
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

	opt	o+,p=68000

	section	text


begin:
	bra	install

	dc.b	'XBRA'
	dc.b	'xmod'
old_gem	dc.l	0
my_gem:
	cmp	#$73,d0		; VDI call ?
	bne.s	mgde		; no: back to system code

	move.l	d1,a0		; global array
	move.l	(a0),a0		; control array
	cmp	#1,(a0)		; v_opnwk() (control[0]==1) ?
	beq.s	v_opnwk
	cmp	#2,(a0)		; v_clswk() ?
	beq.s	v_clswk

mgde:	move.l	old_gem(pc),a0
	jmp	(a0)

v_clswk:
	move.l	d1,a0		; global array
	move.l	4(a0),a0	; intin array
	cmp	#2+2+1,(a0)	; if peripheral number too high (> 2+max res)
	bpl	mgde		; then it's not a standard screen mode
	tst	(a0)		; if too low
	ble	mgde		; no good either

	bclr.b	#2,$ffff8260.w	; disable extended bit

	bra	mgde

v_opnwk:
	move.l	d1,a0		; global array
	move.l	4(a0),a0	; int_in array
	cmp	#2+2+1,(a0)	; if peripheral number too high (> 2+max res)
	bpl	mgde		; then it's not a standard screen mode
	tst	(a0)		; if too low
	ble	mgde		; no good either

	move.l	d1,a0		; global array
	move.l	12(a0),-(sp)	; int_out array

	pea	post_opnwk(pc)	; create a stack frame so return address from VDI comes back to our code
	move	sr,-(sp)	;
	bra	mgde

; Portion of code that is called after standard VDI v_opnwk return
post_opnwk:

	moveq	#3,d0
	and.b	$ffff8260.w,d0	; get screen mode
	move	d0,d1

	move.l	$462.w,a0	; _vbclock
wtvbl:	cmp.l	$462.w,a0	; wait for new VBL
	beq.s	wtvbl

	bset	#2,d0
	move.b	d0,$ffff8260.w	; enable extended mode

	lsl	#4,d1		; mode*16

	move.l	$44e.w,a0	; logical screen base (_v_bas_ad)
	suba.w	mdata+12(pc,d1.w),a0	; corrected screen address
	move.l	a0,$44e.w	; new logical screen base
	move.l	a0,d0
	lsr.w	#8,d0
	move.l	d0,$ffff8200.w	; physical screen address

	dc.w	$a000		; get Line-A structure address in a0
	move.l	(sp)+,a1	; int_out array
	move	mdata+0(pc,d1.w),d0	; screen width
	move	d0,-12(a0)	; horizontal pixel resolution
	subq	#1,d0
	move	d0,(a1)		; max X coord
	move	d0,-692(a0)	; max X coord (width-1)

	move	mdata+2(pc,d1.w),d0	; screen height
	move	d0,-4(a0)	; vertical pixel resolution
	subq	#1,d0
	move	d0,2(a1)	; max Y coord
	move	d0,-690(a0)	; max Y coord (height-1)

	move	mdata+4(pc,d1.w),d0	; bytes per scanline
	move	d0,2(a0)		; bytes/scanline
	move	d0,-2(a0)		; bytes per screen line

	move	mdata+6(pc,d1.w),-44(a0)	; number of VT52 characters per line -1

	;move	-46(a0),d0		; text cell height (8 or 16)

	move	mdata+8(pc,d1.w),-40(a0)	; VT52 text line size in bytes
	move	mdata+10(pc,d1.w),d0	; number of VT52 text lines
	subq	#1,d0
	move	d0,-42(a0)		; Number of VT52 text lines -1

	rte

; Extended screen mode data values in order, and offsets
; - 0:screen width in pixels
; - 2:screen height in pixels
; - 4:number of bytes per scanline
; - 6:number of VT52 characters per line
; - 8:VT52 text line size in bytes
; - 10:number of VT52 text lines
; - 12:number of extra screen size bytes (including padding for 256B alignment)
; - 14:reserved dummy value, left to 0
mdata:
	dc.w	416,276,208, 52,1664,34,25600,0	; low resolution
	dc.w	832,276,208,104,1664,34,25600,0	; medium resolution

end_resident:

install:
	lea	hello_txt(pc),a0
	bsr	cconws

	pea	install_super(pc)
	move	#38,-(sp)	; Supexec
	trap	#14
	addq.l	#6,sp

	tst	d0
	beq.s	do_install

	lea	hires_txt(pc),a0
	subq	#1,d0		; Was the error code 1 ?
	beq.s	noinstall	; Yes - high resolution error

	lea	noextmod_txt(pc),a0
	bra.s	noinstall	; Otherwise, zeST has disabled extended modes


do_install:
	clr	-(sp)
	move.l	#end_resident-begin+256,-(sp)
	move	#$31,-(sp)	; Ptermres
	trap	#1

; exit without installing
noinstall:
	bsr	cconws		; print the error message
	clr	-(sp)
	trap	#1

install_super:
	moveq	#3,d0
	and.b	$ffff8260.w,d0	; screen mode
	cmp.b	#2,d0
	bne.s	_is1		; don't install on high resolution
	moveq	#1,d0
	rts

_is1:
	move.l	$462.w,a0	; _vbclock
i1wvbl:	cmp.l	$462.w,a0	; wait for new VBL
	beq.s	i1wvbl

	bset.b	#2,$ffff8260.w	; test enabling extended mode
	btst.b	#2,$ffff8260.w	; test if mode is activated
	bne.s	_is2		; don't install if mode is not activated
	moveq	#2,d0
	rts

_is2:
	move.b	d0,$ffff8260.w	; set the mode back to normal for now

	move.l	$88.w,old_gem
	move.l	#my_gem,$88.w	; AES/VDI (Trap #2) vector

	moveq	#0,d0
	move	mdata+12(pc),d0	; Extra screen bytes for mode 0
	move	mdata+28(pc),d1	; Extra screen bytes for mode 1
	cmp	d1,d0
	bcc.s	foundmax
	move	d1,d0		; maximum extra screen size
foundmax:

	move.l	$436.w,a0	; _memtop
	move.l	a0,a3		; save old value
	sub.l	d0,a0		; fix _memtop so it points before screen memory
	move.l	a0,$436.w

; Look for our program's MD (memory descriptor)
; To our knowledge, there is no known standard way to find the MPB (Memory
; Parameter Block) that has been initialised at boot.
; Hence we directly search for our MD by scanning the system memory.
	lea	begin-256(pc),a0	; basepage address
	sub.l	a0,a3		; current block size value
	lea	$2004.w,a1	; TOS internal variables
	move.l	$432.w,a2	; _membot
	sub.l	#12,a2		; remove size of MD
mdsearch_lp:
	cmp.l	(a1),a0		; Block address
	bne.s	.cont
	cmp.l	4(a1),a3	; Block size
	beq.s	mdsearch_found
.cont	addq.l	#2,a1
	cmp.l	a2,a1
	ble.s	mdsearch_lp
	bra.s	mdsearch_notfound

; Here we shrink the allocated buffer size for our program.
; Since we are now using a larger video memory buffer, we need to inform the
; system that a part of memory is not available anymore for allocation.
; Our program's memory has been allocated by Malloc, and the normal system
; behaviour is to allocate the largest available block of memory for any new
; program. When the program quits, the memory block will become a free block,
; so changing our program's memory descriptor will also affect the largest
; free block after program termination.
mdsearch_found:
	sub.l	d0,4(a1)	; Shrink block size

; if not found (should not happen!), do nothing
mdsearch_notfound:
	moveq	#0,d0
	rts

cconws:
	move.l	a0,-(sp)
	move	#9,-(sp)	; Cconws
	trap	#1
	addq.l	#6,sp
	rts

	section data
hello_txt:	dc.b	13,10
		dc.b	27,"p- zeST extended screen modes v0.2 -",27,"q",13,10
		dc.b	"by Fran",$87,"ois Galea",13,10,0
hires_txt:	dc.b	"does not work in high resolution!",13,10,0
noextmod_txt:	dc.b	"extended modes are disabled!",13,10,0
	even
