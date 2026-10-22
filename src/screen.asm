; Fat Chip 64 - screen
;
;  row 0   FAT CHIP 64 header
;  rows 2-7  devices (F1/F3/F5), channels, panic, overlap warning
;  rows 9-18 voice table: which chip voice plays which note
;  row 20  held notes, row 22 RESTORE help, row 23 messages sent, row 24 mode

; Print the 0-terminated ASCII string at (ptr) to screen row Y, column X.
; Letters become screen codes; bit 7 of t2 reverses.
PrintAt:
	subroutine
	jsr ScreenAddr
	ldy #0
.c:
	lda (ptr),y
	beq .done
	cmp #64
	bcc .noLetter
	sec
	sbc #64
.noLetter:
	ora t2
	sta (ptr2),y
	iny
	bne .c
.done:
	rts

; ptr2 = SCREEN + 40*Y + X
ScreenAddr:
	subroutine
	lda #<SCREEN
	sta ptr2
	lda #>SCREEN
	sta ptr2+1
	cpy #0
	beq .col
.row:
	lda ptr2
	clc
	adc #40
	sta ptr2
	bcc .nc
	inc ptr2+1
.nc:
	dey
	bne .row
.col:
	txa
	clc
	adc ptr2
	sta ptr2
	bcc .x
	inc ptr2+1
.x:
	rts

; macro-ish helper: PRINT row, col, label
	mac PRINT
	ldx #{2}
	ldy #{1}
	lda #<{3}
	sta ptr
	lda #>{3}
	sta ptr+1
	jsr PrintAt
	endm

; Put the character in A at column X of the row in ptr2 (ScreenAddr first).
; Keeps X; uses Y.
PutChar:
	subroutine
	pha
	txa
	tay
	pla
	cmp #64
	bcc .nl
	sec
	sbc #64
.nl:
	sta (ptr2),y
	rts

; Decimal 0-99 in A at column X of row ptr2 (one or two digits). Returns X past it.
PutNum:
	subroutine
	ldy #0
.tens:
	cmp #10
	bcc .ones
	sbc #10
	iny
	bne .tens
.ones:
	pha
	tya
	beq .skip
	clc
	adc #'0
	jsr PutChar
	inx
.skip:
	pla
	clc
	adc #'0
	jsr PutChar
	inx
	rts

ScreenInit:
	subroutine
	lda #0
	sta BORDER
	sta BGCOL
	ldx #0
.c:
	lda #32
	sta SCREEN,x
	sta SCREEN+$100,x
	sta SCREEN+$200,x
	sta SCREEN+$2E8,x
	lda #13                 ; light green, a nod to the Game Boy
	sta COLRAM,x
	sta COLRAM+$100,x
	sta COLRAM+$200,x
	sta COLRAM+$2E8,x
	inx
	bne .c
	lda VIC_CTRL1
	ora #$10
	sta VIC_CTRL1
	lda #$15                ; uppercase character set
	sta $D018
	rts

ScreenDrawAll:
	subroutine
	lda #$80
	sta t2
	PRINT 0, 0, txtHeader
	lda #0
	sta t2
	PRINT 2, 0, txtDevices
	PRINT 6, 0, txtPanic
	PRINT 9, 0, txtVoices
	PRINT 22, 0, txtRestore
	PRINT 24, 0, txtMode
	lda #1
	sta screenDirty
	jsr ScreenUpdate
	rts

ScreenUpdate:
	subroutine
	lda #0
	sta t2
	; ---- device lines
	PRINT 3, 0, txtSid
	ldx #DEV_SID
	ldy #3
	jsr OnOff
	PRINT 4, 0, txtGb
	ldx #DEV_GB
	ldy #4
	jsr OnOff
	ldy #4
	lda gbBase
	jsr Channels
	PRINT 5, 0, txtNes
	ldx #DEV_NES
	ldy #5
	jsr OnOff
	ldy #5
	lda nesBase
	jsr Channels
	; overlap warning: both on and |gbBase - nesBase| < 5
	PRINT 7, 0, txtBlank
	lda devOn+DEV_GB
	and devOn+DEV_NES
	beq .vt
	lda gbBase
	sec
	sbc nesBase
	bcs .pos
	eor #$FF
	adc #1
.pos:
	cmp #5
	bcs .vt
	PRINT 7, 0, txtOverlap
.vt:
	; ---- voice table
	ldx #0
.v:
	stx t3
	txa
	clc
	adc #10
	tay
	ldx #0
	lda #0
	sta t2
	jsr ScreenAddr
	ldx t3
	lda vNameLo,x
	sta ptr
	lda vNameHi,x
	sta ptr+1
	ldy #0
.n:
	lda (ptr),y
	beq .note
	cmp #64
	bcc .nl
	sbc #64
.nl:
	sta (ptr2),y
	iny
	bne .n
.note:
	ldx t3
	lda vNote,x
	ldx #16
	jsr PutNote
	; off-device voices are drawn dark
	ldx t3
	ldy vDev,x
	lda devOn,y
	beq .dark
	lda #13
	bne .col
.dark:
	lda #11
.col:
	sta t1
	; colour RAM row = screen row + $D400
	lda ptr2
	sta ptr
	lda ptr2+1
	clc
	adc #>(COLRAM-SCREEN)
	sta ptr+1
	ldy #19
	lda t1
.cc:
	sta (ptr),y
	dey
	bpl .cc
	ldx t3
	inx
	cpx #NUM_VOICES
	bne .v
	; ---- held notes
	PRINT 20, 0, txtHeld
	ldy #20
	ldx #0
	jsr ScreenAddr
	ldx #6
	ldy #0
.h:
	cpy heldCount
	beq .hd
	sty t3
	lda heldList,y
	clc
	adc #BASE_NOTE
	jsr PutMidiNote
	inx
	ldy t3
	iny
	bne .h
.hd:
	; ---- messages sent
	PRINT 23, 0, txtSent
	ldy #23
	ldx #0
	jsr ScreenAddr
	sei
	lda statSent
	sta t0
	lda statSent+1
	sta t1
	cli
	ldx #10
	jsr PutDec16
	rts

; 16-bit number in t1:t0 at column X of row ptr2, five digits
PutDec16:
	subroutine
	ldy #0
.digit:
	lda #0
	sta t2
.sub:
	lda t0
	sec
	sbc decLo,y
	pha
	lda t1
	sbc decHi,y
	bcc .done
	sta t1
	pla
	sta t0
	inc t2
	bne .sub
.done:
	pla
	lda t2
	clc
	adc #'0
	sty t3
	jsr PutChar
	ldy t3
	inx
	iny
	cpy #5
	bne .digit
	rts

decLo:	.byte <10000,<1000,<100,<10,<1
decHi:	.byte >10000,>1000,>100,>10,>1

; "ON " / "OFF" for device X at row Y, column 12
OnOff:
	subroutine
	lda devOn,x
	beq .off
	lda #<txtOn
	sta ptr
	lda #>txtOn
	sta ptr+1
	jmp .p
.off:
	lda #<txtOff
	sta ptr
	lda #>txtOff
	sta ptr+1
.p:
	ldx #12
	jmp PrintAt

; "CH a-b" for base channel A (0-15) at row Y, column 17
Channels:
	subroutine
	pha
	ldx #0
	jsr ScreenAddr
	ldx #17
	lda #'C
	jsr PutChar
	inx
	lda #'H
	jsr PutChar
	inx
	lda #32
	jsr PutChar
	inx
	pla
	pha
	clc
	adc #1
	jsr PutNum
	lda #'-
	jsr PutChar
	inx
	pla
	clc
	adc #5
	jsr PutNum
	lda #32
	jsr PutChar
	rts

; Note index A (or NO_NOTE) at column X of row ptr2: "C#3", "--"
PutNote:
	subroutine
	cmp #NO_NOTE
	bne .n
	lda #'-
	jsr PutChar
	inx
	jsr PutChar
	inx
	lda #32
	jsr PutChar
	inx
	jmp PutChar
.n:
	clc
	adc #BASE_NOTE
	; bass voices sound an octave down
	ldy t3
	cpy #NUM_VOICES
	bcs PutMidiNote
	pha
	lda vBass,y
	tay
	pla
	cpy #0
	beq PutMidiNote
	sec
	sbc #12
; MIDI note A at column X: name + octave (C4 = 60)
PutMidiNote:
	ldy #0
.o:
	cmp #12
	bcc .name
	sbc #12
	iny
	bne .o
.name:
	sty t1                  ; octave + 1
	asl
	pha
	tay
	lda noteNames,y
	jsr PutChar             ; (uses Y)
	inx
	pla
	tay
	lda noteNames+1,y
	jsr PutChar
	inx
	lda t1
	sec
	sbc #1
	clc
	adc #'0
	jsr PutChar
	inx
	lda #32
	jmp PutChar
