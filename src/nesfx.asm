; Fat Chip 64 - MidiNES vibrato, glide and detune (v0.15), with pitch bend
;
; The MidiNES has no vibrato, glide or detune of its own, so Fat Chip 64
; bends each NES channel itself, on top of the SPACE / wheel / VINYL bends:
;   detune   the pulses apart: pulse 1 down, pulse 2 up, by the SID's detune
;            (FAT about 1/16 semitone each way; WIDE more)
;   vibrato  the SID's vibrato (depth, rate, delay, spread; TAPE WOBBLE) on
;            the two pulses (the triangle is usually the bass: it stays put)
;   glide    a new note starts bent back to the voice's last note and slides
;            in the way the SID's does (all three channels)
; Bends go out every NFX_EVERY ms at most, only when they change, and only
; while the NES queue has room. The MidiNES moves in steps of about 1/16
; semitone, so these are a little stepped.

NFX_EVERY   equ 8               ; ms between steps: one NES channel a step
	                        ;  (the pulses, and the triangle while it glides)

; A = 1 (not Z) when a NesFxTick step is due
NesFxDue:
	subroutine
	lda devOn+DEV_NES
	beq .x
	lda vibDepth
	ora nfxGlide
	ora nfxRun
	beq .x
	lda ticks
	sec
	sbc nfxLast
	cmp #NFX_EVERY
	lda #0
	bcc .x
	lda #1
.x:
	rts

; From FxTick, on a pass of its own (the effects' passes). Nothing to do (no vibrato, no glide
; moving, no effects change to catch up with: nfxRun, set by FxVars): a
; quick return.
NesFxTick:
	subroutine
	lda devOn+DEV_NES
	beq .q
	lda vibDepth
	ora nfxGlide
	ora nfxRun
	bne .on
.q:
	rts
.on:
	lda ticks
	sec
	sbc nfxLast
	cmp #NFX_EVERY
	bcs .go
	rts
.go:
	lsr
	lsr                     ; 4 ms steps
	cmp #8
	bcc .n
	lda #8
.n:
	sta nfxN
	lda ticks
	sta nfxLast
	; ---- vibrato phase, the voices' delay counters, glides
	ldy nfxN
.ph:
	lda nvPhL
	clc
	adc vibRL
	sta nvPhL
	lda nvPhH
	adc vibRH
	sta nvPhH
	dey
	bne .ph
	lda #0
	sta nfxGlide
	ldx #8                  ; (the NES voices: 2, 5, 8)
.v:
	lda nesVT,x
	clc
	adc nfxN
	bcc .vt
	lda #255
.vt:
	sta nesVT,x
	jsr NesGlideStep
	lda nesGlL,x
	ora nesGlH,x
	ora nfxGlide
	sta nfxGlide            ; (still gliding)
	dex
	dex
	dex
	bpl .v
	; ---- the NES queue needs room
	lda nesqHead
	sec
	sbc nesqTail
	and #63
	cmp #Q_BACKLOG
	bcs .x
	; ---- the next NES voice: a bend if its effects moved
	lda nfxRun              ; (a few rounds after an effects change)
	beq .r
	dec nfxRun
.r:
	ldx nfxV                ; (2, 5, 8)
	inx
	inx
	inx
	cpx #NUM_VOICES
	bcc .nv
	ldx #2
.nv:
	cpx #8                  ; the triangle only while it glides or is bent
	bne .t
	lda nesGlL,x
	ora nesGlH,x
	ora nesBent,x
	bne .t
	ldx #2
.t:
	stx nfxV
	stx t0
	lda vOut,x
	cmp #NO_NOTE
	beq .x
	jsr NesFxVal
	ldx t0
	lda nfxL
	cmp nesFxSL,x
	bne .send
	lda nfxH
	cmp nesFxSH,x
	beq .x
.send:
	lda #1
	sta nfxHave             ; (NesBendVoice: nfx is this voice's already)
	lda vOut,x
	jmp NesBendVoice
.x:
	rts

; voice X's glide offset closer to 0: by off / 2^glideK for each 4 ms step
; (worked out once: d = off >> k, off -= d x n; past 0 or nothing left to
; move by: there). Keeps X.
NesGlideStep:
	subroutine
	lda nesGlL,x
	ora nesGlH,x
	bne .go
	rts
.go:
	lda nesGlL,x
	sta nfxL
	lda nesGlH,x
	sta nfxH
	ldy nesK,x              ; (BEND IN: its own)
	bne .sh
	ldy glideK
	bne .sh
	ldy #2                  ; (glide switched off mid-slide: finish quickly)
.sh:
	lda nfxH
	cmp #$80
	ror nfxH
	ror nfxL
	dey
	bne .sh
	lda nfxL                ; d = 0 or -1: there
	ora nfxH
	beq .snap
	lda nfxL
	and nfxH
	cmp #$FF
	beq .snap
	; total = d x n (n = 1-8: shift and add)
	lda #0
	sta nfxTL
	sta nfxTH
	lda nfxN
	sta nfxC
.m:
	lsr nfxC
	bcc .m2
	lda nfxTL
	clc
	adc nfxL
	sta nfxTL
	lda nfxTH
	adc nfxH
	sta nfxTH
.m2:
	asl nfxL
	rol nfxH
	lda nfxC
	bne .m
	lda nesGlL,x
	sec
	sbc nfxTL
	sta nfxC
	lda nesGlH,x
	sbc nfxTH
	eor nesGlH,x            ; crossed 0 (the sign changed): there
	bmi .snap
	eor nesGlH,x
	sta nesGlH,x
	lda nfxC
	sta nesGlL,x
	rts
.snap:
	lda #0
	sta nesGlL,x
	sta nesGlH,x
	sta nesK,x
	lda #3                  ; (one more round: the last bend, centred)
	sta nfxRun
.x:
	rts

; NES voice X starts note A: its glide from the last note it played (when
; something glides), the vibrato delay from now. Keeps X.
NesNoteStart:
	subroutine
	sta nfxK
	lda #0
	sta nesVT,x
	lda vsGlide
	beq .no
	lda nesLast,x
	cmp #NO_NOTE
	beq .no
	sec
	sbc nfxK                ; last - new semitones (an octave at most)
	bvs .no
	bmi .neg
	cmp #13
	bcc .set
	lda #12
	bne .set
.neg:
	cmp #256-12
	bcs .set
	lda #256-12
.set:
	sta nesGlH,x            ; x 256 = 1/256 semitones
	sta nfxGlide
	lda #0
	sta nesGlL,x
	beq .l
.no:
	lda #0
	sta nesGlL,x
	sta nesGlH,x
	lda sndPenv             ; BEND IN: a new note starts away (not legato)
	beq .l
	ldy legatoNow
	bne .l
	sta nesGlH,x
	lda #0
	sta nesGlL,x
	lda #1
	sta nfxGlide
	lda sndPenvK
	sta nesK,x
.l:
	lda nfxK
	sta nesLast,x
	; a pulse's bend per 1/16 semitone at this note (x 16), for the quick
	; small bends (NesBendVoice); 0 = use the full sum
	lda #0
	sta nesUnL,x
	sta nesUnH,x
	lda vIdx,x
	cmp #2
	beq .u
	stx nfxX
	lda nfxK
	jsr MidiNoteValue       ; (t0 = the voice)
	ldx nfxX
	cmp #TRI_FLOOR+13       ; (no room to bend down at the bottom)
	bcc .u
	tay
	lda triPbLo,y
	sta mulA
	lda triPbHi,y
	sta mulA+1
	lda #59                 ; nesDn[1]: p x 59 / 4096 a sixteenth, x 16
	jsr Mul16x8
	lda mulR+1
	sta nesUnL,x
	lda mulR+2
	sta nesUnH,x
.u:
	rts

; nfxH:nfxL = voice X's effects in 1/64 semitones (signed): detune and
; vibrato on the pulses, glide on all three. Keeps X (uses Y).
NesFxVal:
	subroutine
	lda nfxHave             ; just worked out (NesFxTick)
	beq .w
	lda #0
	sta nfxHave
	rts
.w:
	stx nfxX
	; glide: 1/256 -> 1/64 semitones
	lda nesGlH,x
	sta nfxH
	lda nesGlL,x
	sta nfxL
	ldy #2
.g:
	lda nfxH
	cmp #$80
	ror nfxH
	ror nfxL
	dey
	bne .g
	lda tuneN               ; FINE TUNE, Synthcart TUNE TO: every channel
	beq .tn
	jsr .add
.tn:
	lda vIdx,x
	cmp #2
	beq .x                  ; the triangle: glide only (and the tuning)
	sta nfxK                ; pulse 0 / 1
	; detune: (detNow + 1) / 2 sixty-fourths, pulse 1 down, pulse 2 up
	lda detNow
	clc
	adc #1
	lsr
	ldy nfxK
	bne .up
	eor #$FF
	clc
	adc #1
.up:
	jsr .add
	; vibrato: after the delay, the SID's LFO (pulse 2 a quarter turn on
	; when the sound spreads it): vibNow / 16 sixteenths
	lda vibDepth
	beq .x
	ldx nfxX
	lda nesVT,x
	cmp vibDel
	bcc .x
	lda nvPhH
	ldy vibSpr
	beq .ph
	ldy nfxK
	beq .ph
	clc
	adc #64
.ph:
	jsr VibAt               ; vibNow (signed)
	lda vibNow              ; / 4: 1/64 semitones
	cmp #$80
	ror
	cmp #$80
	ror
	jsr .add
.x:
	ldx nfxX
	rts
.add:                           ; nfx += A (signed)
	pha
	clc
	adc nfxL
	sta nfxL
	pla
	and #$80
	beq .ap
	lda #$FF
.ap:
	adc nfxH
	sta nfxH
	rts
