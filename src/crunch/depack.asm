; Fat Chip 64 - the packed program file's unpacker (v0.41)
; tools/crunch.py lays the program file out as: the code from $0801 as it
; is, up to TAIL_DEST; then the rest of the code, packed; then the $E000
; tables, packed; then this, which the BASIC line SYSes. It unpacks the
; tables to $E000, then the code's tail in place (it reads ahead of where it
; writes all the way: crunch.py checks), and starts the program.
; Packed stream, a byte T at a time:
;   T < $80          T+1 literal bytes follow
;   $80 <= T < $C0   copy (T and $3F) + 2 bytes from d+1 back (one byte d)
;   T >= $C0         copy (T and $3F) + 3 bytes from d back (two bytes d);
;                    d = 0: the end

	processor 6502
	include "params.asm"    ; (from crunch.py: DEP_ORG, TAIL_SRC, TAIL_DEST, HI_SRC, HI_DEST, START)

SRC         equ $FB
DST         equ $FD
MSRC        equ $F9
LEN         equ $F8

	org DEP_ORG
Go:
	sei
	cld
	lda #$35                ; RAM under BASIC and the KERNAL (I/O stays)
	sta $01
	lda #0
	sta $D020               ; (a black border while it works)
	lda #<HI_SRC
	sta SRC
	lda #>HI_SRC
	sta SRC+1
	lda #<HI_DEST
	sta DST
	lda #>HI_DEST
	sta DST+1
	jsr Depack
	lda #<TAIL_SRC
	sta SRC
	lda #>TAIL_SRC
	sta SRC+1
	lda #<TAIL_DEST
	sta DST
	lda #>TAIL_DEST
	sta DST+1
	jsr Depack
	jmp START

Depack:
	ldy #0
.tok:
	lda (SRC),y
	inc SRC
	bne .t1
	inc SRC+1
.t1:
	tax
	bmi .match
	inx                     ; 1-128 literal bytes
.lit:
	lda (SRC),y
	sta (DST),y
	iny
	dex
	bne .lit
	tya                     ; past them
	clc
	adc SRC
	sta SRC
	bcc .l1
	inc SRC+1
.l1:
	tya
	jmp .adv
.match:
	cpx #$C0
	bcs .long
	txa                     ; (carry clear) near: 2-65 bytes, d+1 back
	and #$3F
	adc #2
	sta LEN
	lda DST
	clc
	sbc (SRC),y
	sta MSRC
	lda DST+1
	sbc #0
	sta MSRC+1
	inc SRC
	bne .copy
	inc SRC+1
	bne .copy
.long:
	txa                     ; far: 3-66 bytes, d back
	and #$3F
	clc
	adc #3
	sta LEN
	lda (SRC),y
	iny
	ora (SRC),y
	beq .done
	dey
	lda DST
	sec
	sbc (SRC),y
	sta MSRC
	iny
	lda DST+1
	sbc (SRC),y
	sta MSRC+1
	lda SRC
	clc
	adc #2
	sta SRC
	bcc .copy
	inc SRC+1
.copy:
	ldy #0
.cp:
	lda (MSRC),y
	sta (DST),y
	iny
	cpy LEN
	bne .cp
	tya
.adv:
	clc
	adc DST
	sta DST
	bcc .a1
	inc DST+1
.a1:
	ldy #0
	jmp .tok
.done:
	rts
