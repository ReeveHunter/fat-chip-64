; Fat Chip 64 - keyboard and RESTORE

; Scan the whole matrix, turn changes into key events.
KeyScan:
	subroutine
	ldx #7
.col:
	lda colSelect,x
	sta CIA1_PRA
	lda CIA1_PRB
	eor #$FF
	sta keyNow,x
	dex
	bpl .col
	lda #$FF
	sta CIA1_PRA
	; edges
	ldx #0
.edges:
	stx ksCol
	lda keyNow,x
	eor keyPrev,x
	beq .nextCol
	sta ksBits              ; changed bits
	lda #0
	sta ksRow
.bit:
	lsr ksBits
	bcc .nextBit
	; key at column ksCol, row ksRow changed
	lda ksCol
	asl
	asl
	asl
	ora ksRow
	tay
	lda keymap,y
	pha                     ; key code
	ldx ksCol
	ldy ksRow
	lda keyNow,x
	and rowBit,y
	beq .up
	pla
	jsr KeyDown
	jmp .nextBit
.up:
	pla
	jsr KeyUp
.nextBit:
	inc ksRow
	lda ksRow
	cmp #8
	bne .bit
.nextCol:
	ldx ksCol
	lda keyNow,x
	sta keyPrev,x
	inx
	cpx #8
	bne .edges
	rts

; A = key code
KeyDown:
	subroutine
	cmp #24
	bcs .cmd
	tax
	lda #1
	sta noteHeld,x
	sta notePressed,x
	sta reallocFlag
	rts
.cmd:
	cmp #K_LSHIFT
	beq .shift
	cmp #K_RSHIFT
	beq .shift
	cmp #K_F1
	beq .f1
	cmp #K_F3
	beq .f3
	cmp #K_F5
	beq .f5
	cmp #K_F7
	beq .f7
	rts
.shift:
	inc shiftDown
	rts
.f1:
	ldx #DEV_SID
	jmp ToggleDevice
.f3:
	lda shiftDown
	bne .gbch
	ldx #DEV_GB
	jmp ToggleDevice
.gbch:
	jmp NextGbChannel
.f5:
	lda shiftDown
	bne .nesch
	ldx #DEV_NES
	jmp ToggleDevice
.nesch:
	jmp NextNesChannel
.f7:
	jmp Panic

KeyUp:
	subroutine
	cmp #24
	bcs .cmd
	tax
	lda #0
	sta noteHeld,x
	lda #1
	sta reallocFlag
	rts
.cmd:
	cmp #K_LSHIFT
	beq .shift
	cmp #K_RSHIFT
	beq .shift
	rts
.shift:
	lda shiftDown
	beq .x
	dec shiftDown
.x:
	rts

; RESTORE (top B of the overlay) is a command key.
; Every press: downbeat re-sync. A second press within DOUBLE_TAP ms: also
; cycle the video mode (the single action stays immediate so re-sync lands
; on the beat).
RestoreCheck:
	subroutine
	lda nmiCount
	cmp nmiSeen
	bne .new
	lda restoreFlash
	beq .x
	dec restoreFlash
	bne .x
	lda #0
	sta BORDER
.x:
	rts
.new:
	sta nmiSeen
	; debounce: ignore presses within RESTORE_DEBOUNCE ms of the last one
	lda nmiTick
	sec
	sbc lastRestore
	sta t0
	lda nmiTick+1
	sbc lastRestore+1
	sta t1
	bne .notBounce
	lda t0
	cmp #RESTORE_DEBOUNCE
	bcc .x
.notBounce:
	lda nmiTick
	sta lastRestore
	lda nmiTick+1
	sta lastRestore+1
	; double tap? (t1:t0 = ms since the previous press). Decide before acting:
	; the actions use t0/t1.
	ldx #0
	lda t1
	cmp #>DOUBLE_TAP
	bcc .dbl                ; under 256 ms
	bne .single             ; 512 ms or more
	lda t0
	cmp #<DOUBLE_TAP
	bcs .single
.dbl:
	ldx #1
.single:
	txa
	pha
	jsr Resync              ; every press: downbeat re-sync, right away
	pla
	beq .x2
	jmp CycleVideo
.x2:
	rts

Resync:
	subroutine
	lda #GCC_DOWNBEAT
	ldx #0
	lda devOn+DEV_GB
	beq .flash
	lda #GCC_DOWNBEAT
	jsr GbGlobal
.flash:
	lda #1                  ; white border blink
	sta BORDER
	lda #6
	sta restoreFlash
	rts

CycleVideo:
	subroutine
	lda videoMode
	eor #1
	sta videoMode
	beq .on
	lda VIC_CTRL1
	and #$EF                ; blank the screen
	sta VIC_CTRL1
	jmp .gb
.on:
	lda VIC_CTRL1
	ora #$10
	sta VIC_CTRL1
.gb:
	lda devOn+DEV_GB
	beq .x
	lda #GCC_DISPLAY
	ldx videoMode
	jsr GbGlobal
.x:
	rts
