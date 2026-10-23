; Fat Chip 64 - tempo and arpeggiator
;
; Tempo: B taps it (average of the last four taps; a gap over 2 s starts
; again). Default 120 BPM. The Game Boy gets it as CC 107/108.
;
; Arp (A): OFF -> UNISON -> SPARKLE.
;   UNISON  every voice plays the arp note (a nine-voice stepped unison)
;   SPARKLE two voices arpeggiate over the held chord as a pad: the Game Boy
;           pulses (panned left / right, so the arp ping-pongs), or the NES
;           pulses if the Game Boy is off, or SID 1 and 2. Each arp note rings
;           until its voice's next turn.
; Pattern (S): UP, DOWN, UP-DOWN, RANDOM, AS PLAYED.
; Speed (D): 1/4, 1/8, 1/8T, 1/16, 1/32 of the tempo, or FREE (H slower,
;   J faster; either one also picks FREE).
;
; Steps are timed from the 1 ms ticks and checked on every main loop pass;
; arpNext advances by exactly one step each time, so the arp keeps tempo.

; nowL / nowH = ticks, read in one piece (the IRQ could otherwise bump it
; between the two bytes: $22FF read as $23FF)
GetTicks:
	subroutine
	php
	sei
	lda ticks
	sta nowL
	lda ticks+1
	sta nowH
	plp
	rts

; ------------------------------------------------------------ tempo
TapTempo:
	subroutine
	jsr GetTicks
	lda nowL
	sec
	sbc tapLast
	sta t0
	lda nowH
	sbc tapLast+1
	sta t1
	lda nowL
	sta tapLast
	lda nowH
	sta tapLast+1
	lda tapCount
	bne .had
	jmp .first
.had:
	; 240 ms (250 BPM) <= gap < 2000 ms (30 BPM)
	lda t1
	cmp #>2000
	bcc .lt2000
	bne .first2
	lda t0
	cmp #<2000
	bcs .first2
.lt2000:
	lda t1
	bne .ok
	lda t0
	cmp #240
	bcc .x                  ; too fast: a bounce, ignore
.ok:
	ldx tapPos
	lda t0
	sta tapRingLo,x
	lda t1
	sta tapRingHi,x
	inx
	txa
	and #3
	sta tapPos
	lda tapN
	cmp #4
	bcs .avg
	inc tapN
.avg:
	; sum the last tapN gaps
	lda #0
	sta dvdL
	sta dvdH
	ldx #3
.s:
	cpx tapN
	bcs .sn                 ; only slots 0..tapN-1 are filled
	lda dvdL
	clc
	adc tapRingLo,x
	sta dvdL
	lda dvdH
	adc tapRingHi,x
	sta dvdH
.sn:
	dex
	bpl .s
	lda tapN
	sta dvsL
	lda #0
	sta dvsH
	jsr Div16
	lda dvdL
	sta beatMs
	lda dvdH
	sta beatMs+1
	jsr TempoFromBeat
	jsr SendTempo
	jsr StepCalc
	lda #1
	sta screenDirty
.x:
	rts
.first2:
.first:
	lda #1
	sta tapCount
	lda #0
	sta tapN
	sta tapPos
	rts

; bpm = 60000 / beatMs (rounded)
TempoFromBeat:
	subroutine
	lda beatMs+1
	lsr
	sta t0
	lda beatMs
	ror
	clc
	adc #<60000
	sta dvdL
	lda t0
	adc #>60000
	sta dvdH
	lda beatMs
	sta dvsL
	lda beatMs+1
	sta dvsH
	jsr Div16
	lda dvdL
	sta bpm
	rts

; Game Boy tempo: BPM x 32 as 14 bits, CC 107 (MSB) then CC 108
SendTempo:
	subroutine
	lda devOn+DEV_GB
	beq .x
	lda bpm
	lsr
	lsr
	tax
	lda #GCC_TEMPO_MSB
	jsr GbGlobal
	lda bpm
	and #3
	asl
	asl
	asl
	asl
	asl
	tax
	lda #GCC_TEMPO_LSB
	jsr GbGlobal
.x:
	rts

; stepMs from the speed setting
StepCalc:
	subroutine
	ldx arpLen
	cpx #ARP_FREE
	bne .sync
	ldy freeIdx
	lda freeLo,y
	sta stepMs
	lda freeHi,y
	sta stepMs+1
	rts
.sync:
	lda beatMs
	sta dvdL
	lda beatMs+1
	sta dvdH
	lda lenDiv,x
	sta dvsL
	lda #0
	sta dvsH
	jsr Div16
	lda dvdH
	bne .ok
	lda dvdL
	cmp #MIN_STEP
	bcs .ok
	lda #MIN_STEP           ; too fast for the Game Boy link
	sta dvdL
.ok:
	lda dvdL
	sta stepMs
	lda dvdH
	sta stepMs+1
	rts

; dvd = dvd / dvs (16-bit), remainder in rem
Div16:
	subroutine
	lda #0
	sta remL
	sta remH
	ldx #16
.l:
	asl dvdL
	rol dvdH
	rol remL
	rol remH
	lda remL
	sec
	sbc dvsL
	tay
	lda remH
	sbc dvsH
	bcc .n
	sta remH
	sty remL
	inc dvdL
.n:
	dex
	bne .l
	rts

; ------------------------------------------------------------ arp keys
ArpModeKey:
	subroutine
	ldx arpMode
	inx
	cpx #3
	bcc .s
	ldx #0
.s:
	stx arpMode
	lda #0
	sta arpRunning          ; restart cleanly in the new mode
	jsr ArpPan
	lda #1
	sta reallocFlag
	sta screenDirty
	rts

ArpPatKey:
	subroutine
	ldx arpPat
	inx
	cpx #5
	bcc .s
	ldx #0
.s:
	stx arpPat
	lda #$FF
	sta arpIdx              ; next step starts the pattern
	lda #1
	sta screenDirty
	rts

ArpLenKey:
	subroutine
	ldx arpLen
	inx
	cpx #ARP_FREE+1
	bcc .s
	ldx #0
.s:
	stx arpLen
	jmp ArpRateChanged

; H: free rate slower
ArpSlower:
	subroutine
	lda arpLen
	cmp #ARP_FREE
	bne .free               ; first press just picks FREE
	ldx freeIdx
	cpx #FREE_STEPS-1
	bcs ArpRateChanged
	inc freeIdx
	jmp ArpRateChanged
.free:
	lda #ARP_FREE
	sta arpLen
	jmp ArpRateChanged

; J: free rate faster
ArpFaster:
	subroutine
	lda arpLen
	cmp #ARP_FREE
	bne .free
	lda freeIdx
	beq ArpRateChanged
	dec freeIdx
	jmp ArpRateChanged
.free:
	lda #ARP_FREE
	sta arpLen
ArpRateChanged:
	jsr StepCalc
	lda #1
	sta screenDirty
	rts

; Game Boy pulse pan: left / right while SPARKLE uses them, centre otherwise
ArpPan:
	subroutine
	lda devOn+DEV_GB
	beq .x
	lda #10
	sta mD1
	lda gbBase
	ora #$B0
	sta mS
	ldx #64
	ldy #64
	lda arpMode
	cmp #ARP_SPARKLE
	bne .p
	ldx #0
	ldy #127
.p:
	stx mD2
	jsr GbPut               ; (keeps Y)
	sty mD2
	lda mS
	clc
	adc #1
	and #$0F
	ora #$B0
	sta mS
	jmp GbPut
.x:
	rts

; ------------------------------------------------------------ the arp clock
; Every main loop pass. Steps when due; starts when notes appear.
ArpTick:
	subroutine
	lda arpMode
	bne .on
	sta arpRunning
	rts
.on:
	jsr GetTicks
	lda arpRunning
	beq .check
	lda reallocFlag         ; keys changed: let go of everything = stop, so
	beq .due                ; the next press starts the arp at once
	jsr BuildHeld
	lda heldCount
	beq .stop
.due:
	lda nowL                ; due? (now - arpNext) >= 0; arpNext is never
	sec                     ; more than one step ahead while running
	sbc arpNext
	lda nowH
	sbc arpNext+1
	bmi .x
	jsr BuildHeld
	lda heldCount
	beq .stop
	jsr ArpStep
	lda arpNext
	clc
	adc stepMs
	sta arpNext
	lda arpNext+1
	adc stepMs+1
	sta arpNext+1
	; fell behind (rate change, long redraw)? start the count from now
	lda nowL
	sec
	sbc arpNext
	lda nowH
	sbc arpNext+1
	bmi .x
	jmp .fromNow
.check:
	lda reallocFlag
	beq .x
	jsr BuildHeld
	lda heldCount
	beq .x
	; notes appeared: first step right away
	lda #1
	sta arpRunning
	lda #$FF
	sta arpIdx
	jsr ArpStep
.fromNow:
	lda nowL
	clc
	adc stepMs
	sta arpNext
	lda nowH
	adc stepMs+1
	sta arpNext+1
.x:
	rts
.stop:
	lda #0
	sta arpRunning
	rts

; Pick the next arp note. heldList / heldCount / playOrder are current.
ArpStep:
	subroutine
	jsr PlayPrune
	lda arpPat
	cmp #PAT_PLAYED
	bne .asc
	lda playCount
	jmp .n
.asc:
	lda heldCount
.n:
	sta t2                  ; notes in the source
	beq .x
	; a shrunk chord: keep the index in range
	lda arpIdx
	cmp #$FF
	beq .pat
	cmp t2
	bcc .pat
	ldx t2
	dex
	stx arpIdx
.pat:
	ldx arpPat
	lda patLo,x
	sta ptr
	lda patHi,x
	sta ptr+1
	jmp (ptr)
ArpDone:                        ; patterns come back here with arpIdx set
	lda arpPat
	cmp #PAT_PLAYED
	bne .fromHeld
	ldx arpIdx
	lda playOrder,x
	clc
	adc octBase
	jmp .set
.fromHeld:
	ldx arpIdx
	lda heldList,x
.set:
	sta arpNote
	inc arpStep
	lda #1
	sta arpHit
	sta reallocFlag
.x:
	rts

PatUp:                          ; (also AS PLAYED)
	subroutine
	lda arpIdx
	cmp #$FF
	beq .zero
	clc
	adc #1
	cmp t2
	bcc .s
.zero:
	lda #0
.s:
	sta arpIdx
	jmp ArpDone

PatDown:
	subroutine
	lda arpIdx
	cmp #$FF
	beq .top
	sec
	sbc #1
	bcs .s
.top:
	ldx t2
	dex
	txa
.s:
	sta arpIdx
	jmp ArpDone

PatUpDown:
	subroutine
	lda arpIdx
	cmp #$FF
	bne .go
	lda #1
	sta arpDir
	lda #0
	beq .s
.go:
	ldx t2
	cpx #1
	bne .more
	lda #0
	beq .s
.more:
	lda arpDir
	bmi .down
	inc arpIdx
	lda arpIdx
	ldx t2
	dex
	stx t3
	cmp t3
	bcc .s
	lda #$FF                ; reached the top: turn
	sta arpDir
	lda t3
	jmp .s
.down:
	dec arpIdx
	lda arpIdx
	beq .turnUp
	bpl .s
.turnUp:
	lda #1
	sta arpDir
	lda #0
.s:
	sta arpIdx
	jmp ArpDone

PatRandom:
	subroutine
	jsr Random
.mod:
	cmp t2
	bcc .m
	sbc t2
	jmp .mod
.m:
	ldx t2
	cpx #1
	beq .s
	cmp arpIdx              ; not the same note twice in a row
	bne .s
	clc
	adc #1
	cmp t2
	bcc .s
	lda #0
.s:
	sta arpIdx
	jmp ArpDone

; A = random 0-127 (8-bit Galois LFSR, stirred with the clock)
Random:
	subroutine
	lda rnd
	bne .g
	lda #$A5
.g:
	lsr
	bcc .n
	eor #$B8
.n:
	sta rnd
	eor ticks
	and #$7F
	rts

; ------------------------------------------------------------ as played
; Key index X was pressed: add it to playOrder (if new; drops the oldest
; when full). Keeps X.
PlayAdd:
	subroutine
	ldy playCount
.f:
	dey
	bmi .add
	txa
	cmp playOrder,y
	bne .f
	rts                     ; already there
.add:
	lda playCount
	cmp #8
	bcc .room
	ldy #0
.sh:
	lda playOrder+1,y
	sta playOrder,y
	iny
	cpy #7
	bne .sh
	dec playCount
.room:
	ldy playCount
	txa
	sta playOrder,y
	inc playCount
	rts

; Drop notes that stopped sounding from playOrder.
PlayPrune:
	subroutine
	ldx #0
	ldy #0
.l:
	cpx playCount
	beq .d
	lda playOrder,x
	sty t0
	tay
	lda noteHeld,y
	ldy t0
	cmp #0
	beq .skip
	lda playOrder,x
	sta playOrder,y
	iny
.skip:
	inx
	bne .l
.d:
	sty playCount
	rts
