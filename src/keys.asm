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
;   overlay        notes (latch: = )
;   F1/F3/F5/F7    octave: C4 / C3 / C2 / C1 on the lowest key
;   SHIFT+F1/F3/F5 SID / Game Boy / MidiNES on-off     SHIFT+F7 panic
;   CTRL+F3/F5     Game Boy / MidiNES: next channel block
;   M              mute the SID (kills the C64's hum)
KeyDown:
	subroutine
	cmp #24
	bcs .cmd
	tax
	lda latch               ; latched: a fresh press after letting go of
	beq .add                ; everything starts a new chord
	lda physCount
	bne .add
	jsr ClearNotes
.add:
	lda #1
	sta physKey,x
	sta noteHeld,x
	sta notePressed,x
	sta reallocFlag
	inc physCount
	rts
.cmd:
	cmp #K_LSHIFT
	beq .shift
	cmp #K_RSHIFT
	beq .shift
	cmp #K_CTRL
	beq .ctrl
	cmp #K_M
	beq .mute
	cmp #K_EQUALS
	beq .latch
	cmp #K_F1
	bcc .x
	cmp #K_F7+1
	bcs .x
	; F keys
	sec
	sbc #K_F1
	tax                     ; 0-3 = F1 F3 F5 F7
	lda ctrlDown
	bne .ctrlF
	lda shiftDown
	bne .shiftF
	lda octaves,x
	sta octBase
	lda #1
	sta reallocFlag
	sta screenDirty
.x:
	rts
.shiftF:
	cpx #3
	beq .panic
	jmp ToggleDevice        ; X = 0 SID, 1 GB, 2 NES
.panic:
	jmp Panic
.ctrlF:
	cpx #1
	bne .c5
	jmp NextGbChannel
.c5:
	cpx #2
	bne .x
	jmp NextNesChannel
.shift:
	inc shiftDown
	rts
.ctrl:
	lda #1
	sta ctrlDown
	rts
.mute:
	lda sidMute
	eor #1
	sta sidMute
	jsr SidVolume
	lda #1
	sta screenDirty
	rts
.latch:
	lda latch
	eor #1
	sta latch
	bne .l1
	; latch off: only keys still down keep sounding
	ldx #23
.l0:
	lda physKey,x
	sta noteHeld,x
	dex
	bpl .l0
	lda #1
	sta reallocFlag
.l1:
	lda #1
	sta screenDirty
	rts

; lowest overlay key for F1 F3 F5 F7
octaves:    .byte 60,48,36,24

ClearNotes:
	subroutine
	ldy #23
	lda #0
.c:
	sta noteHeld,y
	dey
	bpl .c
	rts

KeyUp:
	subroutine
	cmp #24
	bcs .cmd
	tax
	lda #0
	sta physKey,x
	lda physCount
	beq .n
	dec physCount
.n:
	lda latch
	bne .x                  ; latched: keeps sounding
	lda #0
	sta noteHeld,x
	lda #1
	sta reallocFlag
.x:
	rts
.cmd:
	cmp #K_CTRL
	bne .s
	lda #0
	sta ctrlDown
	rts
.s:
	cmp #K_LSHIFT
	beq .shift
	cmp #K_RSHIFT
	beq .shift
	rts
.shift:
	lda shiftDown
	beq .x2
	dec shiftDown
.x2:
	rts

; RESTORE (top B of the overlay) is a command key. For testing, for now:
;   single tap: white border blink, count it, downbeat re-sync to the Game
;               Boy (its header blinks the beat)
;   double tap (second press within DOUBLE_TAP ms): red border blink, count
;               it, switch the Game Boy's screen off / on (CC 112)
; A double tap's first press is a single tap.
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
	bne .double
	jmp Resync
.double:
	jmp GbScreenToggle

Resync:
	subroutine
	inc rsSingle
	lda devOn+DEV_GB
	beq .flash
	lda #GCC_DOWNBEAT
	ldx #0
	jsr GbGlobal
.flash:
	lda #1                  ; white
	sta BORDER
	lda #6
	sta restoreFlash
	lda #1
	sta screenDirty
	rts

GbScreenToggle:
	subroutine
	inc rsDouble
	lda #2                  ; red
	sta BORDER
	lda #6
	sta restoreFlash
	lda #1
	sta screenDirty
	lda videoMode
	eor #1
	sta videoMode
	lda devOn+DEV_GB
	beq .x
	lda #GCC_DISPLAY
	ldx videoMode
	jsr GbGlobal
.x:
	rts
