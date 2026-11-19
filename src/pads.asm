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

; C= + F1 / F3: SPARKLE arp octave down / up (0 / +1 / +2)
ArpOctUp:
	subroutine
	ldx arpOct
	cpx #2
	bcs .x
	inx
	bne .s
ArpOctDown:
	ldx arpOct
	beq .x
	dex
.s:
	stx arpOct
	lda #FOCUS_ARP
	sta fxFocus
	lda #1
	sta reallocFlag
	sta screenDirty
	rts
.x:
	rts
