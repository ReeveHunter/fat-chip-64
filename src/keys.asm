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
	bne .chk                ; filter off (default): phantom notes play...
	jsr KeyCode
	cmp #24
	bcc .accept
	jsr IsModifier
	beq .accept
.chk:                           ; ...but a command key never comes from a phantom
	jsr Suspect             ;  (v0.40: Q + E held, then C=, read C= + S too)
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
	lda spArm
	beq .nsp
	jmp SplitSet            ; (C= + V held: this note sets the split, it doesn't play)
.nsp:
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
	cmp #K_CRSR_DOWN
	beq .crsr
	cmp #K_CRSR_RIGHT
	bne .nokp
.crsr:
	ldx ctrlDown            ; CTRL + CRSR: the play mode (v0.40)
	beq .cb
	jmp PlayModeKey
.cb:
	ldx cbmDown             ; C= + CRSR: the last effect's settings, as in the menu (v0.45)
	beq .okp0
	jmp FocusCrsr
.okp0:
	ldx okpOn               ; ONE KEY PLAY: the cursor keys play
	beq .x
	ldx #1
	cmp #K_CRSR_DOWN
	beq .okp
	inx
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
	bne .ctrlF              ; CTRL + F1 F3: MIDI in octave up / down
	lda cbmDown
	bne .cbmF               ; C= + F1 F3: arp octave up / down, F5 sync / free, F7 type
	lda shiftDown
	bne .leadF              ; SHIFT + F1 F3: the lead's (and OKP's) octave, F5 SPLIT on / off, F7 its mode
	cpx #2
	bcc .oct
	beq .fat
	jmp VoiceModeKey        ; F7: POLY, MONO, SMART CHORD (v0.40)
.fat:
	jmp FatKey              ; F5: Fat Bass on / off (v0.37)
.oct:
	lda octBase             ; F1 up, F3 down: an octave (C0 .. C6 on the lowest key)
	cpx #0
	bne .down
	cmp #OCT_TOP
	bcs .x
	adc #12
	bcc .os
.down:
	cmp #OCT_BOTTOM+12
	bcc .x
	sbc #12
.os:
	sta octBase
	lda #1
	sta reallocFlag
	sta screenDirty
.x:
	rts
.cbmF:
	cpx #1                  ; (v0.43: F1 up, F3 down, as in every layer)
	bcc .au
	beq .ad
	cpx #2
	beq .as
	jmp ArpTypeKey
.ad:
	jmp ArpOctDown
.au:
	jmp ArpOctUp
.as:
	jmp ArpSyncKey
.leadF:
	cpx #1
	bcc .lu
	beq .ld
	cpx #2
	beq .ls
	jmp SplitNext           ; (v0.43: F5 on / off, F7 the cycle, in every layer)
.lu:
	jmp LeadOctUp
.ld:
	jmp LeadOctDown
.ls:
	jmp SplitToggle
.ctrlF:
	cpx #1
	bcc .mu
	beq .md
	rts
.mu:
	jmp MidiOctUp
.md:
	jmp MidiOctDown
.table:
	ldx #0                  ; the keys every layer shares
	jsr .find
	bcc .go
	ldx #CMD_CTRL           ; then one layer: CTRL, C=, RUN/STOP, SHIFT or none
	ldy ctrlDown
	bne .layer
	ldx #CMD_CBM
	ldy cbmDown
	beq .st
	jsr .find
	bcc .go
	lda keyCodeNow          ; (C= + the effect keys: fxKeyTab)
	jmp FxKey
.st:
	ldy #4                  ; (rowLayer: the A-G / Z-B keys' jobs)
	ldx #CMD_STOP
	lda stopDown
	beq .shl
	sta stopUsed            ; (RUN/STOP was a modifier: no start / stop)
	bne .rows
.shl:
	ldy #2
	ldx #CMD_SHIFT
	lda shiftDown
	bne .rows
	ldy #0
	ldx #CMD_PLAIN
.rows:
	lda keyCodeNow          ; A-G, Z-B: one job a row in these layers
	sty t0
	jsr KeyIndex            ; (X = 0 if it's neither)
	cmp bankKeys,x
	beq .row
	cmp slotKeys,x
	bne .lst
	inc t0
.row:
	ldy t0
	lda rowLo,y
	sta ptr
	lda rowHi,y
	sta ptr+1
	lda keyCodeNow
	jmp (ptr)
.lst:
	ldy t0
	ldx rowList,y
.layer:
	jsr .find
	bcc .go
	rts
.go:
	lda cmdLo,x
	sta ptr
	lda cmdHi,x
	sta ptr+1
	lda keyCodeNow
	jmp (ptr)
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

; key -> handler (v0.40: Fat Chip Shortcuts): six lists, each ending in 0
; (the bank / patch keys in the plain, SHIFT and RUN/STOP layers: rowLo;
;  C= + the effect keys: fxKeyTab)
cmdCode:
	.byte K_CTRL,K_CBM,K_STOP,K_LEFT,0
CMD_PLAIN   equ 5
	.byte K_K,K_L,K_COLON,K_SEMI,K_EQUALS,K_N,K_M,K_COMMA,K_PERIOD,K_SLASH,K_SPACE,K_RETURN,0
CMD_SHIFT   equ CMD_PLAIN+13
	.byte K_K,K_COLON,K_SEMI,K_COMMA,K_PERIOD,K_SPACE,0
CMD_CBM     equ CMD_SHIFT+7
	.byte K_A,K_Z,K_X,K_L,K_COLON,K_SEMI,K_COMMA,K_PERIOD,K_SPACE,K_RETURN,0
CMD_STOP    equ CMD_CBM+11
	.byte K_COLON,K_SEMI,K_COMMA,K_PERIOD,K_SPACE,0
CMD_CTRL    equ CMD_STOP+6
	.byte K_A,K_S,K_D,K_F,K_H,K_J,K_L,K_M,K_COMMA,K_PERIOD,0
CMD_END     equ CMD_CTRL+11

	mac CMDH                ; the handlers, {1} = < or >
	.byte {1}CtrlDown,{1}CbmDown,{1}StopDown,{1}UndoKey,0
	.byte {1}KeyArm,{1}LatchKey,{1}PrevPatch,{1}NextPatch,{1}TapTempo,{1}SpiceKey,{1}MuteKey,{1}NudgeDown,{1}NudgeUp
	.byte {1}DiceRoll,{1}MomentDown,{1}ReturnKey,0
	.byte {1}SplitPointKey,{1}LeadPrev,{1}LeadNext,{1}TransDown,{1}TransUp,{1}MomentDown,0
	.byte {1}CbmArp,{1}EnvAtkKey,{1}EnvRelKey
	.byte {1}FocusSync,{1}FocusPrevFx,{1}FocusNextFx,{1}FocusSlower,{1}FocusFaster,{1}CbmSpace,{1}FocusMenu,0
	.byte {1}BeatPrev,{1}BeatNext,{1}TempoDown,{1}TempoUp,{1}StopSpace,0
	.byte {1}ChipKey,{1}ChipKey,{1}ChipKey,{1}ScSyncKey,{1}FineDown,{1}FineUp,{1}LatchStyleKey,{1}Panic
	.byte {1}SpaceBack,{1}SpaceNext,0
	endm
cmdLo:
	CMDH <
cmdHi:
	CMDH >
  if cmdLo - cmdCode != CMD_END || cmdHi - cmdLo != CMD_END
    echo "the key lists and their handlers don't line up"
    err
  endif
; plain, SHIFT, RUN/STOP: the bank row's job, the patch row's; their lists
rowLo:      .byte <BankKey,<SlotKey,<LeadBankKey,<LeadSlotKey,<BeatBankKey,<BeatSlotKey
rowHi:      .byte >BankKey,>SlotKey,>LeadBankKey,>LeadSlotKey,>BeatBankKey,>BeatSlotKey
rowList:    .byte CMD_PLAIN,0,CMD_SHIFT,0,CMD_STOP

; the bank keys (A S D F G) and slot keys (Z X C V B), in order
bankKeys:   .byte K_A,K_S,K_D,K_F,K_G
slotKeys:   .byte K_Z,K_X,K_C,K_V,K_B

; A = key code -> X = its place in bankKeys, else in slotKeys
KeyIndex:
	subroutine
	ldx #4
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

; ------------------------------------------------------------ RUN/STOP + : the beats
; RUN/STOP + A S D F G: a beat bank (its beat in the same place, or its first);
; Z X C V B: that beat in the bank; : ; the previous / next beat
BeatBankKey:
	subroutine
	jsr KeyIndex
	stx beatBank
	txa
	asl
	asl
	adc beatBank
	sta t3                  ; the bank's first beat
	lda beatSel
.m:
	cmp #5
	bcc .s
	sbc #5
	bcs .m
.s:
	adc t3
	cmp #NUM_BEATS
	bcc .go
	lda t3
	cmp #NUM_BEATS
	bcs .x
.go:
	jmp BeatChoose
.x:
	rts

BeatSlotKey:
	subroutine
	jsr KeyIndex
	stx t3
	lda beatBank
	asl
	asl
	adc beatBank
	adc t3
	cmp #NUM_BEATS
	bcs .x
	jmp BeatChoose
.x:
	rts

BeatPrev:
	subroutine
	ldx beatSel
	dex
	bpl BeatSet
	ldx #NUM_BEATS-1
	bne BeatSet
BeatNext:
	ldx beatSel
	inx
	cpx #NUM_BEATS
	bcc BeatSet
	ldx #0
; X = beat: chosen, and its bank the beat bank
BeatSet:
	txa
	pha
	ldy #0
.b:
	cmp #5
	bcc .s
	sbc #5
	iny
	bne .b
.s:
	sty beatBank
	pla
	jmp BeatChoose

; ------------------------------------------------------------ the patches
; A S D F G: that bank, the same slot (or its first patch if that's empty)
BankKey:
	jsr KeyIndex
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

; SHIFT + A S D F G / Z X C V B: the lead's bank / patch
LeadBankKey:
	jsr KeyIndex
	jmp LeadBank
LeadSlotKey:
	jsr KeyIndex
	jmp LeadSlot

; : / ; the previous / next patch, on through the banks (empty slots skipped)
PrevPatch:
	subroutine
	lda #$FF
	bne .s
NextPatch:
	lda #1
.s:
	sta t3
	lda curBank
	ldx curSlot
	jsr SlotScan
	bcs .x
	pha
	jsr SlotSplit
	stx curBank
	sta curSlot
	pla
	tax
	jmp SoundSet
.x:
	rts

; SHIFT + : / ; the lead's
LeadPrev:
	subroutine
	lda #$FF
	bne .s
LeadNext:
	lda #1
.s:
	sta t3
	lda leadBank
	ldx leadSlot
	jsr SlotScan
	bcs .x
	pha
	jsr SlotSplit
	stx leadBank
	sta leadSlot
	pla
	jmp LeadLoad
.x:
	rts

; A = bank, X = slot, t3 = +1 / -1: the next filled slot that way (round the
; 25) -> carry clear, Y = it, A = its patch; carry set: none
SlotScan:
	subroutine
	stx t2
	sta t1
	asl
	asl
	adc t1
	adc t2
	tay
	ldx #25
.l:
	tya
	clc
	adc t3
	bpl .p
	lda #24
.p:
	cmp #25
	bcc .q
	lda #0
.q:
	tay
	lda bankSlot,y
	cmp #$FF
	bne .yes
	dex
	bne .l
	sec
	rts
.yes:
	clc
	rts

; Y = slot 0-24 -> X = bank, A = slot in it
SlotSplit:
	subroutine
	tya
	ldx #0
.d:
	cmp #5
	bcc .x
	sbc #5
	inx
	bne .d
.x:
	rts

; <- : back to the patch before the last change (the dice, a new patch, an
; effect or a setting); again: forward to it once more
UndoKey:
	subroutine
	lda undoOk
	beq .x
	ldy #PATCH_SIZE-1
.c:
	lda diceUndo,y
	ldx livePatch,y
	sta livePatch,y
	txa
	sta diceUndo,y
	dey
	bpl .c
	lda #$FF
	sta undoTag
	ldx undoSound
	lda soundMode
	sta undoSound
	stx soundMode
	jsr SlotOf
	jmp PatchApply
.x:
	rts

; ------------------------------------------------------------ tempo
; RUN/STOP + , / . : tempo down / up 1 BPM, 30-250 (Synthcart sync: its next)
TempoDown:
	subroutine
	lda #0
	jsr ScTempoKey
	bcc .dn
	rts
.dn:
	lda bpm
	sec
	sbc #1
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
	lda bpm
	clc
	adc #1
	cmp #250
	bcc .s
	lda #250
.s:
	ldx #0
	stx beatFresh           ; (a tempo of your own: a beat starting keeps it)
	jmp SetBpm

; , / . : a DJ nudge, 3% slower / faster while held
NudgeDown:
	lda #0
	jmp TempoNudge
NudgeUp:
	lda #1
	jmp TempoNudge

; SHIFT + , / . : everything played a semitone down / up (-12..+12)
TransDown:
	subroutine
	lda transp
	cmp #256-12
	beq .x
	dec transp
	bne .ch
	beq .ch
TransUp:
	lda transp
	cmp #12
	beq .x
	inc transp
.ch:
	lda #1
	sta reallocFlag
	jmp Dirty
.x:
	rts

; RETURN: the menu
ReturnKey:
	jmp MenuOpen

MuteKey:
	lda sidMute             ; (now mutes everything)
	eor #1
	sta sidMute
	jmp MuteChanged

; SPACE: its action (CTRL + , .), held while it's down. C= + SPACE: VINYL;
; RUN/STOP + SPACE: FILL
CbmSpace:
	lda #A_VINYL
	bne SpaceMoment
StopSpace:
	lda #A_FILL
	bne SpaceMoment
MomentDown:
	lda spaceAct
SpaceMoment:
	subroutine
	ldx spaceDown
	bne .x
	ldx #1
	stx spaceDown
	stx t3
	sta spaceHeld
	jmp DoAction
.x:
	rts

; ------------------------------------------------------------ CTRL +
; CTRL + A S D: the SID, Game Boy, MidiNES on / off
ChipKey:
	jsr KeyIndex
	jmp ToggleDevice

; CTRL + F: Synthcart tempo sync on / off (on: the Synthcart's in use)
ScSyncKey:
	subroutine
	lda scSync
	eor #1
	sta scSync
	beq .d
	sta useSc
.d:
	jsr SyncDerive
	jmp Dirty

; CTRL + H / J: fine tune a cent down / up
FineDown:
	subroutine
	ldx fineTune
	beq .x
	dex
	jmp .s
FineUp:
	ldx fineTune
	cpx #100
	bcs .x
	inx
.s:
	stx fineTune
	jmp SyncDerive
.x:
	rts

; CTRL + CRSR: the play mode, PLAY <-> DRONE
PlayModeKey:
	subroutine
	lda playMode
	cmp #MODE_DRONE
	beq .back
	sta playLast
	lda #MODE_DRONE
	bne .s
.back:
	lda playLast
.s:
	sta playMode
	jmp SettingChanged

; F7: POLY, MONO, SMART CHORD, round again (from DRONE: POLY)
VoiceModeKey:
	subroutine
	lda playMode
	cmp #MODE_CHORD
	beq .poly
	lda monoMode
	bne .smart
	lda playMode
	bne .poly
	ldx #MODE_POLY          ; POLY -> MONO
	lda #1
	bne .set
.smart:
	ldx #MODE_CHORD
	lda #0
	beq .set
.poly:
	lda #0
	ldx #MODE_POLY
.set:
	stx playMode
	cmp monoMode
	beq .same
	sta monoMode
	jsr GbLegato
.same:
	jmp SettingChanged

; SHIFT + K: the next note sets the split point (SPLIT KEY); again: never mind
SplitPointKey:
	lda spArm
	eor #1
	sta spArm
	lda #0
	sta spUsed
	jmp Dirty

; ------------------------------------------------------------ C= + : the effects
FOCUS_ARP   equ NUM_FX+1
; C= + S D F G H J C V B N M: that effect on / off (it's the one C= + : ; , . L
; and RETURN work on now). (v0.41: K was ATTACK, now BEND IN's STEP)
fxKeyTab:   .byte K_S,K_D,K_F,K_G,K_H,K_J,K_C,K_V,K_B,K_N,K_M
fxIdxTab:   .byte FXI_REPEAT,FXI_DUTYSEQ,FXI_FILTER,FXI_GLIDE,FXI_DETUNE,FXI_WARBLE
	.byte FXI_TREMOLO,FXI_VIBRATO,FXI_PENV,FXI_RDROP,FXI_PWM
FxKey:
	subroutine
	ldx #10
.f:
	cmp fxKeyTab,x
	beq .h
	dex
	bpl .f
	rts
.h:
	lda fxIdxTab,x
	tax
	inx
	stx fxFocus
	dex
	lda #0
	sta fxParam
	jmp FxToggle

; C= + A: the arp on / off
CbmArp:
	lda #FOCUS_ARP
	sta fxFocus
	jmp ArpToggle

; C= + Z / X: the envelope's attack / release: instant <-> as it was (or a
; slow one)
EnvAtkKey:
	ldy #0
	lda #10                 ; (500 ms)
	ldx #0
	beq EnvToggle
EnvRelKey:
	ldy #1
	lda #9                  ; (750 ms)
	ldx #3
EnvToggle:
	stx fxParam
	ldx #FXI_ENV+1
	stx fxFocus
	ldx fxParam
	sta tglDef
	sty tglY
	txa
	clc
	adc efP0+FXI_ENV
	tax
; X = param: step 0 <-> the step it had (tglSave, Y = tglY), or tglDef
ParamToggle:
	subroutine
	jsr ParamNearest
	ldy tglY
	cmp #0
	beq .on
	sta tglSave,y
	lda #0
	beq .set
.on:
	lda tglSave,y
	bne .set
	lda tglDef
.set:
	jmp ParamSet

; C= + L: tempo sync on / off (TREMOLO SYNC FREE <-> as it was or 1/4; the arp)
FocusSync:
	subroutine
	ldx fxFocus
	beq .x
	cpx #FOCUS_ARP
	bne .fx
	jmp ArpSyncKey
.fx:
	dex
	lda efSync,x
	bmi .x
	sta fxParam
	clc
	adc efP0,x
	tax
	lda #3
	sta tglDef
	lda #2
	sta tglY
	jmp ParamToggle
.x:
	rts

; v0.45: C= + CRSR, as in the menu: CRSR DOWN the effect's next setting
; (SHIFT: the one before), CRSR RIGHT its value up (SHIFT: down; the arp: its
; pattern). Row 14 shows them.
FocusCrsr:
	cmp #K_CRSR_DOWN
	bne FocusVal
	jmp FocusNext
FocusVal:
	subroutine
	lda shiftDown
	eor #1
	and #1
	sta stDir
	ldx fxFocus
	beq .x
	cpx #FOCUS_ARP
	bne .fx
	ldx arpPat
	lda stDir
	beq .ad
	jmp ArpPatKey
.ad:
	dex
	bpl .ap
	ldx #4
.ap:
	jmp ArpPatSet
.fx:
	dex
	lda fxParam
	clc
	adc efP0,x
	tax
; X = param, stDir 0 down / 1 up: a step, stopping at the ends
ParamStep:
	jsr ParamNearest
	ldy stDir
	bne .up
	cmp #0
	beq .x
	sec
	sbc #1
	jmp ParamSet
.up:
	clc
	adc #1
	cmp prN,x
	bcs .x
	jmp ParamSet
.x:
	rts

; C= + , / . : the effect slower / faster (its rate or time; the arp's speed)
FocusSlower:
	subroutine
	lda #0
	beq .s
FocusFaster:
	lda #1
.s:
	sta stDir
	ldx fxFocus
	beq .x
	cpx #FOCUS_ARP
	bne .fx
	lda arpLen
	cmp #ARP_FREE
	bne .syn
	lda stDir
	beq .sl
	jmp ArpFaster
.sl:
	jmp ArpSlower
.syn:
	ldx arpLen
	lda stDir
	beq .sd
	cpx #ARP_FREE-1
	bcs .x
	inx
	bne .ss
.sd:
	dex
	bmi .x
.ss:
	stx arpLen
	jmp ArpRateChanged
.fx:
	dex
	lda efRate,x
	cmp #$FF
	beq .x
	pha
	and #$7F
	sta fxParam
	clc
	adc efP0,x
	tax
	pla
	bpl .d                  ; (bit 7: a higher step is slower)
	lda stDir
	eor #1
	sta stDir
.d:
	jmp ParamStep
.x:
	rts

; C= + CRSR DOWN: the effect's next setting (SHIFT: the one before), round
FocusNext:
	subroutine
	ldx fxFocus
	beq .x
	cpx #FOCUS_ARP
	beq .x
	dex
	ldy fxParam
	lda shiftDown
	bne .b
	iny
	tya
	cmp efNP,x
	bcc .s
	lda #0
	beq .s
.b:
	dey
	tya
	bpl .s
	lda efNP,x
	sec
	sbc #1
.s:
	sta fxParam
	jmp Dirty
.x:
	rts

; v0.45: C= + : / ; : the previous / next effect for the C= keys, without
; switching it (row 14 shows it): ENVELOPE ... REPEAT, then the arp, round
FocusPrevFx:
	lda #$FF
	bne FocusFx
FocusNextFx:
	lda #1
FocusFx:
	subroutine
	ldx fxFocus
	bne .add
	cmp #1                  ; (none yet: ; the envelope, : the arp)
	beq .env
	lda #FOCUS_ARP
	bne .s
.add:
	clc
	adc fxFocus
	cmp #FXI_ENV+1
	bcs .a
	lda #FOCUS_ARP          ; (before the envelope: the arp)
	bne .s
.a:
	cmp #FOCUS_ARP+1
	bcc .s
.env:
	lda #FXI_ENV+1          ; (past the arp: the envelope)
.s:
	sta fxFocus
	lda #0
	sta fxParam
	jmp Dirty

; v0.45: C= + RETURN: the menu, open on the effect's page at its setting;
; SHIFT + RETURN there goes straight back to playing
FocusMenu:
	subroutine
	ldx fxFocus
	beq .x
	cpx #FOCUS_ARP
	beq .x
	dex
	lda efPage,x
	pha
	tay
	lda pgFirst,y
	clc
	adc fxParam
	pha
	jsr GlitchCalm
	lda #1
	sta colDirty
	sta menuOn
	pla
	sta menuRow
	pla
	sta menuJump
	jmp MenuPage
.x:
	rts

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

SpiceKey:
	subroutine
	ldx spice               ; SMART CHORD: 5TH, TRIAD, 7TH, 9TH, 11TH
	inx
	cpx #5
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
	jsr FxButtons           ; (v0.42: and the Game Boy's glide: DRONE's)
	pla
	tay
	pla
	tax
.r:
	rts

; L: latch on (in the LATCH STYLE: SMART / HOLD / ADD) or off
LatchKey:
	subroutine
	lda #1                  ; (SPLIT: LATCH holds the chord part: rebuild)
	sta reallocFlag
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

; CTRL + L: the next latch style (and the latch takes it at once if it's on)
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
	lda clMode              ; SPLIT: only KEY's chord side latches (TRIAD
	beq .lt                 ;  keeps its chord itself; the lead never)
	cmp #CL_KEY
	bne .clr
	jsr LeadSide
	bcs .clr
.lt:
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

; RESTORE (top B of the overlay), v0.37: each press the next video mode:
; NORMAL, VISUALIZER (GLITCH), SCREENS OFF (the C64's, and the Game Boy's
; with CC 112), NORMAL again. In the menu it skips the visualizer. No double tap.
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
	ldx vidState            ; NORMAL -> VISUALIZER -> OFF -> NORMAL
	inx
	cpx #1
	bne .n1
	lda menuOn              ; (the menu: no visualizer)
	beq .n1
	inx
.n1:
	cpx #3
	bcc .n2
	ldx #0
.n2:
	stx vidState
	cpx #1
	bne .n3
	jmp VizOn               ; VISUALIZER
.n3:
	lda vizOn               ; (leaving it: the play screen back underneath)
	beq .n4
	jsr VizOff
.n4:
	lda #0
	cpx #2
	bne .n5
	lda #1                  ; OFF: both screens
.n5:
	cmp videoMode
	bne .ch
	rts
.ch:
	sta videoMode
	tax
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
