; Fat Chip 64 - CHORD + LEAD (v0.28): a chord and a lead at once, each its
; own patch.
;   BASS      (was LOW NOTE) the first key pressed is the chord's root
;             (POLY: just it; SMART CHORD: its 5TH, TRIAD...; DRONE: the
;             drone); every other key is the lead, while the chord key is held
;   TRIAD     (was LATCH 3) three keys pressed together are the chord while
;             they're held (v0.36: with LATCH on, it keeps sounding after you
;             let go); every other key is the lead.
; v0.36: the lead is LEAD OCTAVE up in every mode (+1 at first; SHIFT + F1 /
; F3). SHIFT + F5 SPLIT on / off (held + a note: the split point), SHIFT + F7
; its mode. LATCH holds KEY's chord side and TRIAD's chord.
; The lead is one note (the last key pressed) on one voice per chip (SID 3,
; Game Boy pulse 1, NES pulse 1), only while it plays: the rest of the time
; those voices are the chord's. Its patch: SHIFT + A S D F G / Z X C V B.
; The lead's own: the SID's waveform, width, envelope and octave, the Game
; Boy pulse's CCs, the NES pulse's duty. Shared with the chord: the effects
; (vibrato, filter, tremolo...), the NES envelope.

;   KEY       (v0.32) a keyboard split: keys below the split point are the
;             chord (as the mode plays them), keys from it up the lead (LEAD
;             OCTAVE, +1 at first). On the C64's keys the split is a key (it
;             stays put when the octave changes); over MIDI, a note as sent
;             (before MIDI IN OCTAVE). SHIFT + F5 held + a note sets either.
CL_KEY      equ 1               ; SPLIT (clMode)
CL_BASS     equ 2
CL_L3       equ 3               ; (TRIAD)
LEAD_SID    equ 6               ; the lead's voices: SID 3, GB pulse 1, NES pulse 1
LEAD_GB     equ 1
LEAD_NES    equ 2

; NoteDown, CHORD + LEAD on: key X pressed. Carry set: it's the lead (the
; latch styles leave it alone).
ClPress:
	subroutine
	stx exI
	lda clMode
	cmp #CL_L3
	beq .l3
	cmp #CL_KEY
	bne .low
	jsr LeadSide            ; KEY: which side of the split
	bcc .ch
	stx clLeadIdx
.ch:
	rts
.low:
	; LOW NOTE: the chord's key, if none is held
	ldy clChordIdx
	bmi .chord
	lda physKey,y
	bne .lead
.chord:
	stx clChordIdx
	clc
	rts
.lead:
	stx clLeadIdx
	sec
	rts
.l3:
	; LATCH 3: a press within 100 ms of the last counts towards three
	lda nowL
	sec
	sbc clLastL
	sta t0
	lda nowH
	sbc clLastL+1
	bne .new
	lda t0
	cmp #100
	bcs .new
	inc clBurst
	bne .t
.new:
	lda #1
	sta clBurst
.t:
	lda nowL
	sta clLastL
	lda nowH
	sta clLastL+1
	stx clLeadIdx
	lda clBurst
	cmp #3
	bcc .x                  ; (a lead note, for now)
	; three together: every key down now is the chord
	lda #$FF
	sta clLeadIdx
	ldy #0
	ldx #0
.k:
	lda physKey,x
	beq .kn
	cpy #8
	bcs .kn
	jsr IdxNote             ; (keeps X, Y)
	sta clChord,y
	txa
	sta clCIdx,y            ; (v0.36: its key, for TRIAD without LATCH)
	iny
.kn:
	inx
	cpx #NIDX
	bne .k
	sty clChordN
.x:
	ldx exI
	sec
	rts

; BuildHeld, CHORD + LEAD on: heldList = the chord, leadNote = the lead
ClBuild:
	subroutine
	lda #NO_NOTE
	sta leadNote
	ldx clLeadIdx           ; the lead: its key still down
	bmi .c
	lda physKey,x
	beq .c
	jsr IdxNote
	ldy leadOct             ; LEAD OCTAVE up (or down), every mode (v0.36)
.ko:
	cpy #2
	beq .kd
	bcc .kdn
	clc
	adc #12
	dey
	bne .ko
.kdn:
	sec
	sbc #12
	iny
	bne .ko
.kd:
	cmp #128
	bcc .ks
	jsr IdxNote             ; (off the top or bottom: where it was played)
.ks:
	sta leadNote
.c:
	lda #0
	sta heldCount
	lda clMode
	cmp #CL_L3
	beq .l3
	cmp #CL_KEY
	beq .key
	ldx clChordIdx
	bmi .x
	lda physKey,x
	beq .x
	jsr IdxNote
	jmp InsertNote          ; (POLY: just it; SMART CHORD, DRONE: their chord)
.l3:
	lda latch               ; TRIAD: LATCH on, the chord as it was; off, the
	beq .lk                 ;  chord's keys still held
	ldx #0
.n:
	cpx clChordN
	beq .x
	lda clChord,x
	stx exK
	jsr InsertNote
	ldx exK
	inx
	bne .n
.x:
	rts
.lk:
	ldx #0
	stx exS                 ; (any still down?)
.k:
	cpx clChordN
	beq .ke
	stx exK
	lda clCIdx,x
	tax
	lda physKey,x
	beq .kn
	inc exS
	jsr IdxNote
	jsr InsertNote
.kn:
	ldx exK
	inx
	bne .k
.ke:
	lda exS
	bne .x
	sta clChordN            ; (all let go: no chord)
	rts
.key:
	ldx #0                  ; KEY: the chord, every note held below the split
.kk:                            ;  (noteHeld: LATCH keeps them)
	lda noteHeld,x
	beq .kx
	jsr LeadSide
	bcs .kx
	jsr IdxNote
	stx exK
	jsr InsertNote
	ldx exK
.kx:
	inx
	cpx #NIDX
	bne .kk
	rts

; note index X: carry set if it's on the lead's side of the split (KEY).
; Keeps X.
LeadSide:
	subroutine
	cpx #MIDI_FIRST
	bcs .m
	cpx splitKey
	rts
.m:
	lda midiSrc-MIDI_FIRST,x
	cmp splitNote
	rts

; SHIFT + F7: SPLIT's next mode (KEY, BASS, TRIAD; on if it was off)
SplitNext:
	subroutine
	ldx clMode
	bne .n
	ldx clLast
	dex
.n:
	inx
	cpx #4
	bcc .s
	ldx #1
.s:
	stx clMode
	stx clLast
	jmp ClHook

; SHIFT + F5 let go with no note: SPLIT on (its last mode) / off
SplitToggle:
	subroutine
	lda clMode
	beq .on
	sta clLast
	lda #0
	beq .s
.on:
	lda clLast
.s:
	sta clMode
	jmp ClHook

; SHIFT + F1 / F3: the lead an octave up / down (LEAD OCTAVE, -2..+2)
LeadOctUp:
	ldx leadOct
	cpx #4
	bcs LeadOctX
	inx
	bne LeadOctS
LeadOctDown:
	ldx leadOct
	beq LeadOctX
	dex
LeadOctS:
	stx leadOct
	lda #1
	sta reallocFlag
	jmp Dirty
LeadOctX:
	rts

; C= + V held, note index X pressed: the split point there; SPLIT is KEY
SplitSet:
	subroutine
	lda #1
	sta spUsed
	cpx #MIDI_FIRST
	bcs .m
	stx splitKey
	bcc .k
.m:
	lda midiSrc-MIDI_FIRST,x
	sta splitNote
.k:
	lda #CL_KEY
	sta clMode
	sta clLast
	jmp ClHook

; SHIFT + F5 pressed
SplitArm:
	subroutine
	lda #1
	sta spArm
	lda #0
	sta spUsed
	rts

; Allocate: the lead's voices (before anything else is shared out)
LeadVoices:
	subroutine
	ldx #NUM_VOICES-1
	lda #0
.z:
	sta vLead,x
	dex
	bpl .z
	lda leadNote
	cmp #NO_NOTE
	beq .x
	lda clMode
	beq .x
	ldx #LEAD_SID
	jsr .one
	ldx #LEAD_GB
	jsr .one
	ldx #LEAD_NES
.one:
	jsr VoiceEnabled
	beq .x
	lda #1
	sta vLead,x
.x:
	rts

; Allocate, once nothing's wanted yet: the lead's voices play it
LeadWant:
	subroutine
	ldx #NUM_VOICES-1
.v:
	lda vLead,x
	beq .n
	lda leadNote
	sta vWant,x
.n:
	dex
	bpl .v
	rts

; ApplyVoices, voice X about to play vWant: its channel gets the right patch
; (the lead's or the chord's) if it hasn't it already. Keeps X.
LeadPatchFor:
	subroutine
	lda vWant,x
	cmp #NO_NOTE
	beq .x
	lda vLead,x
	cmp vPat,x
	beq .x
	jmp ChanPatch
.x:
	rts

; Voice X's channel: patch A (0 the chord's, 1 the lead's). Keeps X.
ChanPatch:
	subroutine
	sta vPat,x
	stx exV
	ldy #3                  ; (t0-t3: ApplyVoices' and the caller's)
.sv:
	lda t0,y
	pha
	dey
	bpl .sv
	lda vPat,x
	tay
	beq .go
	jsr PatchSwap           ; (the lead's in livePatch for a moment)
.go:
	ldx exV
	lda vDev,x
	bne .midi
	lda vIdx,x
	tax
	jsr SidVoiceRegs
	jmp .back
.midi:
	cmp #DEV_GB
	bne .nes
	lda devOn+DEV_GB
	beq .back
	lda vIdx,x
	sta t3
	jsr GbChan
	jmp .back
.nes:
	lda devOn+DEV_NES
	beq .back
	lda vIdx,x
	cmp #2
	bcs .back
	tax
	jsr NesDutyCh
.back:
	ldx exV
	lda vPat,x
	beq .x
	jsr PatchSwap
.x:
	ldy #0
.rs:
	pla
	sta t0,y
	iny
	cpy #4
	bne .rs
	ldx exV
	rts

; livePatch <-> leadPatch (the patch's bytes). Keeps X.
PatchSwap:
	subroutine
	txa
	pha
	ldx #PATCH_SIZE-1
.s:
	lda livePatch,x
	ldy leadPatch,x
	sta leadPatch,x
	tya
	sta livePatch,x
	dex
	bpl .s
	pla
	tax
	rts

; SoundApply: the chord's patch went to every channel; the lead's voices
; sounding get theirs back
LeadReapply:
	subroutine
	ldx #NUM_VOICES-1
.v:
	lda #0
	sta vPat,x
	lda vLead,x
	beq .n
	lda vNote,x
	cmp #NO_NOTE
	beq .n
	lda #1
	jsr ChanPatch
.n:
	dex
	bpl .v
	rts

; SHIFT + A S D F G with CHORD + LEAD on: the lead's bank (X)
LeadBank:
	subroutine
	stx leadBank
	txa
	asl
	asl
	adc leadBank
	sta t2
	adc leadSlot
	tay
	lda bankSlot,y
	cmp #$FF
	bne LeadLoad
	ldy t2                  ; (empty: the bank's first)
	ldx #0
.f:
	lda bankSlot,y
	cmp #$FF
	bne .first
	iny
	inx
	cpx #5
	bne .f
	rts
.first:
	stx leadSlot
	jmp LeadLoad

; SHIFT + Z X C V B: the lead's patch in its bank (X = slot)
LeadSlot:
	subroutine
	stx t3
	lda leadBank
	asl
	asl
	adc leadBank
	adc t3
	tay
	lda bankSlot,y
	cmp #$FF
	beq .x
	ldx t3
	stx leadSlot
	jmp LeadLoad
.x:
	rts

; A = built-in patch: the lead's patch
LeadLoad:
	subroutine
	tax
	lda patchLo,x
	sta .src+1
	lda patchHi,x
	sta .src+2
	ldy #PATCH_SIZE-1
.src:
	lda $FFFF,y
	sta leadPatch,y
	dey
	bpl .src
	ldx #NUM_VOICES-1       ; the lead's channels: theirs again when next used
.v:
	lda vPat,x
	beq .n
	lda #$FF
	sta vPat,x
	lda vLead,x
	beq .n
	lda vNote,x
	cmp #NO_NOTE
	beq .n
	lda #1
	jsr ChanPatch           ; (sounding now: at once)
.n:
	dex
	bpl .v
	jmp Dirty

; CHORD + LEAD changed: nothing held over
ClHook:
	ldx #0
	lda clMode
	cmp #CL_KEY
	bne .k
	inx
.k:
	stx clKeyOn
	ldx #0
	lda clMode
	beq .o
	inx
.o:
	stx clOn
	lda #$FF
	sta clChordIdx
	sta clLeadIdx
	lda #0
	sta clChordN
	lda #1
	sta reallocFlag
	jsr Dirty
	lda menuOn              ; (the menu: KEY's rows come or go)
	beq .x
	jmp MenuDraw
.x:
	rts

; the SID's octave for SID voice Y: the lead's on its voice (A = note + it)
SidOct:
	subroutine
	cpy #LEAD_SID/3
	bne .c
	ldx vLead+LEAD_SID
	beq .c
	clc
	adc leadPatch+sndOct-livePatch
	rts
.c:
	clc
	adc sndOct
	rts

; row 3 of the play screen (v0.36): SPLIT's mode (KEY: and the note it
; splits at), then the lead: its octave and patch, dark while SPLIT is off
ScrLead:
	subroutine
	lda clMode
	asl
	tax
	lda splitTxt,x
	sta ptr
	lda splitTxt+1,x
	sta ptr+1
	ldx #0
	ldy #3
	jsr PrintAt
	lda clMode
	cmp #CL_KEY
	bne .l
	lda splitKey
	clc
	adc octBase
	jsr NoteBuf
	ldx #10
	ldy #3
	jsr PrintAt
.l:
	lda leadOct             ; (8 bytes each)
	asl
	asl
	asl
	clc
	adc #<txtLeadOct
	sta ptr
	lda #>txtLeadOct
	adc #0
	sta ptr+1
	ldx #14
	ldy #3
	jsr PrintAt
	lda #<(leadPatch+patchName-livePatch)
	sta ptr
	lda #>(leadPatch+patchName-livePatch)
	sta ptr+1
	ldx #22
	ldy #3
	jsr PrintAt
	ldx #0                  ; the lead's part: dark grey while SPLIT is off
	ldy #3
	jsr ScreenAddr
	lda ptr2+1
	clc
	adc #>(COLRAM-SCREEN)
	sta ptr2+1
	lda #13
	ldx clMode
	bne .c
	lda #11
.c:
	ldy #14
.cc:
	sta (ptr2),y
	iny
	cpy #39
	bne .cc
	rts

splitTxt:   .word txtSpOff,txtSpKey,txtSpBass,txtSpTriad
txtSpOff:   .byte "SPLIT OFF     ",0
txtSpKey:   .byte "SPLIT KEY     ",0
txtSpBass:  .byte "SPLIT BASS    ",0
txtSpTriad: .byte "SPLIT TRIAD   ",0
txtLeadOct: .byte "LEAD -2",0,"LEAD -1",0,"LEAD  0",0,"LEAD +1",0,"LEAD +2",0
