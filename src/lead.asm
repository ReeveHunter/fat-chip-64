; Fat Chip 64 - CHORD + LEAD (v0.28): a chord and a lead at once, each its
; own patch.
;   LOW NOTE  the first key pressed is the chord's root (POLY: root and
;             fifth; SMART CHORD / EXT / DRONE: their chord); every other key
;             is the lead, while the chord key is held
;   LATCH 3   three keys pressed together latch as the chord (let go, it
;             keeps sounding); everything else is the lead. L clears it.
; The lead is one note (the last key pressed) on one voice per chip (SID 3,
; Game Boy pulse 1, NES pulse 1), only while it plays: the rest of the time
; those voices are the chord's. Its patch: SHIFT + A S D F G / Z X C V B.
; The lead's own: the SID's waveform, width, envelope and octave, the Game
; Boy pulse's CCs, the NES pulse's duty. Shared with the chord: the effects
; (vibrato, filter, tremolo...), the NES envelope.

LEAD_SID    equ 6               ; the lead's voices: SID 3, GB pulse 1, NES pulse 1
LEAD_GB     equ 1
LEAD_NES    equ 2

; NoteDown, CHORD + LEAD on: key X pressed. Carry set: it's the lead (the
; latch styles leave it alone).
ClPress:
	subroutine
	stx exI
	lda clMode
	cmp #2
	beq .l3
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
	sta leadNote
.c:
	lda #0
	sta heldCount
	lda clMode
	cmp #2
	beq .l3
	ldx clChordIdx
	bmi .x
	lda physKey,x
	beq .x
	jsr IdxNote
	sta exR
	jsr InsertNote
	lda effMode             ; POLY: root and fifth
	bne .x
	lda exR
	clc
	adc #7
	jmp InsertNote
.l3:
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
	lda #$FF
	sta clChordIdx
	sta clLeadIdx
	lda #0
	sta clChordN
	lda #1
	sta reallocFlag
	jmp Dirty

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

; row 3 of the play screen: the lead's patch (CHORD + LEAD on)
ScrLead:
	subroutine
	lda #<txtLeadOff
	ldy #>txtLeadOff
	ldx clMode
	beq .p
	lda #<txtLead
	ldy #>txtLead
.p:
	sta ptr
	sty ptr+1
	ldx #0
	ldy #3
	jsr PrintAt
	lda clMode
	beq .x
	lda #<(leadPatch+patchName-livePatch)
	sta ptr
	lda #>(leadPatch+patchName-livePatch)
	sta ptr+1
	ldx #8
	ldy #3
	jmp PrintAt
.x:
	rts

txtLead:    .byte "LEAD",0
txtLeadOff: .byte "                        ",0
