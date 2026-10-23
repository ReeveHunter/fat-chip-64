; Fat Chip 64 - keyboard and RESTORE

; Scan the whole matrix, turn changes into key events.
;
; Phantom keys: the C64 keyboard has no diodes, so holding three keys on the
; corners of a rectangle in the matrix makes the fourth corner read as held.
; keyAcc holds the keys we've accepted. A newly down key is accepted only if
; it isn't the corner of a rectangle of held keys; if it is, it could be a
; phantom (the matrix can't tell a real fourth key from a ghost), so it waits
; until the rectangle breaks. Keys Fat Chip doesn't use (most are under the
; overlay) are left out: they're never really pressed, so a reading on one is
; always a ghost. So Q 2 E plays all three (the ghost lands on 4), and only
; chords whose ghost lands on another used key lose their newest note.
KeyScan:
	subroutine
	ldx #7
.col:
	lda colSelect,x
	sta CIA1_PRA
	lda CIA1_PRB
	eor #$FF
	and keyUsed,x           ; unused keys only ever read as ghosts
	sta keyNow,x
	dex
	bpl .col
	lda #$FF
	sta CIA1_PRA
	; ---- releases first: accepted keys that are up now
	ldx #0
.rc:
	stx ksCol
	lda keyNow,x
	eor #$FF
	and keyAcc,x
	sta ksBits
	lda #0
	sta ksRow
.rb:
	lda ksBits
	beq .rcn
	lsr ksBits
	bcc .rbn
	ldx ksCol
	ldy ksRow
	lda rowBit,y
	eor #$FF
	and keyAcc,x
	sta keyAcc,x
	jsr KeyCode
	jsr KeyUp
.rbn:
	inc ksRow
	bne .rb
.rcn:
	ldx ksCol
	inx
	cpx #8
	bne .rc
	; ---- presses: down now, not accepted yet
	ldx #0
.pc:
	stx ksCol
	lda keyAcc,x
	eor #$FF
	and keyNow,x
	sta ksBits
	lda #0
	sta ksRow
.pb:
	lda ksBits
	beq .pcn
	lsr ksBits
	bcc .pbn
	lda ghostFilter
	beq .accept             ; filter off (default): phantoms play
	jsr Suspect
	bcs .pbn                ; maybe a phantom: wait
.accept:
	ldx ksCol
	ldy ksRow
	lda rowBit,y
	ora keyAcc,x
	sta keyAcc,x
	jsr KeyCode
	jsr KeyDown
.pbn:
	inc ksRow
	bne .pb
.pcn:
	ldx ksCol
	inx
	cpx #8
	bne .pc
	rts

; A = key code at ksCol / ksRow
KeyCode:
	subroutine
	lda ksCol
	asl
	asl
	asl
	ora ksRow
	tay
	lda keymap,y
	rts

; Carry set if the key at ksCol / ksRow is the corner of a rectangle of held
; keys: some other column has a key in this row and shares another row with
; this column.
Suspect:
	subroutine
	ldy ksRow
	lda rowBit,y
	eor #$FF
	ldx ksCol
	and keyNow,x
	sta ksMask              ; this column's other held rows
	beq .no
	ldx #7
.c:
	cpx ksCol
	beq .n
	lda keyNow,x
	and rowBit,y
	beq .n
	lda keyNow,x
	and ksMask
	beq .n
	sec
	rts
.n:
	dex
	bpl .c
.no:
	clc
	rts

; A = key code
;   overlay        notes
;   =              latch: OFF -> HOLD -> BUILD -> OFF
;   N              new chord: latched notes go (keys still down stay)
;   G              phantom-key filter on / off (off at start; for testing)
;   A / S / D      arp mode / pattern / speed     H / J  free speed
;   B              tap tempo
;   F1/F3/F5/F7    octave: C4 / C3 / C2 / C1 on the lowest key
;   SHIFT+F1/F3/F5 SID / Game Boy / MidiNES on-off     SHIFT+F7 panic
;   CTRL+F3/F5     Game Boy / MidiNES: next channel block
;   M              mute the SID (kills the C64's hum)
KeyDown:
	subroutine
	cmp #24
	bcs .cmd
	tax
	lda #1
	sta physKey,x
	inc physCount
	lda latch
	cmp #LATCH_BUILD
	beq .build
	cmp #LATCH_HOLD         ; hold: a fresh press after letting go of
	bne .add                ; everything starts a new chord
	lda physCount
	cmp #1
	bne .add
	jsr ClearNotes
.add:
	lda #1
	sta noteHeld,x
	sta notePressed,x
	sta reallocFlag
	jmp PlayAdd
.build:
	; build: each press adds a note; pressing a latched note takes it out
	lda #1
	sta reallocFlag
	lda noteHeld,x
	beq .add
	lda #0
	sta noteHeld,x
	rts
.cmd:
	cmp #K_LSHIFT
	beq .sh
	cmp #K_RSHIFT
	bne .nsh
.sh:
	inc shiftDown
	rts
.nsh:
	cmp #K_CTRL
	bne .nct
	lda #1
	sta ctrlDown
	rts
.nct:
	cmp #K_M
	bne .j0
	jmp .mute
.j0:
	cmp #K_EQUALS
	bne .j1
	jmp .latch
.j1:
	cmp #K_N
	bne .j2
	jmp .newChord
.j2:
	cmp #K_G
	bne .k0
	jmp .ghost
.k0:
	cmp #K_A
	bne .k1
	jmp ArpModeKey
.k1:
	cmp #K_S
	bne .k2
	jmp ArpPatKey
.k2:
	cmp #K_D
	bne .k3
	jmp ArpLenKey
.k3:
	cmp #K_H
	bne .k4
	jmp ArpSlower
.k4:
	cmp #K_J
	bne .k5
	jmp ArpFaster
.k5:
	cmp #K_B
	bne .k6
	jmp TapTempo
.k6:
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
	ldx latch
	inx
	cpx #3
	bcc .l1
	ldx #0
.l1:
	stx latch
	lda #1
	sta screenDirty
	txa
	bne .x2
	; latch off: only keys still down keep sounding
.newChord:
	ldx #23
.l0:
	lda physKey,x
	sta noteHeld,x
	dex
	bpl .l0
	lda #1
	sta reallocFlag
.x2:
	rts

.ghost:
	lda ghostFilter
	eor #1
	sta ghostFilter
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
