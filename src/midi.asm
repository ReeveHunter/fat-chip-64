; Fat Chip 64 - MIDI out
;
; Each device has its own queue of 3-byte messages. Every 1 ms the IRQ moves
; at most one message per device onto the wire buffer, no sooner than that
; device's gap (GB_GAP / NES_GAP) after its previous one. The Game Boy link
; drops messages when MIDI arrives at full speed (measured on Reeve's
; Teensyboy Pro: 1 per 2 ms is clean, 1 per 1 ms loses), so its queue is
; paced; the MidiNES only gets the wire's own limit for now.
; The wire uses running status. The main loop and the IRQ both feed the ACIA.

MidiInit:
	subroutine
	lda #ACIA_RESET
	sta ACIA_CTRL
	lda #ACIA_MODE
	sta ACIA_CTRL
	rts

; IRQ: send one wire byte if the ACIA is ready.
TxByte:
	subroutine
	ldx wireTail
	cpx wireHead
	beq .done
	lda ACIA_STAT
	and #ACIA_TDRE
	beq .done
	lda wireBuf,x
	sta ACIA_TX
	inc wireTail
.done:
	rts

; Main loop: same, with interrupts off around it.
TxService:
	subroutine
	php
	sei
	jsr TxByte
	plp
	rts

; IRQ: pace device queues onto the wire.
Schedule:
	subroutine
	; ---- Game Boy
	lda gbqTail
	cmp gbqHead
	beq .nes
	lda ticks               ; due? (ticks - gbNext) >= 0
	sec
	sbc gbNext
	lda ticks+1
	sbc gbNext+1
	bmi .nes
	; only onto an empty wire, so the gap holds on the cable itself (NES
	; bytes already waiting would otherwise delay this one and squeeze it
	; against the next)
	lda wireHead
	cmp wireTail
	bne .nes
	ldx gbqTail
	lda gbqS,x
	ldy gbqD2,x
	sty irqT
	ldy gbqD1,x
	jsr WireMsg
	lda gbqTail
	clc
	adc #1
	and #63
	sta gbqTail
	lda ticks
	clc
	adc #GB_GAP
	sta gbNext
	lda ticks+1
	adc #0
	sta gbNext+1
.nes:
	lda nesqTail
	cmp nesqHead
	beq .done
	lda ticks
	sec
	sbc nesNext
	lda ticks+1
	sbc nesNext+1
	bmi .done
	jsr WireFree
	cmp #3
	bcc .done
	ldx nesqTail
	lda nesqS,x
	ldy nesqD2,x
	sty irqT
	ldy nesqD1,x
	jsr WireMsg
	lda nesqTail
	clc
	adc #1
	and #63
	sta nesqTail
	lda ticks
	clc
	adc #NES_GAP
	sta nesNext
	lda ticks+1
	adc #0
	sta nesNext+1
.done:
	rts

; A = free bytes in the wire ring
WireFree:
	subroutine
	lda wireTail
	sec
	sbc wireHead
	sec
	sbc #1
	rts

; Put a message on the wire (IRQ only): A = status, Y = data 1, irqT = data 2.
; Program change / channel pressure have one data byte.
WireMsg:
	subroutine
	cmp lastStatus
	beq .rs
	sta lastStatus
	jsr WirePut
.rs:
	tya
	jsr WirePut
	lda lastStatus
	and #$E0
	cmp #$C0                ; $Cx and $Dx: one data byte
	beq .done
	lda irqT
	jsr WirePut
.done:
	inc statSent
	bne .x
	inc statSent+1
.x:
	rts

WirePut:
	subroutine
	ldx wireHead
	sta wireBuf,x
	inc wireHead
	rts

; ------------------------------------------------------------ queueing (main loop)
; Message in mS / mD1 / mD2. Dropped if the queue is full (63 messages).
GbPut:
	subroutine
	; write the slot at head first (always free: one slot stays empty),
	; then publish head unless the queue is full. Uses only A and X.
	ldx gbqHead
	lda mS
	sta gbqS,x
	lda mD1
	sta gbqD1,x
	lda mD2
	sta gbqD2,x
	txa
	clc
	adc #1
	and #63
	cmp gbqTail
	beq .full
	sta gbqHead
.full:
	rts

NesPut:
	subroutine
	; write the slot at head first (always free: one slot stays empty),
	; then publish head unless the queue is full. Uses only A and X.
	ldx nesqHead
	lda mS
	sta nesqS,x
	lda mD1
	sta nesqD1,x
	lda mD2
	sta nesqD2,x
	txa
	clc
	adc #1
	and #63
	cmp nesqTail
	beq .full
	sta nesqHead
.full:
	rts

; Game Boy global CC: A = CC number, X = value (sent on the pulse 1 channel)
GbGlobal:
	subroutine
	sta mD1
	stx mD2
	lda gbBase
	ora #$B0
	sta mS
	jmp GbPut

; ------------------------------------------------------------ device setup
; Fat Chip GB startup / resync (protocol section 2)
GbStartup:
	subroutine
	lda devOn+DEV_GB
	beq .done
	lda #GCC_PROFILE
	ldx #PROFILE_F
	jsr GbGlobal
	lda #GCC_PANIC
	ldx #0
	jsr GbGlobal
	lda #GCC_TUNE
	ldx #64
	jsr GbGlobal
	lda #GCC_WARBLE         ; a little drift so stacked voices breathe
	ldx #24
	jsr GbGlobal
	lda #GCC_WSPEED
	ldx #40
	jsr GbGlobal
	; detune the two pulses apart: CC 94 is scaled 0-127 (64 = centre,
	; +-50 cents), so 58 / 70 = about -5 / +5 cents
	lda gbBase
	ora #$B0
	sta mS
	lda #94
	sta mD1
	lda #58
	sta mD2
	jsr GbPut
	inc mS
	lda #70
	sta mD2
	jsr GbPut
	lda #GCC_DISPLAY
	ldx videoMode
	jsr GbGlobal
.done:
	rts

; MidiNES startup: CC7 = 127 on every voice (levels 0-7 are silent and CC7
; scales velocity), sweep shift CC16 = 127 on the pulses (lowest octave).
NesStartup:
	subroutine
	lda devOn+DEV_NES
	beq .done
	lda #7
	sta mD1
	lda #127
	sta mD2
	ldy #0
.cc7:
	tya
	clc
	adc nesBase
	and #15
	ora #$B0
	sta mS
	sty t1
	jsr NesPut
	ldy t1
	iny
	cpy #5
	bne .cc7
	lda #16
	sta mD1
	ldy #0
.cc16:
	tya
	clc
	adc nesBase
	and #15
	ora #$B0
	sta mS
	sty t1
	jsr NesPut
	ldy t1
	iny
	cpy #2
	bne .cc16
.done:
	rts
