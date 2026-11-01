; Fat Chip 64 - sound: FAT (default) or PADS (V)
;
; PADS, per the brief's ambient pads: some voices swell and glide into each
; chord, others keep sharp defined attacks.
;   SID       slow attack (500 ms), long release (2.4 s), pulse wave with its
;             width wobbling (each voice its own phase), through a low-pass
;             filter that sweeps slowly (about 8 s up and down)
;   Game Boy  slow attack and release on pulses + wave, pulse 2 glides
;             into each new note, deeper warble
;   MidiNES   pulses swell and fade (CC7 envelope, see nesenv.asm); the
;             triangle (bass) just stops on release
;
; RAW, the classic raw chip sound: FAT's stacking, everything square and
; instant: SID pulse (50 / 25 / 12.5% per voice), attack 0, sustain full,
; release 0, no filter; Game Boy instant attack and release, no warble,
; pulses 50% / 25%, wave channel as a third pulse; MidiNES full volume,
; pulse 2 at 25%. The small detunes between doubled voices stay.

SoundApply:
	subroutine
	jsr NesSoundApply       ; leaving PADS: NES envelopes end, full volume
	jsr NesDuty
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
	cpx #SND_RAW
	bne .pw50
	ldx t1                  ; RAW: each SID voice its own width
	lda rawPwHi,x
	bne .pw
.pw50:
	lda #$08                ; 50% (PADS then wobbles it)
.pw:
	sta SID+3,y
	lda #0
	sta SID+2,y
	ldx t1
	lda sidGate,x
	and #1
	ora t0
	sta sidGate,x
	sta SID+4,y
	dex
	bpl .v
	lda padSound
	beq .noFilt
	lda #$77                ; resonance 7, filter voices 1-3
	sta SID+$17
	lda #$10                ; low-pass
	sta sidFilt
	lda #$30
	sta SID+$16
	bne .vol
.noFilt:
	lda #0
	sta SID+$17
	sta sidFilt
.vol:
	jsr SidVolume
	; fall through: the Game Boy's share

; Game Boy part of the sound (also sent again by GbStartup)
SoundGb:
	subroutine
	lda devOn+DEV_GB
	bne .on
	rts
.on:
	ldx soundMode
	lda sndGbAtk,x
	sta t2
	lda sndGbRel,x
	sta t3
	lda gbBase
	ora #$B0
	sta mS
	ldx #3                  ; pulse 1, pulse 2, wave: attack, release
.ch:
	lda #73
	sta mD1
	lda t2
	sta mD2
	stx t1
	jsr GbPut
	lda #72
	sta mD1
	lda t3
	sta mD2
	jsr GbPut
	ldx t1
	jsr .nextCh
	dex
	bne .ch
	; duty (CC 70) on the pulses
	lda gbBase
	ora #$B0
	sta mS
	lda #70
	sta mD1
	ldx soundMode
	lda sndGbDuty1,x
	sta mD2
	jsr GbPut
	jsr .nextCh
	ldx soundMode
	lda sndGbDuty2,x
	sta mD2
	jsr GbPut
	; pulse 2 glides in PADS
	lda #5
	sta mD1
	ldx soundMode
	lda sndGbGlide,x
	sta mD2
	jsr GbPut
	; wave channel: triangle (its default), or a third pulse in RAW
	jsr .nextCh
	lda #71
	sta mD1
	ldx soundMode
	lda sndWaveMode,x
	sta mD2
	jsr GbPut
	lda #70
	sta mD1
	ldx soundMode
	lda sndWaveShape,x
	sta mD2
	jsr GbPut
	lda #GCC_WARBLE
	ldy soundMode
	ldx sndWarble,y
	jmp GbGlobal
.nextCh:
	lda mS
	clc
	adc #1
	and #$0F
	ora #$B0
	sta mS
	rts

; MidiNES duty (CC 1): 50% on both pulses; RAW: pulse 2 at 25%
NesDuty:
	subroutine
	lda devOn+DEV_NES
	beq .x
	lda #1
	sta mD1
	lda #64
	sta mD2
	lda nesBase
	ora #$B0
	sta mS
	jsr NesPut
	ldx soundMode
	lda sndNesDuty2,x
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

; per sound:          FAT  PADS RAW
sndAD:      .byte $19, $A0, $00   ; SID attack/decay
sndSR:      .byte $C9, $FB, $F0   ; SID sustain/release: RAW = full sustain, instant release
sndWave:    .byte $20, $40, $40   ; SID saw / pulse / pulse
rawPwHi:    .byte $08, $04, $02   ; RAW SID widths: 50%, 25%, 12.5%
sndGbAtk:   .byte 0, 88, 0        ; Game Boy CC 73 (attack 0 / 5 of 7)
sndGbRel:   .byte 40, 100, 0      ; CC 72 (release 2 / 6 / 0 of 7)
sndGbDuty1: .byte 64, 64, 64      ; CC 70 pulse 1: 50%
sndGbDuty2: .byte 64, 64, 32      ; CC 70 pulse 2: 50% / 25% in RAW
sndGbGlide: .byte 0, 64, 0        ; CC 5 pulse 2 glide
sndWaveMode: .byte 40, 40, 24     ; CC 71 wave mode: TRI (2) / PULSE (1)
sndWaveShape: .byte 0, 0, 64      ; CC 70 wave shape: (triangle) / pulse 50%
sndWarble:  .byte 24, 48, 0       ; CC 104 warble: none in RAW
sndNesDuty2: .byte 64, 64, 32     ; MidiNES pulse 2 duty: 25% in RAW
sndTxtLo:   .byte <txtFat, <txtPads, <txtRaw
sndTxtHi:   .byte >txtFat, >txtPads, >txtRaw

; Every keyboard scan (4 ms): filter sweep and pulse-width wobble.
PadTick:
	subroutine
	lda padSound
	bne .on
	rts
.on:
	inc padT
	bne .p
	inc padT+1
.p:
	; cutoff: triangle over padT / 8 (2048 scans, about 8 s)
	lda padT+1
	sta t0
	lda padT
	lsr t0
	ror
	lsr t0
	ror
	lsr t0
	ror                     ; A = phase 0-255
	jsr Tri                 ; 0-127
	lsr
	sta t0
	lsr
	clc
	adc t0                  ; x 3/4: 0-95
	adc #$10
	sta SID+$16
	; pulse widths: each voice its own phase, about 2 s around
	ldx #2
.v:
	lda padT+1
	lsr
	lda padT
	ror                     ; phase = padT / 2
	clc
	adc pwPhase,x
	jsr Tri                 ; 0-127
	sta t0
	ldy sidOfs,x
	asl
	asl
	asl                     ; low byte of t0 x 8
	sta SID+2,y
	lda t0
	lsr
	lsr
	lsr
	lsr
	lsr                     ; high bits of t0 x 8
	clc
	adc #3                  ; width $300-$6F8 (19-43%)
	sta SID+3,y
	dex
	bpl .v
	rts

; A = 0-255 phase -> 0-127 triangle
Tri:
	subroutine
	cmp #128
	bcc .x
	eor #$FF
.x:
	rts

pwPhase:    .byte 0,85,170

; F: SPARKLE arp octave 0 / +1 / +2
ArpOctKey:
	subroutine
	ldx arpOct
	inx
	cpx #3
	bcc .s
	ldx #0
.s:
	stx arpOct
	lda #1
	sta reallocFlag
	sta screenDirty
	rts
