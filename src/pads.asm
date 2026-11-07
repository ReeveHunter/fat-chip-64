; Fat Chip 64 - small helpers left from v0.11's pads.asm (the sounds are in sounds.asm)

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
