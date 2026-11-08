; Fat Chip 64 - SPACE modes and the SPACE bend (v0.10)
;
; , and . (the < > keys) pick what SPACE does:
;   MUTES  (default) held = the mute flips (the momentary mute / play key)
;   BENDS  held = everything bends down 2 semitones over about 1 s;
;          let go and it comes back up over about 0.5 s
;
; bendLvl 0-255 is the depth (255 = 2 semitones down).
;   SID       frequency x (1 - k / 256), k = lvl / 8 - lvl / 64 (max 28: 0.891,
;             2 semitones), every change (4 ms steps)
;   Game Boy  pitch bend on its three channels (Fat Chip GB bend range is
;             2 semitones): 8192 - lvl x 32, every BEND_TICK ms
;   MidiNES   its bend moves the timer, so the amount depends on the note:
;             p(n) x lvl / 1024 for the triangle, twice that for the pulses
;             (p = the MidiNES triangle bend scale, 1710 at MIDI 36; 2 semitones
;             is p x 0.245, this is p x 0.249). Sent every BEND_TICK ms, and
;             before each new NES note while bent. Notes too near the bottom
;             of the NES range (the timer would wrap) don't bend.

; , : SPACE mode back
SpaceBack:
	subroutine
	ldx spaceMode
	bne .d
	ldx #SPC_MODES
.d:
	dex
	jmp SpaceSet

; . : SPACE mode on
SpaceNext:
	subroutine
	ldx spaceMode
	inx
	cpx #SPC_MODES
	bcc SpaceSet
	ldx #0
SpaceSet:
	stx spaceMode
	lda #0
	sta moment              ; a mute held in the old mode ends
	jsr MuteChanged
	jmp Dirty

; Main loop, every pass.
BendTick:
	subroutine
	jsr GetTicks
	lda nowL
	sec
	sbc bendLast
	cmp #BEND_DOWN_MS
	bcs .step
	jmp .midi
.step:
	; n = elapsed / 4 steps; keep the remainder
	sta bT0
	and #3
	sta bT1
	lda nowL
	sec
	sbc bT1
	sta bendLast
	lda bT0
	lsr
	lsr
	sta bT0                 ; n
	lda bendBtn             ; the keytar's BEND DOWN button, held
	bne .down
	lda spaceDown
	beq .up
	lda spaceMode
	cmp #SPC_BEND
	bne .up
.down:
	; down: +n, to 255
	lda bendLvl
	cmp #255
	beq .midi
	clc
	adc bT0
	bcc .set
	lda #255
	bne .set
.up:
	lda bendLvl
	beq .midi
	sec
	sbc bT0
	bcc .zero
	sbc bT0                 ; up twice as fast
	bcs .set
.zero:
	lda #0
.set:
	sta bendLvl
.midi:
	; v0.13: the bend everything gets = the wheel (up or down) and the SPACE
	; bend (down) together: bendMag (0-255 = 2 semitones), bendUp
	lda wheelUp
	bne .wu
	lda wheelMag
	clc
	adc bendLvl
	bcc .wd
	lda #255
.wd:
	ldx #0
	beq .comb
.wu:
	lda wheelMag
	sec
	sbc bendLvl
	ldx #1
	bcs .comb
	eor #$FF                ; the SPACE bend is bigger: down
	adc #1
	ldx #0
.comb:
	sta bendMag
	stx bendUp
	cmp bendSidMag
	bne .sid
	cpx bendSidUp
	beq .mid2
.sid:
	sta bendSidMag
	stx bendSidUp
	jsr SidBendAll
.mid2:
	lda bendMag
	cmp bendSent
	bne .chg
	lda bendUp
	cmp bendSentUp
	beq .x
.chg:
	; not more often than BEND_TICK, unless it's the final centring
	lda bendMag
	beq .send
	lda nowL
	sec
	sbc bendSentAt
	cmp #BEND_TICK
	bcc .x
.send:
	; the device queues have to have room (or this waits for the next pass)
	lda devOn+DEV_GB
	beq .q2
	lda gbqHead
	sec
	sbc gbqTail
	and #63
	cmp #Q_BACKLOG
	bcs .x
.q2:
	lda devOn+DEV_NES
	beq .ok
	lda nesqHead
	sec
	sbc nesqTail
	and #63
	cmp #Q_BACKLOG
	bcs .x
.ok:
	lda nowL
	sta bendSentAt
	lda bendMag
	sta bendSent
	lda bendUp
	sta bendSentUp
	jmp BendMidiAll
.x:
	rts

; All three SID voices from their base frequency, bent by bendLvl.
SidBendAll:
	subroutine
	ldy #2
.v:
	jsr SidFreqOut
	dey
	bpl .v
	rts

; SID voice Y (0-2): sidBase bent by bendLvl -> the frequency registers.
; Keeps Y.
SidFreqOut:
	subroutine
	lda bendMag
	bne .bend
	lda sidBaseLo,y
	sta bT2
	lda sidBaseHi,y
	sta bT3
	jmp .w
.bend:
	lsr
	lsr
	lsr
	sta bT0                 ; lvl / 8
	ldx bendUp
	bne .upK                ; up: x (1 + lvl / 8 / 256), 2 semitones at 255
	lda bendMag
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr                     ; lvl / 64
	eor #$FF
	sec
	adc bT0                 ; k = lvl / 8 - lvl / 64
	sta mulB
	lda #0
	sta mulB+1
	lda sidBaseLo,y
	sta mulA
	sta bT2
	lda sidBaseHi,y
	sta mulA+1
	sta bT3
	jsr Mul16               ; base x k, (>> 8 = bytes 1-2)
	lda bT2
	sec
	sbc mulR+1
	sta bT2
	lda bT3
	sbc mulR+2
	sta bT3
	jmp .w
.upK:
	lda bT0
	sta mulB
	lda #0
	sta mulB+1
	lda sidBaseLo,y
	sta mulA
	sta bT2
	lda sidBaseHi,y
	sta mulA+1
	sta bT3
	jsr Mul16
	lda bT2
	clc
	adc mulR+1
	sta bT2
	lda bT3
	adc mulR+2
	sta bT3
.w:
	lda vibAmt,y            ; vibrato (sounds.asm)
	beq .out
	jsr SidVib
.out:
	ldx sidOfs,y
	lda bT2
	sta SID+0,x
	lda bT3
	sta SID+1,x
	rts

; Bend messages to every Game Boy and MidiNES voice.
BendMidiAll:
	subroutine
	ldx #0
.v:
	stx t0
	lda vDev,x
	beq .n                  ; SID
	cmp #DEV_GB
	bne .nes
	jsr GbBendVoice
	jmp .n
.nes:
	lda vOut,x
	jsr NesBendVoice
.n:
	ldx t0
	inx
	cpx #NUM_VOICES
	bne .v
	rts

; Game Boy voice t0: 8192 - lvl x 32
GbBendVoice:
	subroutine
	ldx t0
	lda vIdx,x
	clc
	adc gbBase
	and #15
	ora #$E0
	sta mS
	lda bendMag
	sta bT3
	lda #0
	sta bT2                 ; bT2:bT3 = lvl (hi:lo)
	ldx #5
.sh:
	asl bT3
	rol bT2
	dex
	bne .sh                 ; x 32
	jsr BendFromAmt
	jmp GbPut

; MidiNES voice t0, sounding note A (vOut style, NO_NOTE = centre): the bend
; for bendLvl. (MidiTo also calls this before a new NES note.)
NesBendVoice:
	subroutine
	ldx t0
	sta bT1
	lda vIdx,x
	clc
	adc nesBase
	and #15
	ora #$E0
	sta mS
	lda #0
	sta bT2
	sta bT3                 ; no drop
	lda bendMag
	beq .send0
	lda bT1
	cmp #NO_NOTE
	bne .note
.send0:
	jmp .send
.note:
	jsr MidiNoteValue       ; (bass voices an octave down)
	sta bT1
	ldx t0
	lda vIdx,x
	cmp #2
	beq .tri
	lda bendUp
	bne .calc               ; (going up can't wrap at the bottom)
	lda bT1
	cmp #TRI_FLOOR+14       ; pulse: lowest note an octave above the
	bcc .send               ;  triangle's, and 2 semitones of room
	bcs .calc
.tri:
	lda bendUp
	bne .calc
	lda bT1
	cmp #TRI_FLOOR+2
	bcc .send
.calc:
	ldx bT1
	lda triPbLo,x
	sta mulA
	lda triPbHi,x
	sta mulA+1
	lda bendMag
	ldx bendUp
	beq .m
	lsr                     ; up: 7/8 of it (the timer's maths isn't symmetric)
	lsr
	lsr
	eor #$FF
	sec
	adc bendMag
.m:
	sta mulB
	lda #0
	sta mulB+1
	jsr Mul16               ; p x lvl
	; triangle >> 10, pulse >> 9: bytes 1-2 shifted right 2 or 1
	lda mulR+2
	sta bT2
	lda mulR+1
	sta bT3
	ldx t0
	lda vIdx,x
	cmp #2
	bne .one
	lsr bT2
	ror bT3
.one:
	lsr bT2
	ror bT3
	lda bT3
	and #$FC                ; MidiNES bends move in steps of 4
	sta bT3
.send:
	jsr BendFromAmt
	jmp NesPut

; bT2:bT3 = amount (hi:lo): down (8192 - it) or up (8192 + it, at most 16383)
BendFromAmt:
	subroutine
	lda bendUp
	bne .up
	jmp BendFromDrop
.up:
	lda bT3
	clc
	adc #0
	sta bT3
	lda bT2
	adc #$20
	cmp #$40
	bcc .ok
	lda #$FF
	sta bT3
	lda #$3F
.ok:
	sta bT2
	jmp BendOut

; bT2:bT3 = drop (hi:lo) -> mD1 / mD2 = 8192 - drop as a 14-bit bend
; (bottom of the range if the drop is bigger than that)
BendFromDrop:
	subroutine
	lda #0
	sec
	sbc bT3
	sta bT3
	lda #$20
	sbc bT2
	bcs .ok
	lda #0
	sta bT3
.ok:
	sta bT2
BendOut:
	lda bT3
	and #$7F
	sta mD1
	lda bT3
	asl
	lda bT2
	rol
	sta mD2
	rts
