; Fat Chip 64 - sound: FAT (default) or PADS (V)
;
; PADS, per the brief's ambient pads: some voices swell and glide into each
; chord, others keep sharp defined attacks.
;   SID       slow attack (500 ms), long release (2.4 s), pulse wave with its
;             width wobbling (each voice its own phase), through a low-pass
;             filter that sweeps slowly (about 8 s up and down)
;   Game Boy  slow attack and release on pulses + wave, pulse 2 glides
;             into each new note, deeper warble
;   MidiNES   unchanged: the sharp attacks under the swell

SoundApply:
	subroutine
	ldx #2
.v:
	ldy sidOfs,x
	lda padSound
	beq .fat
	lda #$A0                ; attack 500 ms, decay -
	sta SID+5,y
	lda #$FB                ; sustain 15, release 2.4 s
	sta SID+6,y
	lda #$40                ; pulse
	bne .w
.fat:
	lda #$19
	sta SID+5,y
	lda #$C9
	sta SID+6,y
	lda #$08                ; pulse width back to 50%
	sta SID+3,y
	lda #0
	sta SID+2,y
	lda #$20                ; saw
.w:
	sta t0
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
	beq .x
	ldx #0                  ; FAT: Fat Chip GB's own defaults
	ldy #40                 ; release 2
	lda padSound
	beq .s
	ldx #88                 ; attack 5 of 7
	ldy #100                ; release 6 of 7
.s:
	stx t2
	sty t3
	lda gbBase
	ora #$B0
	sta mS
	ldx #3                  ; pulse 1, pulse 2, wave
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
	lda mS
	clc
	adc #1
	and #$0F
	ora #$B0
	sta mS
	dex
	bne .ch
	; pulse 2 glides in PADS
	lda gbBase
	clc
	adc #1
	and #$0F
	ora #$B0
	sta mS
	lda #5
	sta mD1
	lda #0
	ldx padSound
	beq .g
	lda #64                 ; glide 8 of 15
.g:
	sta mD2
	jsr GbPut
	lda #GCC_WARBLE
	ldx #24
	ldy padSound
	beq .wb
	ldx #48
.wb:
	jsr GbGlobal
.x:
	rts

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
