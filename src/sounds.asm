; Fat Chip 64 - sounds (V), mono (C), Fat Bass, SID effects
;
; Each sound is a column in soundtab.asm (made by tools/gen_sounds.py): the
; SID's envelope, wave, width, filter, detune and effects; the Game Boy's
; parameters (sent once as CCs: it does its own LFOs and warble); the
; MidiNES's duty and envelope (CC7, nesenv.asm). FAT, PADS and RAW are
; v0.11's; the rest are demo versions of the Chip Lab sounds.
;
; Each sound has a mono default and a Fat Bass default:
;   MONO      one note (the last key pressed and still held) on every voice;
;             a new key while another is held changes the pitch without a
;             new attack (legato; the Game Boy glides if the sound has glide)
;   FAT BASS  the Game Boy wave and the NES triangle play the lowest note,
;             folded by octaves into E1-E2 (BASS_LO-BASS_HI); off, they join
;             the other voices
;
; SID effects, every 4 ms (FxTick): filter LFO and envelope, pulse-width LFO
; (each voice its own phase), vibrato (all voices in step unless the sound
; spreads them), glide; and the duty sequence (SID width steps, NES CC1).

; ------------------------------------------------------------ choosing
; V: next sound (SHIFT+V: previous)
SoundKey:
	subroutine
	jsr SoundRelease        ; held notes end with the old sound's settings...
	ldx soundMode
	lda shiftDown
	bne .prev
	inx
	cpx #NUM_SOUNDS
	bcc .s
	ldx #0
	beq .s
.prev:
	dex
	bpl .s
	ldx #NUM_SOUNDS-1
.s:
	jmp SoundSetX

; X = sound (the keytar's voice buttons)
SoundSet:
	txa
	pha
	jsr SoundRelease
	pla
	tax
SoundSetX:
	stx soundMode
	jsr SoundVars
	jsr SoundApply          ; ...and come back with the new one
	jmp Dirty

; C: POLY <-> MONO (each sound picks one when chosen; this overrides it)
MonoKey:
	subroutine
	lda monoMode
	eor #1
	sta monoMode
	jsr GbLegato
	lda #1
	sta reallocFlag
	jmp Dirty

; Every Game Boy / NES voice lets go now (no soft releases), so nothing
; sounding depends on the old sound's octave or bass settings. The next
; voice update plays the held notes again.
SoundRelease:
	subroutine
	lda #1
	sta hardCut
	ldx #0
.v:
	stx t0
	lda vDev,x
	beq .n
	lda vOut,x
	cmp #NO_NOTE
	beq .n0
	lda #NO_NOTE
	jsr MidiTo
.n0:
	ldx t0
	lda #NO_NOTE
	sta vNote,x
.n:
	ldx t0
	inx
	cpx #NUM_VOICES
	bne .v
	lda #0
	sta hardCut
	jsr NesEnvReset
	lda #1
	sta reallocFlag
	rts

; RAM copies of the sound's settings that the busy code reads
SoundVars:
	subroutine
	ldx soundMode
	lda sndMono,x
	sta monoMode
	jsr FatBassSet
	lda nesEnv,x
	sta nesEnvOn
	lda nesAtk,x
	sta envAtkV
	lda nesDec,x
	sta envDecV
	lda nesSus,x
	sta envSusV
	lda nesPeak,x
	sta envPeakV
	lda nesRel,x
	sta envRelV
	lda #0
	sta fEnv
	sta dutyIdx
	sta dutyMs
	jsr RepeatFromSound
	jmp FxVars

; fatBass from the sound, unless the menu locks it (ALWAYS / NEVER)
FatBassSet:
	subroutine
	ldx soundMode
	lda sndFat,x
	ldy fbLock
	beq .s
	lda #1
	cpy #1
	beq .s
	lda #0
.s:
	sta fatBass
	rts

; Menu: Fat Bass lock changed
FatBassMenu:
	jsr SoundRelease
	jsr FatBassSet
	jmp Dirty

; The vibrato and glide FxTick uses: the sound's, or the keytar buttons'
; while held (a sound without vibrato gets 0.25 semitone at 5.5 Hz, no
; delay; one without glide gets 1/16 of the way per 4 ms)
FxVars:
	subroutine
	ldx soundMode
	lda sndVib,x
	sta vibDepth
	lda sndVibRL,x
	sta vibRL
	lda sndVibRH,x
	sta vibRH
	lda sndVibDel,x
	sta vibDel
	lda sndVibSpr,x
	sta vibSpr
	lda vibBtn
	beq .g
	lda #0
	sta vibDel
	lda vibDepth
	bne .g
	lda #61
	sta vibDepth
	lda #<1442
	sta vibRL
	lda #>1442
	sta vibRH
.g:
	lda sndGlide,x
	bne .gs
	lda glideBtn
	beq .gs
	lda #4
.gs:
	sta glideK
	lda sndFDep,x           ; anything for FxTick to do?
	ora sndFEnv,x
	ora sndPwm,x
	ora vibDepth
	ora glideK
	ora sndSeq,x
	beq .b
	lda #1
.b:
	sta fxBusy
	rts

; A keytar button changed vibrato / glide: the SID's (FxVars) and the Game
; Boy's (its LFO and glide CCs while held; the sound's back when let go)
FxButtons:
	subroutine
	jsr FxVars
	lda vibDepth            ; no vibrato now: the SID back on pitch
	bne .v
	sta vibAmt
	sta vibAmt+1
	sta vibAmt+2
	jsr SidBendAll
.v:
	lda devOn+DEV_GB
	bne .gb
	rts
.gb:
	lda #0
	sta t3
.ch:
	lda gbBase
	clc
	adc t3
	and #15
	ora #$B0
	sta mS
	ldx soundMode
	; glide (CC 5)
	ldy t3
	lda gbGl1,x
	cpy #0
	beq .g1
	lda gbGl2,x
	cpy #1
	beq .g1
	lda gbGlW,x
.g1:
	ldy glideBtn
	beq .g2
	cmp #32
	bcs .g2
	lda #32                 ; glide 4 of 15
.g2:
	tay
	lda #5
	jsr SoundGbPut
	ldy t3
	cpy #2
	beq .next               ; (the wave channel has no LFO here)
	lda vibBtn
	beq .lfoSound
	lda #78                 ; LFO to pitch, triangle, rate 22, no delay, depth 6
	ldy #0
	jsr SoundGbPut
	lda #77
	ldy #0
	jsr SoundGbPut
	lda #76
	ldy #91
	jsr SoundGbPut
	lda #79
	ldy #0
	jsr SoundGbPut
	lda #1
	ldy #24
	jsr SoundGbPut
	jmp .next
.lfoSound:
	jsr SoundGbLfo
.next:
	inc t3
	lda t3
	cmp #3
	bne .ch
	rts

SoundApply:
	subroutine
	jsr SoundSid
	jsr SoundGb
	jmp SoundNes

; ------------------------------------------------------------ SID
SoundSid:
	subroutine
	ldx #2
.v:
	ldy sidOfs,x
	stx t1
	ldx soundMode
	lda sndAD,x
	sta SID+5,y
	lda sndSR,x
	sta SID+6,y
	lda sndWave,x
	sta t0
	lda sndPwLo,x
	sta SID+2,y
	lda sndPwHi,x
	cpx #SND_RAW
	bne .pw
	ldx t1                  ; RAW: each SID voice its own width
	lda rawPwHi,x
.pw:
	sta SID+3,y
	ldx t1
	lda sidGate,x
	and #1
	ora t0
	sta sidGate,x
	sta SID+4,y
	dex
	bpl .v
	ldx soundMode
	lda sndCut,x
	beq .noFilt
	sta SID+$16
	lda sndRes,x            ; resonance, voices 1-3 through the filter
	sta SID+$17
	lda #$10                ; low-pass
	sta sidFilt
	bne .vol
.noFilt:
	lda #0
	sta SID+$17
	sta sidFilt
.vol:
	jmp SidVolume

rawPwHi:    .byte $08, $04, $02   ; RAW SID widths: 50%, 25%, 12.5%

; ------------------------------------------------------------ Game Boy
; The sound's parameters as CCs (also sent again by GbStartup)
SoundGb:
	subroutine
	lda devOn+DEV_GB
	bne .on
	rts
.on:
	lda #0
	sta t3                  ; channel 0-2: pulse 1, pulse 2, wave
.ch:
	lda gbBase
	clc
	adc t3
	and #15
	ora #$B0
	sta mS
	ldx soundMode
	lda #73
	ldy gbAtk,x
	jsr .put
	lda #75
	ldy gbDec,x
	jsr .put
	lda #72
	ldy gbRel,x
	jsr .put
	ldy t3                  ; glide per channel
	lda gbGl1,x
	cpy #0
	beq .gl
	lda gbGl2,x
	cpy #1
	beq .gl
	lda gbGlW,x
.gl:
	tay
	lda #5
	jsr .put
	ldy t3                  ; level: pulses / wave
	lda gbLvl,x
	cpy #2
	bne .lv
	lda gbLvlW,x
.lv:
	tay
	lda #7
	jsr .put
	ldy #62                 ; bend range 12 semitones (Fat Chip 64 scales its bends)
	lda #85
	jsr .put
	ldy t3
	cpy #2
	beq .wave
	; ---- pulses: duty, detune, LFO
	lda gbDuty1,x
	cpy #0
	beq .d
	lda gbDuty2,x
.d:
	tay
	lda #70
	jsr .put
	ldy t3
	lda gbDetA,x
	cpy #0
	beq .dt
	lda gbDetB,x
.dt:
	tay
	lda #94
	jsr .put
	jsr SoundGbLfo
	inc t3
	jmp .ch
.wave:
	lda #71
	ldy gbWMode,x
	jsr .put
	lda #70
	ldy gbWShape,x
	jsr .put
	jsr GbLegato
	ldx soundMode
	lda #GCC_WSPEED
	ldy gbWSpd,x
	sty t0
	ldx t0
	jsr GbGlobal
	ldx soundMode
	lda #GCC_WARBLE
	ldy gbWarb,x
	sty t0
	ldx t0
	jmp GbGlobal
.put:
	jmp SoundGbPut

; A = CC, Y = value, on channel mS (keeps X)
SoundGbPut:
	sta mD1
	sty mD2
	stx t2
	jsr GbPut
	ldx t2
	rts

; the sound's LFO on channel mS (X = soundMode; keeps X)
SoundGbLfo:
	lda #76
	ldy gbLRate,x
	jsr SoundGbPut
	lda #77
	ldy gbLShape,x
	jsr SoundGbPut
	lda #78
	ldy gbLDest,x
	jsr SoundGbPut
	lda #79
	ldy gbLDelay,x
	jsr SoundGbPut
	lda #1
	ldy gbLDepth,x
	jmp SoundGbPut

; Legato (CC 68) on the three note channels: on in MONO, so a new note on a
; sounding voice changes pitch without a new attack
GbLegato:
	subroutine
	lda devOn+DEV_GB
	beq .x
	lda #68
	sta mD1
	lda #0
	ldx monoMode
	beq .v
	lda #127
.v:
	sta mD2
	ldy #0
.c:
	tya
	clc
	adc gbBase
	and #15
	ora #$B0
	sta mS
	jsr GbPut
	iny
	cpy #3
	bne .c
.x:
	rts

; ------------------------------------------------------------ MidiNES
; Duty (CC 1) on both pulses; full volume when the sound has no envelope
SoundNes:
	subroutine
	lda devOn+DEV_NES
	beq .x
	jsr NesDuty
	lda nesEnvOn
	bne .x
	jmp NesFullVolume
.x:
	rts

NesDuty:
	subroutine
	lda devOn+DEV_NES
	beq .x
	lda #1
	sta mD1
	ldx soundMode
	lda nesDuty1,x
	sta mD2
	lda nesBase
	ora #$B0
	sta mS
	jsr NesPut
	ldx soundMode
	lda nesDuty2,x
	sta mD2
	lda nesBase
	clc
	adc #1
	and #15
	ora #$B0
	sta mS
	jmp NesPut
.x:
	rts

; ------------------------------------------------------------ voices
; A = note for voice t0 -> the note it sends: Fat Bass folds the bass
; voices' note into BASS_LO-BASS_HI; the sound may put the Game Boy pulses
; up an octave. Keeps X (= t0).
MidiNoteValue:
	subroutine
	ldx t0
	ldy vBass,x
	beq .gb
	ldy fatBass
	beq .x
.dn:
	cmp #BASS_HI+1
	bcc .up
	sbc #12
	jmp .dn
.up:
	cmp #BASS_LO
	bcs .x
	adc #12
	jmp .up
.gb:
	ldy vDev,x
	cpy #DEV_GB
	bne .x
	ldy soundMode
	clc
	adc gbOct,y
.x:
	rts

; MONO: the last key pressed that still sounds (else the highest held note)
MonoNote:
	subroutine
	ldy playCount
.p:
	dey
	bmi .hi
	ldx playOrder,y
	lda noteHeld,x
	beq .p
	jmp IdxNote
.hi:
	ldx heldCount
	lda heldList-1,x
	rts

; ------------------------------------------------------------ effects
; Main loop, on a pass the keyboard and screen don't need: catch up with the
; 4 ms steps since last time (fxN of them, at most 4). LFO phases, envelopes,
; vibrato delays and glides move fxN steps; the SID registers are written once.
FxTick:
	subroutine
	lda ticks
	sec
	sbc fxLast
	cmp #FX_EVERY
	bcs .go
	rts
.go:
	cmp #FX_EVERY*4
	bcc .n
	lda ticks               ; far behind: count 4 steps, start again from now
	sta fxLast
	lda #4
	bne .st
.n:
	lsr
	lsr                     ; (FX_EVERY = 4)
	pha
	asl
	asl
	clc
	adc fxLast
	sta fxLast
	pla
.st:
	sta fxN
	jsr SeqTick
	lda devOn+DEV_SID
	bne SidFx
	rts

; X = soundMode: phase (ptr2 -> 2 bytes) += rate x fxN
	mac ADVANCE             ; {1} phase lo, {2} rate lo, {3} rate hi
	ldy fxN
.adv{1}:
	lda {1}
	clc
	adc {2},x
	sta {1}
	lda {1}+1
	adc {3},x
	sta {1}+1
	dey
	bne .adv{1}
	endm

SidFx:
	subroutine
	ldx soundMode
	; ---- filter: cutoff = base + LFO + envelope
	lda sndCut,x
	beq .noF
	sta t0
	lda sndFDep,x
	beq .fenv
	ADVANCE fPhL, sndFRateL, sndFRateH
	lda fPhH
	jsr Tri                 ; 0-127
	ldy sndFDep,x
	jsr Mul8                ; tri x depth
	asl mt16
	lda mt16+1
	rol                     ; >> 7
	clc
	adc t0
	bcc .f1
	lda #$FF
.f1:
	sta t0
.fenv:
	lda fEnv
	beq .wr
	clc
	adc t0
	bcc .f2
	lda #$FF
.f2:
	sta t0
	ldy fxN                 ; falls back: -1/16 - 1 per 4 ms
.fd:
	lda fEnv
	lsr
	lsr
	lsr
	lsr
	sec
	adc #0                  ; (+1)
	sta t1
	lda fEnv
	sec
	sbc t1
	bcs .fe
	lda #0
.fe:
	sta fEnv
	dey
	bne .fd
.wr:
	lda t0
	sta SID+$16
.noF:
	; ---- width LFO: one voice per call (width = base + tri x depth / 8,
	; each voice its own phase)
	ldx soundMode
	lda sndPwm,x
	beq .noP
	ADVANCE pPhL, sndPwmRL, sndPwmRH
	ldy fxVoice
	iny
	cpy #3
	bcc .vy
	ldy #0
.vy:
	sty fxVoice
	lda pPhH
	clc
	adc pwPhase,y
	jsr Tri
	ldy sndPwm,x
	jsr Mul8
	lsr mt16+1
	ror mt16
	lsr mt16+1
	ror mt16
	lsr mt16+1
	ror mt16                ; / 8
	ldy fxVoice
	ldx sidOfs,y
	ldy soundMode
	lda mt16
	clc
	adc sndPwLo,y
	sta SID+2,x
	lda mt16+1
	adc sndPwHi,y
	sta SID+3,x
.noP:
	; ---- pitch: glide and vibrato, every sounding voice
	lda vibDepth
	ora glideK
	bne .pitch
	rts
.pitch:
	lda vibDepth
	beq .noVp
	ldy fxN
.va:
	lda vPhL
	clc
	adc vibRL
	sta vPhL
	lda vPhH
	adc vibRH
	sta vPhH
	dey
	bne .va
	jsr VibLfo              ; vibNow: the in-step amount (if not spread)
.noVp:
	ldy #0
.sv:
	sty envY                ; (SID voice 0-2; envY is free here)
	lda sidVoice,y
	tax
	lda vNote,x
	cmp #NO_NOTE
	beq .next
	jsr GlideStep
	jsr VibStep
	ldy envY
	jsr SidFreqOut
.next:
	ldy envY
	iny
	cpy #3
	bne .sv
	rts

sidVoice:   .byte 0,3,6         ; SID voice -> pool voice

; SID voice envY: sidBase moves 1/2^k of the way to sidTgt, fxN times
GlideStep:
	subroutine
	lda glideK
	bne .on
	rts
.on:
	lda fxN
	sta bT1
.again:
	lda glideK
	sta t1
	ldy envY
	lda sidTgtLo,y
	sec
	sbc sidBaseLo,y
	sta t2
	lda sidTgtHi,y
	sbc sidBaseHi,y
	sta t3                  ; t3:t2 = target - now (signed)
	ora t2
	beq .x
	ldx t1
.sh:
	lda t3
	cmp #$80                ; arithmetic shift right
	ror t3
	ror t2
	dex
	bne .sh
	lda t2
	ora t3
	beq .snap
	lda t3
	cmp #$FF
	bne .add
	lda t2
	cmp #$FF                ; -1 also snaps (a shift never reaches 0 going down)
	beq .snap
.add:
	lda sidBaseLo,y
	clc
	adc t2
	sta sidBaseLo,y
	lda sidBaseHi,y
	adc t3
	sta sidBaseHi,y
	dec bT1
	bne .again
.x:
	rts
.snap:
	lda sidTgtLo,y
	sta sidBaseLo,y
	lda sidTgtHi,y
	sta sidBaseHi,y
	rts

; vibNow = signed tri LFO x depth / 128 at phase A
VibAt:
	subroutine
	jsr Tri                 ; 0-127 -> signed: tri x 2 - 127
	asl
	sec
	sbc #127
	php
	bcs .pos
	eor #$FF
	adc #1
.pos:
	ldy vibDepth
	jsr Mul8
	asl mt16
	rol mt16+1              ; / 128
	lda mt16+1
	plp
	bcs .st
	eor #$FF
	clc
	adc #1
.st:
	sta vibNow
	rts

; once per call: the shared vibrato (voices in step)
VibLfo:
	subroutine
	lda vibSpr
	bne .x
	lda vPhH
	jmp VibAt
.x:
	rts

; SID voice envY: vibAmt after its delay (4 ms steps since its attack)
VibStep:
	subroutine
	ldy envY
	lda #0
	sta vibAmt,y
	lda vibDepth
	beq .x
	lda vibT,y
	cmp vibDel
	bcs .on
	adc fxN                 ; (carry clear)
	bcc .t
	lda #255
.t:
	sta vibT,y
	rts
.on:
	lda vibSpr
	beq .same
	lda vPhH                ; spread: each voice its own phase
	clc
	adc pwPhase,y
	jsr VibAt
	ldy envY
.same:
	lda vibNow
	sta vibAmt,y
.x:
	rts

; ---- duty sequence: SID widths and / or NES CC1, one step per sndSeqMs
SeqTick:
	subroutine
	jmp .go
.no:
	rts
.go:
	ldx soundMode
	lda sndSeq,x
	beq .no
	lda dutyMs
	clc
	adc fxN
	sta dutyMs
	cmp sndSeqMs,x
	bcc .no
	lda #0
	sta dutyMs
	ldy sndSeq,x
	inc dutyIdx
	lda dutyIdx
	cmp seqLen-1,y
	bcc .i
	lda #0
	sta dutyIdx
.i:
	clc
	adc seqStart-1,y
	tay
	lda seqData,y
	sta t0                  ; duty 0-3
	lda sndSeqSid,x
	beq .nes
	lda devOn+DEV_SID
	beq .nes
	ldy t0
	lda dutyPw,y
	sta SID+3
	sta SID+3+7
	sta SID+3+14
	lda #0
	sta SID+2
	sta SID+2+7
	sta SID+2+14
.nes:
	lda devOn+DEV_NES
	beq .x
	lda vOut+2              ; a NES pulse sounding?
	and vOut+5
	cmp #NO_NOTE
	beq .x
	lda nesqHead            ; queue busy: skip this step
	sec
	sbc nesqTail
	and #63
	cmp #Q_BACKLOG
	bcs .x
	lda #1
	sta mD1
	lda t0
	asl
	asl
	asl
	asl
	asl                     ; x 32
	sta mD2
	lda nesBase
	ora #$B0
	sta mS
	jsr NesPut
	lda nesBase
	clc
	adc #1
	and #15
	ora #$B0
	sta mS
	jmp NesPut
.x:
	rts

seqLen:     .byte 4, 6
seqStart:   .byte 0, 4
seqData:    .byte 0,1,2,1, 0,1,2,3,2,1   ; 1: lead, 2: shimmer
dutyPw:     .byte $02,$04,$08,$0C        ; 12.5 / 25 / 50 / 75%

; mt16 = A x Y (8 x 8). Keeps X.
Mul8:
	subroutine
	sta mulB
	sty mulB+1
	lda #0
	sta mt16+1
	ldy #8
.l:
	lsr mulB
	bcc .n
	clc
	adc mulB+1
.n:
	ror
	ror mt16
	dey
	bne .l
	sta mt16+1
	rts

; mulR+0..2 (24 bits) = mulA (16) x A (8). Keeps X and Y.
Mul16x8:
	subroutine
	sta mulB
	tya
	pha
	lda #0
	sta mulR+1
	sta mulR+2
	ldy #8
.l:
	lsr mulB
	bcc .n
	lda mulR+1
	clc
	adc mulA
	sta mulR+1
	lda mulR+2
	adc mulA+1
	jmp .s
.n:
	clc
	lda mulR+2
.s:
	ror
	sta mulR+2
	ror mulR+1
	ror mulR
	dey
	bne .l
	pla
	tay
	rts

; SID frequency bT3:bT2 x (1 + A / 4096), A signed (vibrato), using the
; high byte only (cheap; the error is under 1/256 of the vibrato). Keeps Y.
SidVib:
	subroutine
	sta bT1                 ; (the sign)
	cmp #$80
	bcc .p
	eor #$FF
	adc #0                  ; (carry set: +1)
.p:
	sty bT0
	tay
	lda bT3
	jsr Mul8                ; f high byte x |amt|
	ldy bT0
	lsr mt16+1              ; / 16
	ror mt16
	lsr mt16+1
	ror mt16
	lsr mt16+1
	ror mt16
	lsr mt16+1
	ror mt16
	lda bT1
	bmi .down
	lda bT2
	clc
	adc mt16
	sta bT2
	lda bT3
	adc mt16+1
	sta bT3
	rts
.down:
	lda bT2
	sec
	sbc mt16
	sta bT2
	lda bT3
	sbc mt16+1
	sta bT3
	rts
