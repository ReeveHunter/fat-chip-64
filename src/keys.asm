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
	; ---- presses: down now, not accepted yet. Two passes: modifiers (SHIFT,
	; CTRL, K) first, so SHIFT+F7 or K + a note pressed in the same scan
	; still count as a combination.
	lda #0
	sta ksPass
.pass:
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
	jsr KeyCode
	jsr IsModifier          ; Z set = modifier
	beq .mod
	lda ksPass
	beq .pbn                ; pass 0: modifiers only
	bne .take
.mod:
	lda ksPass
	bne .pbn                ; (taken in pass 0)
.take:
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
	lda ksPass
	bne .done
	inc ksPass
	jmp .pass
.done:
	rts

; Z set if key code A is a modifier. Keeps A.
IsModifier:
	cmp #K_LSHIFT
	beq .y
	cmp #K_RSHIFT
	beq .y
	cmp #K_CTRL
	beq .y
	cmp #K_K
.y:
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
;   overlay        notes (K held + a note: set the key)
;   F1/F3/F5/F7    octave: C4 / C3 / C2 / C1 on the lowest key
;   SHIFT+F1/F3/F5 SID / Game Boy / MidiNES on-off     SHIFT+F7 panic
;   CTRL+F3/F5     Game Boy / MidiNES: next channel block
;   M              mute everything        SPACE  momentary (flips mute while held)
;   =              latch: OFF -> SMART -> HOLD -> ADD -> OFF
;   N              new chord: the next note starts one (twice: clear now)
;   Z / X          notes mode (POLY, CHORD, EXT) / extensions (7 9 11 13)
;   K + note / L   key root / major-minor        V  sound: FAT or PADS
;   A / S / D / F  arp mode / pattern / speed / SPARKLE octave
;   H / J          free arp speed            B  tap tempo
;   G              phantom-key filter on / off (off at start; for testing)
KeyDown:
	subroutine
	cmp #24
	bcc .isNote
	jmp .cmd
.isNote:
	tax
	lda kDown
	beq .note
	jmp SetKeyRoot
.note:
	lda #1
	sta physKey,x
	inc physCount
	jsr GetTicks
	lda newPending          ; N was pressed: this note starts a new chord
	beq .styles
	lda #0
	sta newPending
	jsr ClearNotes
	jmp .add
.styles:
	lda latch
	cmp #LATCH_ADD
	beq .addStyle
	cmp #LATCH_HOLD
	beq .hold
	cmp #LATCH_SMART
	bne .add
	; smart: a key still down, or a press soon after the last one, adds to
	; the chord; after a pause the next note starts a new chord
	lda physCount
	cmp #1
	bne .add
	lda nowL
	sec
	sbc lastPress
	sta t0
	lda nowH
	sbc lastPress+1
	cmp #>SMART_WINDOW
	bcc .add
	bne .new
	lda t0
	cmp #<SMART_WINDOW
	bcc .add
.new:
	jsr ClearNotes
	jmp .add
.hold:
	; hold: a fresh press after letting go of everything starts a new chord
	lda physCount
	cmp #1
	bne .add
	jsr ClearNotes
.add:
	lda nowL
	sta lastPress
	lda nowH
	sta lastPress+1
	lda #1
	sta noteHeld,x
	sta notePressed,x
	sta reallocFlag
	jmp PlayAdd
.addStyle:
	; add: each press adds a note; pressing a latched note takes it out
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
	cmp #K_F1
	bcc .table
	cmp #K_F7+1
	bcs .table
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
.table:
	ldx #0
.t:
	ldy cmdCode,x
	beq .x                  ; end of the table
	cmp cmdCode,x
	beq .go
	inx
	bne .t
.go:
	lda cmdLo,x
	sta ptr
	lda cmdHi,x
	sta ptr+1
	jmp (ptr)
.x:
	rts

; key -> handler (KeyDown)
cmdCode:    .byte K_CTRL,K_M,K_SPACE,K_EQUALS,K_N,K_G,K_A,K_S,K_D,K_F,K_H,K_J,K_B,K_Z,K_X,K_K,K_L,K_V,0
cmdLo:      .byte <CtrlDown,<MuteKey,<MomentDown,<LatchKey,<NewChordKey,<GhostKey,<ArpModeKey,<ArpPatKey,<ArpLenKey,<ArpOctKey,<ArpSlower,<ArpFaster,<TapTempo,<ModeKey,<SpiceKey,<KeyKeyDown,<ScaleKey,<SoundKey
cmdHi:      .byte >CtrlDown,>MuteKey,>MomentDown,>LatchKey,>NewChordKey,>GhostKey,>ArpModeKey,>ArpPatKey,>ArpLenKey,>ArpOctKey,>ArpSlower,>ArpFaster,>TapTempo,>ModeKey,>SpiceKey,>KeyKeyDown,>ScaleKey,>SoundKey

CtrlDown:
	lda #1
	sta ctrlDown
	rts

MuteKey:
	lda sidMute             ; (now mutes everything)
	eor #1
	sta sidMute
	jmp MuteChanged

MomentDown:
	lda #1
	sta moment
	jmp MuteChanged

GhostKey:
	lda ghostFilter
	eor #1
	sta ghostFilter
	jmp Dirty

KeyKeyDown:
	lda #1
	sta kDown
	rts

; K held + note X: that note is the key's root
SetKeyRoot:
	subroutine
	txa
.m:
	cmp #12
	bcc .r
	sbc #12
	bcs .m
.r:
	sta keyRoot
	lda #1
	sta reallocFlag
	jmp Dirty

ScaleKey:
	lda keyMinor
	eor #1
	sta keyMinor
	lda #1
	sta reallocFlag
	jmp Dirty

ModeKey:
	subroutine
	ldx playMode
	inx
	cpx #3
	bcc .s
	ldx #0
.s:
	stx playMode
	lda #1
	sta reallocFlag
	jmp Dirty

SpiceKey:
	subroutine
	ldx spice
	inx
	cpx #4
	bcc .s
	ldx #0
.s:
	stx spice
	lda #1
	sta reallocFlag
	jmp Dirty

SoundKey:
	lda padSound
	eor #1
	sta padSound
	jsr SoundApply
	jmp Dirty

LatchKey:
	subroutine
	ldx latch
	inx
	cpx #4
	bcc .l1
	ldx #0
.l1:
	stx latch
	lda #0
	sta newPending
	jsr Dirty
	txa
	bne .x
	jmp KeepPhysical        ; latch off: only keys still down keep sounding
.x:
	rts

; N: the next note starts a new chord. Pressed again before that: clear now.
NewChordKey:
	subroutine
	lda newPending
	bne .now
	lda #1
	sta newPending
	jmp Dirty
.now:
	lda #0
	sta newPending
	jsr Dirty
KeepPhysical:
	ldx #23
.l0:
	lda physKey,x
	sta noteHeld,x
	dex
	bpl .l0
	lda #1
	sta reallocFlag
	rts

Dirty:
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
	cmp #K_SPACE
	bne .k
	lda #0
	sta moment
	jmp MuteChanged
.k:
	cmp #K_K
	bne .sh
	lda #0
	sta kDown
	rts
.sh:
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

; RESTORE (top B of the overlay): each press switches both screens off / on
; (the C64's, and the Game Boy's with CC 112). No double tap.
RestoreCheck:
	subroutine
	lda nmiCount
	cmp nmiSeen
	bne .new
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
	bne .ok
	lda t0
	cmp #RESTORE_DEBOUNCE
	bcs .ok
	rts
.ok:
	lda nmiTick
	sta lastRestore
	lda nmiTick+1
	sta lastRestore+1
	lda videoMode
	eor #1
	sta videoMode
	beq .on
	lda VIC_CTRL1
	and #$EF                ; blank the C64 screen
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
	jmp GbGlobal
.x:
	rts
