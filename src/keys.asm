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
	; ---- every column as accepted (nothing pressed or let go): done
	ldx #7
.same:
	lda keyNow,x
	cmp keyAcc,x
	bne .changed
	dex
	bpl .same
	rts
.changed:
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
	cmp #K_CBM
	beq .y
	cmp #K_STOP
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

; A = key code (v0.22 layout)
;   overlay        notes
;   A S D F G      bank (FAT PADS LEADS BASS FX): switches at once, same slot
;   Z X C V B      patch 1-5 in the bank
;   L              latch on / off            K, then a note or a shape: key + scale
;   =              tap tempo                 , / .  tempo -1 / +1 (SHIFT: 10)
;   /              mute                      SHIFT+/  the dice
;   ; / :          free arp speed            SPACE  its action
;   F1 / F3        octave up / down          F5  arp on / off    F7  visualizer
;   RETURN         the menu                  CTRL+F3/F5  GB / NES channel block
;   C= +  A S D F  arp type / pattern / speed / SPARKLE octave
;         Z X C    notes mode / extensions / POLY-MONO     L  latch style
;         , .      SPACE's action            ; :  MIDI in octave down / up
;         /        undo the dice             F1 F3 F5  SID / GB / NES on-off
;         F7       panic                     (SHIFT + F keys too, as before)
;   RUN/STOP       tapped: beat start / stop; held + A S D F G H: pick a beat
KeyDown:
	subroutine
	cmp #24
	bcc NoteDown
	jmp .cmd
NoteDown:                       ; A = note index (overlay key 0-23, MIDI slot 24-31)
	tax
	lda kArm
	beq .note
	jmp KeyShapeNote        ; (K tapped: this note picks the key, it doesn't play)
.note:
	lda #1
	sta physKey,x
	inc physCount
	jsr RepeatPress         ; REPEAT: its echoes (keeps X)
	jsr GetTicks
	jsr ApplySettings       ; (changes waiting for this note)
	lda clMode              ; CHORD + LEAD: the chord's key, or the lead
	beq .ncl
	jsr ClPress
	bcc .ncl
	jmp .add                ; (the lead: no latch styles)
.ncl:
	lda newPending          ; NEXT or a setting change: this note starts a new chord
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
	ldx menuOn              ; the menu takes the cursor keys and RETURN
	beq KeyCmdPlay
	jmp MenuKey
KeyCmdPlay:                     ; (A = a command key: its usual job)
	sta keyCodeNow
	ldx okpOn               ; ONE KEY PLAY: the cursor keys play
	beq .nokp
	ldx #1
	cmp #K_CRSR_DOWN
	beq .okp
	inx
	cmp #K_CRSR_RIGHT
	bne .nokp
.okp:
	txa
	jmp OkpPress
.nokp:
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
	lda cbmDown
	ora shiftDown
	bne .shiftF
	cpx #2
	bcc .oct
	beq .arp
	jmp VizKey              ; F7
.arp:
	jmp ArpToggle           ; F5
.oct:
	lda octBase             ; F1 up, F3 down: an octave (C0 .. C6 on the lowest key)
	cpx #0
	bne .down
	cmp #OCT_TOP
	bcs .ox
	adc #12
	bcc .os
.down:
	cmp #OCT_BOTTOM+12
	bcc .ox
	sbc #12
.os:
	sta octBase
	lda #1
	sta reallocFlag
	sta screenDirty
.ox:
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
	ldx #0                  ; the keys every layer shares
	jsr .find
	bcc .go
	ldx #CMD_CBM            ; C= held, or RUN/STOP held, or neither
	ldy cbmDown
	bne .layer
	ldx #CMD_STOP
	ldy stopDown
	beq .plain
	sty stopUsed            ; (RUN/STOP was a modifier: no start / stop)
	bne .layer
.plain:
	ldx #CMD_PLAIN
.layer:
	jsr .find
	bcs .x
.go:
	lda cmdLo,x
	sta ptr
	lda cmdHi,x
	sta ptr+1
	lda keyCodeNow
	jmp (ptr)
.x:
	rts
; X = where a list starts -> carry clear and X = the key's entry
.find:
	lda keyCodeNow
.t:
	ldy cmdCode,x
	beq .no                 ; the end of this list
	cmp cmdCode,x
	beq .yes
	inx
	bne .t
.no:
	sec
	rts
.yes:
	clc
	rts

; key -> handler: four lists, each ending in 0
cmdCode:    .byte K_CTRL,K_CBM,K_STOP,K_SPACE,K_RETURN,K_K,0
CMD_PLAIN   equ 7
	.byte K_A,K_S,K_D,K_F,K_G,K_Z,K_X,K_C,K_V,K_B,K_L,K_EQUALS,K_COMMA,K_PERIOD,K_SLASH,K_SEMI,K_COLON,0
CMD_CBM     equ CMD_PLAIN+18
	.byte K_A,K_S,K_D,K_F,K_Z,K_X,K_C,K_L,K_COMMA,K_PERIOD,K_SEMI,K_COLON,K_SLASH,0
CMD_STOP    equ CMD_CBM+14
	.byte K_A,K_S,K_D,K_F,K_G,K_H,0
cmdLo:      .byte <CtrlDown,<CbmDown,<StopDown,<MomentDown,<ReturnKey,<KeyArm,0
	.byte <BankKey,<BankKey,<BankKey,<BankKey,<BankKey,<SlotKey,<SlotKey,<SlotKey,<SlotKey,<SlotKey
	.byte <LatchKey,<TapTempo,<TempoDown,<TempoUp,<SlashKey,<ArpFaster,<ArpSlower,0
	.byte <ArpTypeKey,<ArpPatKey,<ArpLenKey,<ArpOctKey,<ModeKey,<SpiceKey,<MonoKey,<LatchStyleKey
	.byte <SpaceBack,<SpaceNext,<MidiOctDown,<MidiOctUp,<DiceUndo,0
	.byte <BeatPickKey,<BeatPickKey,<BeatPickKey,<BeatPickKey,<BeatPickKey,<BeatPickKey,0
cmdHi:      .byte >CtrlDown,>CbmDown,>StopDown,>MomentDown,>ReturnKey,>KeyArm,0
	.byte >BankKey,>BankKey,>BankKey,>BankKey,>BankKey,>SlotKey,>SlotKey,>SlotKey,>SlotKey,>SlotKey
	.byte >LatchKey,>TapTempo,>TempoDown,>TempoUp,>SlashKey,>ArpFaster,>ArpSlower,0
	.byte >ArpTypeKey,>ArpPatKey,>ArpLenKey,>ArpOctKey,>ModeKey,>SpiceKey,>MonoKey,>LatchStyleKey
	.byte >SpaceBack,>SpaceNext,>MidiOctDown,>MidiOctUp,>DiceUndo,0
	.byte >BeatPickKey,>BeatPickKey,>BeatPickKey,>BeatPickKey,>BeatPickKey,>BeatPickKey,0

; the bank keys (A S D F G) and slot keys (Z X C V B), in order; H = beat 6
bankKeys:   .byte K_A,K_S,K_D,K_F,K_G,K_H
slotKeys:   .byte K_Z,K_X,K_C,K_V,K_B

; A = key code -> X = its place in bankKeys, else in slotKeys
KeyIndex:
	subroutine
	ldx #5
.l:
	cmp bankKeys,x
	beq .x
	dex
	bpl .l
	ldx #4
.s:
	cmp slotKeys,x
	beq .x
	dex
	bpl .s
	ldx #0
.x:
	rts

CtrlDown:
	subroutine
	lda #1
	sta ctrlDown
	rts

CbmDown:
	lda #1
	sta cbmDown
	rts

StopDown:
	lda #1
	sta stopDown
	lda #0
	sta stopUsed
	rts

; RUN/STOP + A S D F G H: that beat (and its kit)
BeatPickKey:
	subroutine
	jsr KeyIndex
	cpx #NUM_BEATS
	bcs .x
	txa
	jmp BeatChoose
.x:
	rts

; A S D F G: that bank, the same slot (or its first patch if that's empty)
BankKey:
	jsr KeyIndex
	lda clMode              ; CHORD + LEAD: SHIFT picks the lead's bank
	beq BankPick
	lda shiftDown
	beq BankPick
	jmp LeadBank
; X = bank (the DH-100's tone buttons too)
BankPick:
	subroutine
	stx t3                  ; bank
	txa
	asl
	asl
	adc t3                  ; x 5
	sta t2
	adc curSlot
	tay
	ldx bankSlot,y
	cpx #$FF
	bne .go
	ldy t2                  ; the slot's empty: the bank's first patch
	ldx #0
.f:
	lda bankSlot,y
	cmp #$FF
	bne .first
	iny
	inx
	cpx #5
	bne .f
	rts                     ; (an empty bank)
.first:
	stx curSlot
	tax
.go:
	lda t3
	sta curBank
	jmp SoundSet

; Z X C V B: that patch in the bank (an empty slot does nothing)
SlotKey:
	subroutine
	jsr KeyIndex
	lda clMode              ; CHORD + LEAD: SHIFT picks the lead's patch
	beq .n
	lda shiftDown
	beq .n
	jmp LeadSlot
.n:
	stx t3
	lda curBank
	asl
	asl
	adc curBank
	adc t3
	tay
	ldx bankSlot,y
	cpx #$FF
	beq .x
	lda t3
	sta curSlot
	jmp SoundSet
.x:
	rts

; , / . : tempo down / up 1 BPM (SHIFT: 10), 30-250
TempoDown:
	subroutine
	lda #0
	jsr ScTempoKey          ; (Synthcart sync: nudge / step)
	bcc .dn
	rts
.dn:
	lda #1
	ldx shiftDown
	beq .d
	lda #10
.d:
	sta t3
	lda bpm
	sec
	sbc t3
	cmp #30
	bcs .s
	lda #30
	bcc .s
TempoUp:
	lda #1
	jsr ScTempoKey
	bcc .up
	rts
.up:
	lda #1
	ldx shiftDown
	beq .u
	lda #10
.u:
	clc
	adc bpm
	bcs .top
	cmp #250
	bcc .s
.top:
	lda #250
.s:
	ldx #0
	stx beatFresh           ; (a tempo of your own: a beat starting keeps it)
	jmp SetBpm

; / : mute; SHIFT + / : the dice
SlashKey:
	lda shiftDown
	beq MuteKey
	jmp DiceRoll

; RETURN: the menu (SHIFT+RETURN closes it again)
ReturnKey:
	subroutine
	lda shiftDown
	bne .x
	jmp MenuOpen
.x:
	rts

MuteKey:
	lda sidMute             ; (now mutes everything)
	eor #1
	sta sidMute
	jmp MuteChanged

; SPACE: its action (the menu's SPACE, or , and .), held while it's down
MomentDown:
	subroutine
	lda spaceDown
	bne .x
	lda #1
	sta spaceDown
	sta t3
	lda spaceAct
	sta spaceHeld
	jmp DoAction
.x:
	rts

GhostKey:
	lda ghostFilter
	eor #1
	sta ghostFilter
	jmp Dirty

; K tapped: the next note, or notes played together, set the key and scale
; (when they're all let go: the lowest is the key, the shape the scale - see
; shapeLo / shapeScale). They don't play. K again first: never mind.
KeyArm:
	subroutine
	lda kArm
	eor #1
	sta kArm
	lda #0
	sta kCount
	sta kMaskL
	sta kMaskH
	lda #$FF
	sta kLow
	jmp Dirty

; note index X pressed while K is armed
KeyShapeNote:
	subroutine
	lda #1
	sta kNote,x
	sta physKey,x           ; (so a MIDI note-off finds its slot)
	inc kCount
	jsr IdxNote
	cmp kLow
	bcs .m
	sta kLow
.m:
	cmp #12
	bcc .pc
	sbc #12
	bcs .m
.pc:
	cmp #8
	bcs .hi
	tay
	lda pcBit,y
	ora kMaskL
	sta kMaskL
	rts
.hi:
	sbc #8
	tay
	lda pcBit,y
	ora kMaskH
	sta kMaskH
	rts

; the shape's last key let go: key = the lowest note, scale = the shape's
KeyShapeDone:
	subroutine
	lda #0
	sta kArm
	lda kLow
.m:
	cmp #12
	bcc .r
	sbc #12
	bcs .m
.r:
	sta keyRoot
	tax                     ; turn the pitch classes so the root is bit 0
	beq .look
.rot:
	lsr kMaskH
	ror kMaskL
	bcc .rn
	lda kMaskH
	ora #$08
	sta kMaskH
.rn:
	dex
	bne .rot
.look:
	ldx #NUM_SHAPES-1
.s:
	lda kMaskL
	cmp shapeLo,x
	bne .sn
	lda kMaskH
	cmp shapeHi,x
	beq .found
.sn:
	dex
	bpl .s
	lda kMaskL              ; not a shape we know: a minor third -> minor
	and #$08
	beq .maj
	lda #1
	bne .set
.maj:
	lda #0
	beq .set
.found:
	lda shapeScale,x
.set:
	sta keyScale
	jmp SettingChanged

ModeKey:
	subroutine
	ldx playMode            ; POLY, SMART CHORD, EXT, DRONE
	inx
	cpx #4
	bcc .s
	ldx #0
.s:
	stx playMode
	jmp SettingChanged

SpiceKey:
	subroutine
	ldx spice
	inx
	cpx #4
	bcc .s
	ldx #0
.s:
	stx spice
	jmp SettingChanged

; Mode, extensions, key or major/minor changed. A latched chord keeps
; sounding as it is; the next note starts a new chord with the new settings
; (latch NEXT). Otherwise they apply at once.
SettingChanged:
	subroutine
	jsr Dirty
	lda latch
	beq .apply
	ldx #NIDX-1
.c:
	lda noteHeld,x
	bne .wait
	dex
	bpl .c
.apply:
	jsr ApplySettings
	lda #1
	sta reallocFlag
	rts
.wait:
	lda #1
	sta newPending
	rts

; The settings the chord builder uses (eff*) catch up with the chosen ones.
ApplySettings:
	subroutine
	lda useDh               ; (keeps X and Y)
	beq .pm
	lda dhNotes             ; DH-100 NOTES: CHORD or HARMONY, whatever's chosen
	beq .pm
	cmp #2                  ; 1 CHORD, 2 HARMONY
	bne .m
	lda #MODE_HARM
	bne .m
.pm:
	lda playMode
.m:
	sta effMode
	lda spice
	sta effSpice
	lda keyRoot
	sta effRoot
	lda keyScale
	sta effScale
	lda effMode             ; a new notes mode: CHORD CHANGE may glide now
	cmp lastEff
	beq .r
	sta lastEff
	txa
	pha
	tya
	pha
	jsr FxVars
	pla
	tay
	pla
	tax
.r:
	rts

; L: latch on (in the LATCH STYLE: SMART / HOLD / ADD) or off
LatchKey:
	subroutine
	lda clMode              ; CHORD + LEAD LATCH 3: L lets the chord go
	cmp #2
	bne .l
	lda #0
	sta clChordN
	lda #1
	sta reallocFlag
	rts
.l:
	lda latch
	bne .off
	ldx latchStyle          ; (0-2: SMART, HOLD, ADD)
	inx
	stx latch
	lda #0
	sta newPending
	jmp Dirty
.off:
	lda #0
	sta latch
	sta newPending
	jsr Dirty
	jmp KeepPhysical        ; latch off: only keys still down keep sounding

; C= + L: the next latch style (and the latch takes it at once if it's on)
LatchStyleKey:
	subroutine
	ldx latchStyle
	inx
	cpx #3
	bcc .s
	ldx #0
.s:
	stx latchStyle
	lda latch
	beq .d
	inx
	stx latch
.d:
	jmp Dirty

; Only the keys still down keep sounding (the settings catch up)
KeepPhysical:
	jsr ApplySettings
	ldx #NIDX-1
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


ClearNotes:
	subroutine
	ldy #NIDX-1
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
NoteUp:                         ; A = note index
	tax
	lda kNote,x             ; part of a K shape: never played
	beq .play
	lda #0
	sta kNote,x
	sta physKey,x
	dec kCount
	bne .kw
	jmp KeyShapeDone
.kw:
	rts
.play:
	lda #0
	sta physKey,x
	lda physCount
	beq .n
	dec physCount
.n:
	lda clMode              ; (CHORD + LEAD: no latch, it has its own)
	bne .clr
	lda latch
	ora sustainOn           ; (the keytar's sustain button, held)
	bne .x                  ; latched: keeps sounding
.clr:
	lda #0
	sta noteHeld,x
	lda #1
	sta reallocFlag
.x:
	rts
.cmd:
	ldx #1                  ; One Key Play: a cursor key let go
	cmp #K_CRSR_DOWN
	beq .okp
	inx
	cmp #K_CRSR_RIGHT
	bne .ct
.okp:
	txa
	jmp OkpRelease
.ct:
	cmp #K_CTRL
	bne .cb
	lda #0
	sta ctrlDown
	rts
.cb:
	cmp #K_CBM
	bne .st
	lda #0
	sta cbmDown
	rts
.st:
	cmp #K_STOP
	bne .s
	lda #0
	sta stopDown
	lda stopUsed            ; tapped on its own: beat start / stop
	bne .su
	lda menuOn
	bne .su
	jmp BeatRunKey
.su:
	rts
.s:
	cmp #K_COMMA
	beq .nud
	cmp #K_PERIOD
	bne .sp
.nud:
	jmp ScNudgeEnd
.sp:
	cmp #K_SPACE
	bne .k
	lda spaceDown
	beq .k0
	lda #0
	sta spaceDown
	sta t3
	lda spaceHeld
	jmp DoAction
.k0:
	rts
.k:
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
