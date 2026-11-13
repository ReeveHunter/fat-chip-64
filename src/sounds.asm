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
	lda #0
	sta undoOk              ; (a roll on the old patch can't be undone now)
	lda patchSlot,x         ; its bank and slot, for the A-G / Z-B keys
	cmp #$FF
	beq .nb
	ldy #0
.b5:
	cmp #5
	bcc .bs
	sbc #5
	iny
	bne .b5
.bs:
	sta curSlot
	sty curBank
.nb:
	jsr PatchLoad
	jsr SoundVars
	jsr SoundApply          ; ...and come back with the new one
	jmp Dirty

;  built-in patch X -> livePatch, the patch everything plays from (keeps X)
PatchLoad:
	subroutine
	lda patchLo,x
	sta .src+1
	lda patchHi,x
	sta .src+2
	ldy #PATCH_SIZE-1
.src:
	lda $FFFF,y
	sta livePatch,y
	dey
	bpl .src
	rts

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
	jsr MonoSet
	jsr FatBassSet
	lda nesEnv
	sta nesEnvOn
	lda nesAtk
	sta envAtkV
	lda nesDec
	sta envDecV
	lda nesSus
	sta envSusV
	lda nesPeak
	sta envPeakV
	lda nesRel
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
	lda sndFat
	ldy fbLock
	beq .s
	lda #1
	cpy #1
	beq .s
	lda #0
.s:
	sta fatBass
	rts

; monoMode from the sound, unless the menu's MONO/POLY says (MONO / POLY)
MonoSet:
	subroutine
	ldx soundMode
	lda sndMono
	ldy monoLock
	beq .s
	lda #1
	cpy #1
	beq .s
	lda #0
.s:
	sta monoMode
	rts

; Menu: MONO/POLY changed
MonoMenu:
	jsr MonoSet
	jsr GbLegato
	lda #1
	sta reallocFlag
	jmp Dirty

; Menu: Fat Bass lock changed
FatBassMenu:
	jsr SoundRelease
	jsr FatBassSet
	jmp Dirty

; The vibrato, glide and detune the SID uses (FxTick, voices.asm). Each is
; the menu's choice: AS SOUND (the sound's), ON (the ADVANCED SOUND values),
; OFF. VIBRATO or GLIDE held turns on what's off (the ADVANCED SOUND values;
; a held VIBRATO has no delay); TAPE WOBBLE held: a deep slow vibrato, each
; voice its own phase; WIDE held: the detune about twice as wide.
FxVars:
	subroutine
	ldx soundMode
	; ---- vibrato
	ldy vibLock
	beq .vs
	cpy #1
	beq .vu
	lda #0                  ; OFF
	sta vibDepth
	sta vibSpr
	beq .vb
.vs:
	lda sndVib
	sta vibDepth
	lda sndVibRL
	sta vibRL
	lda sndVibRH
	sta vibRH
	lda sndVibDel
	sta vibDel
	lda sndVibSpr
	sta vibSpr
	jmp .vb
.vu:
	jsr VibUser
.vb:
	lda vibBtn
	beq .vw
	lda vibDepth
	bne .vb0
	jsr VibUser
.vb0:
	lda #0
	sta vibDel
.vw:
	lda actCnt+A_WOBBLE
	beq .g
	lda #WOB_DEPTH
	sta vibDepth
	lda #<WOB_RATE
	sta vibRL
	lda #>WOB_RATE
	sta vibRH
	lda #0
	sta vibDel
	lda #1
	sta vibSpr
	; ---- glide
.g:
	lda brVib               ; DH-100: the vibrato follows the breath
	beq .g0
	lda vibDepth
	bne .bv
	jsr VibUser
	lda #0
	sta vibDel
	lda vibDepth
.bv:
	jsr BreathScale
	sta vibDepth
.g0:
	ldy glideLock
	beq .gs
	cpy #1
	beq .gu
	lda #0
	beq .gb
.gs:
	lda sndGlide
	jmp .gb
.gu:
	ldy uGlide
	lda uGlideT,y
.gb:
	bne .gk
	ldy glideBtn
	beq .gk
	ldy uGlide
	lda uGlideT,y
.gk:
	sta glideK
	; ---- detune
	ldy detLock
	beq .ds
	cpy #1
	beq .du
	lda #0
	beq .dw
.ds:
	lda sndDet
	jmp .dw
.du:
	ldy uDet
	lda uDetT,y
.dw:
	ldy actCnt+A_WIDE
	beq .dk
	asl
	adc #6
	cmp #33
	bcc .dk
	lda #32
.dk:
	ldy brDet               ; DH-100: the detune follows the breath
	beq .dk1
	tay
	bne .bd
	lda uDetT+1
.bd:
	jsr BreathScale
.dk1:
	sta detNow
	; ---- anything for FxTick to do?
	lda sndFDep
	ora sndFEnv
	ora sndPwm
	ora vibDepth
	ora glideK
	ora sndSeq
	ora sweepLvl
	ora actCnt+A_SWEEP
	ora brFilt
	beq .b
	lda #1
.b:
	sta fxBusy
	lda #6                  ; the NES voices catch up (nesfx.asm)
	sta nfxRun
	rts

; the ADVANCED SOUND vibrato (keeps X)
VibUser:
	ldy uVibDep
	lda uVibDepT,y
	sta vibDepth
	ldy uVibRate
	lda uVibRateLo,y
	sta vibRL
	lda uVibRateHi,y
	sta vibRH
	ldy uVibDel
	lda uVibDelT,y
	sta vibDel
	lda #0
	sta vibSpr
	rts

WOB_DEPTH   equ 110             ; TAPE WOBBLE: about 0.45 semitone
WOB_RATE    equ 183             ;  at 0.7 Hz

; ADVANCED SOUND values (the menu's choices index these). SID vibrato depth
; x 1/4096 of the frequency (61 = 1/4 semitone), rate x 1/262 Hz, delay in
; 4 ms; glide 1/2^k of the way per 4 ms; tremolo depth of 15, rate x 1/655
; Hz; SID detune (8 = FAT's, about 7 cents); Game Boy warble.
uVibDepT:   .byte 30, 61, 91, 122
uVibRateLo: .byte <524, <786, <1048, <1310, <1572, <1834, <2096
uVibRateHi: .byte >524, >786, >1048, >1310, >1572, >1834, >2096
uVibDelT:   .byte 0, 25, 63, 125, 250
uGlideT:    .byte 3, 4, 5, 6
uTremDepT:  .byte 4, 7, 10, 15
uTremRL:    .byte <1311, <2621, <3932, <5243, <6554
uTremRH:    .byte >1311, >2621, >3932, >5243, >6554
uDetT:      .byte 4, 8, 12, 16
uWarbT:     .byte 24, 56, 100
; ... and the Game Boy's CCs for them (LFO depth CC 1, rate CC 76, delay
; CC 79, glide CC 5, detune +- from 64 on CC 94)
gbVibDepT:  .byte 16, 24, 28, 32
gbVibRateT: .byte 72, 80, 84, 88, 92, 96, 100
gbVibDelT:  .byte 0, 8, 16, 32, 64
gbGlideT:   .byte 16, 32, 48, 64
gbDetT:     .byte 3, 6, 10, 16

; Vibrato, glide or detune changed (a keytar button, SPACE, the menu): the
; SID's (FxVars; held notes retuned if the detune moved) and the Game Boy's
; glide and LFO CCs
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
	lda detNow
	cmp detSent
	beq .d
	sta detSent
	jsr SidRetune
.d:
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
	ldy t3
	jsr GbGlideVal
	tay
	lda #5
	jsr SoundGbPut
	ldy t3
	cpy #2
	beq .next               ; (the wave channel has no LFO here)
	jsr SoundGbLfo
.next:
	inc t3
	lda t3
	cmp #3
	bne .ch
	rts

; Held SID notes play again at the new detune (no new attack)
SidRetune:
	subroutine
	ldx #6
.v:
	stx t0
	lda vNote,x
	cmp #NO_NOTE
	beq .n
	sta vWant,x
	lda #0
	sta t3
	jsr VoiceSet
.n:
	lda t0
	sec
	sbc #3
	tax
	bpl .v
	rts

; A sound switch or an ADVANCED SOUND value changed (menu)
SoundLocks:
	jsr FxButtons
	jsr RepeatFromSound
	lda devOn+DEV_GB
	beq .x
	jsr GbDetAll
	jmp WarbleSend
.x:
	rts

; WIDE / TAPE WOBBLE held or let go
ActWide:
ActWobble:
	jsr FxButtons
WideWobble:
	subroutine
	lda devOn+DEV_GB
	beq .x
	lda actCnt+A_WIDE
	beq .w
	lda #1
.w:
	cmp wideWas
	beq .o
	sta wideWas
	jsr GbDetAll
.o:
	lda actCnt+A_WOBBLE
	beq .b
	lda #1
.b:
	cmp wobWas
	beq .x
	sta wobWas
	jmp WarbleSend
.x:
	rts

; FILTER SWEEP held / let go (SidFx does it)
ActSweep:
	jmp FxVars

; Game Boy glide (CC 5) for channel Y (0-2), X = soundMode -> A (keeps X)
GbGlideVal:
	subroutine
	lda glideLock
	beq .s
	cmp #1
	beq .u
	lda #0
	beq .b
.s:
	lda gbGl1
	cpy #0
	beq .b
	lda gbGl2
	cpy #1
	beq .b
	lda gbGlW
	jmp .b
.u:
	ldy uGlide
	lda gbGlideT,y
.b:
	ldy glideBtn
	beq .x
	cmp #0
	bne .x
	ldy uGlide
	lda gbGlideT,y
.x:
	rts

; Game Boy detune (CC 94) for pulse Y (0-1), X = soundMode -> A (keeps X).
; WIDE: about twice as far from the centre (64), and the pulses panned
; apart (GbDetAll)
GbDetVal:
	subroutine
	sty fxT0
	lda detLock
	beq .s
	cmp #1
	beq .u
	lda #0
	beq .off
.s:
	lda gbDetA
	cpy #0
	beq .abs
	lda gbDetB
.abs:
	sec                     ; distance from 64
	sbc #64
	bcs .off
	eor #$FF
	adc #1
	jmp .off
.u:
	ldy uDet
	lda gbDetT,y
.off:
	ldy actCnt+A_WIDE
	beq .sg
	asl
	adc #4
	cmp #41
	bcc .sg
	lda #40
.sg:
	ldy fxT0                ; pulse 1 flat, pulse 2 sharp
	bne .up
	eor #$FF
	sec
	adc #64                 ; 64 - off
	rts
.up:
	clc
	adc #64
	rts

; Game Boy pulses: detune (CC 94) and pan (CC 10: apart while WIDE is held)
GbDetAll:
	subroutine
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
	ldy t3
	jsr GbDetVal
	tay
	lda #94
	jsr SoundGbPut
	ldy #64
	lda actCnt+A_WIDE
	beq .p
	ldy #0
	lda t3
	beq .p
	ldy #127
.p:
	lda #10
	jsr SoundGbPut
	inc t3
	lda t3
	cmp #2
	bne .ch
	rts

; Game Boy warble (global): the sound's, the menu's WARBLE (ON: the ADVANCED
; SOUND amount; OFF: none); TAPE WOBBLE held: deep and slow
WarbleSend:
	subroutine
	ldx soundMode
	lda gbWarb
	ldy warbLock
	beq .w
	lda #0
	cpy #2
	beq .w
	ldy uWarb
	lda uWarbT,y
.w:
	ldy brWarb              ; DH-100: the warble follows the breath
	beq .w1
	tay
	bne .bw
	lda uWarbT+1
.bw:
	jsr BreathScale
.w1:
	ldy actCnt+A_WOBBLE
	beq .p
	lda #110
.p:
	tax
	lda #GCC_WARBLE
	jsr GbGlobal
	ldx soundMode
	lda gbWSpd
	ldy actCnt+A_WOBBLE
	beq .s
	lda #16
.s:
	tax
	lda #GCC_WSPEED
	jmp GbGlobal

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
	lda sndAD
	sta SID+5,y
	lda sndSR
	sta SID+6,y
	lda sndWave
	sta t0
	lda sndPwLo
	sta SID+2,y
	lda sndPwVoice
	beq .pw0
	ldx t1                  ; (RAW) each SID voice its own width
	lda rawPwHi,x
	bne .pw
.pw0:
	lda sndPwHi
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
	lda sndCut
	beq .noFilt
	sta SID+$16
	lda sndRes            ; resonance, voices 1-3 through the filter
	sta SID+$17
	lda #$10                ; low-pass
	sta sidFilt
	bne .vol
.noFilt:
	lda #0
	sta SID+$17
	sta sidFilt
	sta sweepOn             ; (FILTER SWEEP switches it on again if held)
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
	ldy gbAtk
	jsr .put
	lda #75
	ldy gbDec
	jsr .put
	lda #72
	ldy gbRel
	jsr .put
	ldy t3                  ; glide per channel
	jsr GbGlideVal
	tay
	lda #5
	jsr .put
	ldy t3                  ; level: pulses / wave
	lda gbLvl
	cpy #2
	bne .lv
	lda gbLvlW
.lv:
	tay
	lda #7
	jsr .put
	ldy #127                ; bend range 24 semitones (Fat Chip 64 scales its bends)
	lda #85
	jsr .put
	ldy t3
	cpy #2
	beq .wave
	; ---- pulses: duty, detune, LFO
	lda gbDuty1
	cpy #0
	beq .d
	lda gbDuty2
.d:
	tay
	lda #70
	jsr .put
	ldy t3
	jsr GbDetVal
	tay
	lda #94
	jsr .put
	jsr SoundGbLfo
	inc t3
	jmp .ch
.wave:
	lda #71
	ldy gbWMode
	jsr .put
	lda #70
	ldy gbWShape
	jsr .put
	jsr GbLegato
	jmp WarbleSend
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

; The pulses' LFO on channel mS (X = soundMode; keeps X): the sound's, or
; vibrato on pitch with the ADVANCED SOUND values (VIBRATO held, or the
; menu's VIBRATO ON), none on pitch (VIBRATO OFF), or TAPE WOBBLE's
SoundGbLfo:
	subroutine
	lda actCnt+A_WOBBLE
	bne .wob
	lda vibBtn
	bne .user
	lda vibLock
	beq .snd
	cmp #1
	beq .user
	lda gbLDest           ; OFF: an LFO on pitch gets depth 0
	bne .snd
	lda #1
	ldy #0
	jmp SoundGbPut
.snd:
	lda #76
	ldy gbLRate
	jsr SoundGbPut
	lda #77
	ldy gbLShape
	jsr SoundGbPut
	lda #78
	ldy gbLDest
	jsr SoundGbPut
	lda #79
	ldy gbLDelay
	jsr SoundGbPut
	lda #1
	ldy gbLDepth
	jmp SoundGbPut
.user:
	jsr .pitch
	ldy uVibRate
	lda gbVibRateT,y
	tay
	lda #76
	jsr SoundGbPut
	ldy #0
	lda vibBtn
	bne .dl
	ldy uVibDel
	lda gbVibDelT,y
	tay
.dl:
	lda #79
	jsr SoundGbPut
	ldy uVibDep
	lda gbVibDepT,y
	tay
	lda #1
	jmp SoundGbPut
.wob:
	jsr .pitch
	lda #76
	ldy #52                 ; about 0.9 Hz
	jsr SoundGbPut
	lda #79
	ldy #0
	jsr SoundGbPut
	lda #1
	ldy #32
	jmp SoundGbPut
.pitch:
	lda #78                 ; to pitch, triangle
	ldy #0
	jsr SoundGbPut
	lda #77
	ldy #0
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
	lda nesDuty1
	sta mD2
	lda nesBase
	ora #$B0
	sta mS
	jsr NesPut
	ldx soundMode
	lda nesDuty2
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
	ldy vFat,x              ; (a bass voice playing Fat Bass)
	beq .gb
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
	adc gbOct
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
	jsr NesFxDue            ; a MidiNES effects step due (nesfx.asm)?
	beq .sid
	lda nfxTurn             ; both due: they take turns
	bne .nes
	lda ticks
	sec
	sbc fxLast
	cmp #FX_EVERY
	bcc .nes                ; (the SID's not due: the NES)
	lda #1
	sta nfxTurn
	bne .sid
.nes:
	lda #0
	sta nfxTurn
	jmp NesFxTick
.sid:
	lda ticks
	sec
	sbc fxLast
	cmp #FX_EVERY
	bcs .go
	rts
.go:
	cmp #FX_EVERY*8
	bcc .n
	lda ticks               ; far behind: count 8 steps, start again from now
	sta fxLast
	lda #8
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

; phase += rate x fxN
	mac ADVANCE             ; {1} phase lo, {2} rate lo, {3} rate hi
	ldy fxN
.adv{1}:
	lda {1}
	clc
	adc {2}
	sta {1}
	lda {1}+1
	adc {3}
	sta {1}+1
	dey
	bne .adv{1}
	endm

SidFx:
	subroutine
	jsr SweepStep
	; ---- filter: cutoff = base + LFO + envelope (+ FILTER SWEEP)
	lda sndCut
	bne .filt
	jmp .noF
.filt:
	sta t0
	lda sndFDep
	beq .fenv
	ADVANCE fPhL, sndFRateL, sndFRateH
	lda fPhH
	jsr Tri                 ; 0-127
	ldy sndFDep
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
	lda sweepLvl            ; FILTER SWEEP: opens up towards the top
	beq .wr0
	lda t0
	eor #$FF
	tay
	lda sweepLvl
	jsr Mul8
	lda mt16+1
	clc
	adc t0
	sta t0
.wr0:
	lda t0
	jsr BreathCut           ; (DH-100: the breath closes it down)
	sta SID+$16
	jmp .pwm
.noF:
	; ---- an unfiltered sound: FILTER SWEEP switches the low-pass on and
	; closes it down; let go, it opens again and switches off
	lda sweepLvl
	ora actCnt+A_SWEEP
	ora brFilt
	beq .swOff
	lda sweepOn
	bne .swOn
	lda #1
	sta sweepOn
	lda #$E7                ; resonance 14, voices 1-3
	sta SID+$17
	lda #$10
	sta sidFilt
	jsr SidVolume
.swOn:
	lda sweepLvl            ; cutoff 255 - 7/8 of the sweep
	lsr
	lsr
	lsr
	sta t1
	lda sweepLvl
	sec
	sbc t1
	eor #$FF
	jsr BreathCut
	sta SID+$16
	jmp .pwm
.swOff:
	lda sweepOn
	beq .pwm
	lda #0
	sta sweepOn
	sta SID+$17
	sta sidFilt
	jsr SidVolume
.pwm:
	; ---- width LFO: one voice per call (width = base + tri x depth / 8,
	; each voice its own phase)
	lda sndPwm
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
	ldy sndPwm
	jsr Mul8
	lsr mt16+1
	ror mt16
	lsr mt16+1
	ror mt16
	lsr mt16+1
	ror mt16                ; / 8
	ldy fxVoice
	ldx sidOfs,y
	lda mt16
	clc
	adc sndPwLo
	sta SID+2,x
	lda mt16+1
	adc sndPwHi
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

; FILTER SWEEP: sweepLvl up while held (about 1/3 s to the top), down when
; let go (1/4 s)
SweepStep:
	subroutine
	ldy fxN
	lda actCnt+A_SWEEP
	beq .down
.u:
	lda sweepLvl
	clc
	adc #3
	bcc .us
	lda #255
.us:
	sta sweepLvl
	dey
	bne .u
	rts
.down:
	lda sweepLvl
	beq .x
.d:
	lda sweepLvl
	sec
	sbc #4
	bcs .ds
	lda #0
.ds:
	sta sweepLvl
	dey
	bne .d
.x:
	rts

; SID voice envY: sidBase moves 1/2^k of the way to sidTgt, fxN times
GlideStep:
	subroutine
	lda glideK
	bne .on
	rts
.on:
	; d = (target - now) / 2^glideK, worked out once; then d per 4 ms step
	; (fxN of them), stopping at the target
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
	ldx glideK
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
	bne .go
	lda t2
	cmp #$FF                ; -1 also snaps (a shift never reaches 0 going down)
	beq .snap
.go:
	ldx fxN
.add:
	lda sidBaseLo,y
	clc
	adc t2
	sta sidBaseLo,y
	lda sidBaseHi,y
	adc t3
	sta sidBaseHi,y
	lda sidTgtLo,y          ; past the target (target - now has turned): there
	cmp sidBaseLo,y
	lda sidTgtHi,y
	sbc sidBaseHi,y
	eor t3
	bmi .snap
	dex
	bne .add
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
	lda sndSeq
	beq .no
	lda dutyMs
	clc
	adc fxN
	sta dutyMs
	cmp sndSeqMs
	bcc .no
	lda #0
	sta dutyMs
	ldy sndSeq
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
	lda sndSeqSid
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

; mt16 = A x Y (8 x 8). Keeps X. Unrolled (v0.20: about 40 cycles quicker,
; and the vibrato calls it several times a pass).
	mac MULSTEP
	lsr mulB
	bcc .n{1}
	clc
	adc mulB+1
.n{1}:
	ror
	ror mt16
	endm
Mul8:
	subroutine
	sta mulB
	sty mulB+1
	lda #0
	MULSTEP 1
	MULSTEP 2
	MULSTEP 3
	MULSTEP 4
	MULSTEP 5
	MULSTEP 6
	MULSTEP 7
	MULSTEP 8
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

; ------------------------------------------------------------ the dice
; (DiceRoll: patchedit.asm)

; C= + /: back to the patch before the last roll
DiceUndo:
	subroutine
	lda undoOk
	beq .x
	lda #0
	sta undoOk
	ldy #127
.c:
	lda diceUndo,y
	sta livePatch,y
	dey
	bpl .c
	jmp PatchApply
.x:
	rts

; the live patch changed (dice, undo, SysEx): heard at once
PatchApply:
	jsr SoundRelease
	jsr SoundVars
	jsr SoundApply
	jmp Dirty
