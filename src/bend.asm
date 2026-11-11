; Fat Chip 64 - bends (SPACE / the keytar's buttons and wheel), v0.13
;
; What everything is bent by: m = 0-192 sixteenths of a semitone (an octave
; at most), up or down (bendMag, bendUp), from three things added together:
;   the BEND DOWN / BEND UP actions (SPACE or a keytar button, held): bendLvl
;     0-255 ramps up over about 1 s while held, back over about 0.5 s; full =
;     the menu's BEND RANGE (1-12 semitones, default 2)
;   the keytar's wheel: wheelMag 0-255 up or down, full = BEND RANGE
;   VINYL STOP (held): vinylLvl 0-255 the same way, like a record stopping:
;     speed (256 - lvl) / 256, the pitch 12 log2(1 / speed) down (vinPitch:
;     an octave by lvl 128). The SID keeps on down a second octave (vinSid)
;     and fades out from lvl 192; the beat and arp slow (up to 8x); at lvl
;     248 everything has stopped: silent, no drums (vinylCut). Let go, it
;     winds back up in 0.5 s.
; Then:
;   SID       its frequency x 2^(+-m/192), from tables (bendtab.asm)
;   Game Boy  bend range 12 (CC 85, sent with the sound), bend = 8192 +- m x 8192 / 192
;   MidiNES   p(n) x the table / 8192 for the triangle, twice for the pulses
;             (p = the MidiNES triangle bend scale, 1710 at MIDI 36); notes
;             without room at the bottom of the NES range don't bend down.
; Bends go out every BEND_TICK ms at most, and before each new NES note.

; , : SPACE's action back
SpaceBack:
	subroutine
	ldx spaceAct
	bne .d
	ldx #NUM_ACTS
.d:
	dex
	jmp SpaceSet

; . : SPACE's action on
SpaceNext:
	subroutine
	ldx spaceAct
	inx
	cpx #NUM_ACTS
	bcc SpaceSet
	ldx #0
SpaceSet:
	stx spaceAct            ; (one held now ends with its own action: spaceHeld)
	jmp Dirty

; Main loop, every pass.
BendTick:
	subroutine
	; nothing bending, nothing to undo: just keep the clock (quick pass)
	lda bendLvl
	ora vinylLvl
	ora wheelMag
	ora bendMag
	ora bendSent
	ora bendSidMag
	ora vinylSid
	ora vinylCut
	ora actCnt+A_BENDDN
	ora actCnt+A_BENDUP
	ora actCnt+A_VINYL
	bne .work
	lda ticks
	sta bendLast
	rts
.work:
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
	; ---- BEND DOWN / BEND UP held: up to 255; let go: back twice as fast
	lda actCnt+A_BENDDN
	ora actCnt+A_BENDUP
	beq .bup
	ldx #0                  ; direction: up only when just BEND UP is held
	lda actCnt+A_BENDDN
	bne .dir
	inx
.dir:
	stx bendDir
	lda bendLvl
	clc
	adc bT0
	bcc .bs
	lda #255
	bne .bs
.bup:
	lda bendLvl
	sec
	sbc bT0
	bcc .bz
	sbc bT0
	bcs .bs
.bz:
	lda #0
.bs:
	sta bendLvl
	; ---- VINYL STOP the same way
	lda actCnt+A_VINYL
	beq .vup
	lda vinylLvl
	clc
	adc bT0
	bcc .vs
	lda #255
	bne .vs
.vup:
	lda vinylLvl
	sec
	sbc bT0
	bcc .vz
	sbc bT0
	bcs .vs
.vz:
	lda #0
.vs:
	sta vinylLvl
	tax
	lda vinSid,x            ; the SID's second octave down
	cmp vinylSid
	beq .vc
	sta vinylSid
	lda #1
	sta vinylSidNew
.vc:
	lda #0                  ; stopped?
	cpx #VINYL_CUT
	bcc .vk
	lda #1
.vk:
	cmp vinylCut
	beq .vf
	sta vinylCut
	jsr MuteChanged
.vf:
	cpx #192                ; the SID fades from 192
	bcc .midi
	jsr SidVolume
.midi:
	; the total only when something in it changed
	lda bendLvl
	cmp btIn
	bne .tot
	lda wheelMag
	cmp btIn+1
	bne .tot
	lda vinylLvl
	cmp btIn+2
	bne .tot
	lda bendDir             ; key: dir, wheel dir, range (0-11)
	asl
	ora wheelUp
	asl
	asl
	asl
	asl
	ora bendRange
	sta t0
	cmp btIn+3
	beq .same
	bne .tot2
.tot:
	lda bendDir             ; key: dir, wheel dir, range (0-11)
	asl
	ora wheelUp
	asl
	asl
	asl
	asl
	ora bendRange
	sta t0
.tot2:
	lda bendLvl
	sta btIn
	lda wheelMag
	sta btIn+1
	lda vinylLvl
	sta btIn+2
	lda t0
	sta btIn+3
	jsr BendTotal
.same:
	lda bendMag
	ldx bendUp
	ldy vinylSidNew
	bne .sid
	cmp bendSidMag
	bne .sid
	cpx bendSidUp
	beq .mid2
.sid:
	ldy #0
	sty vinylSidNew
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

; bendMag / bendUp = the actions' bend + the wheel - vinyl, in 1/16 semitones
BendTotal:
	subroutine
	ldy bendRange
	iny                     ; 1-12 semitones
	lda bendLvl
	jsr .scale              ; (lvl + 1) x range / 16: 0-192
	ldx bendDir
	jsr .addS
	ldy bendRange
	iny
	lda wheelMag
	jsr .scale
	ldx wheelUp
	jsr .add
	ldx vinylLvl            ; like a record: 0-192, always down
	lda vinPitch,x
	ldx #0
	jsr .add
	; -> magnitude (at most 192) and direction
	lda btH
	bmi .neg
	ldx #1
	ora btL
	bne .mag
	tax                     ; nothing: centre, "down"
	beq .mag
.neg:
	lda #0
	sec
	sbc btL
	sta btL
	lda #0
	sbc btH
	sta btH
	ldx #0
.mag:
	lda btH
	bne .cap
	lda btL
	cmp #193
	bcc .st
.cap:
	lda #192
.st:
	sta bendMag
	stx bendUp
	rts
; A = level 0-255, Y = semitones: 0 if 0, else (A + 1) x Y / 16
.scale:
	cmp #0
	beq .s0
	sty t0
	jsr Mul8
	lda mt16
	clc
	adc t0
	sta mt16
	bcc .div16
	inc mt16+1
.div16:
	lda mt16+1
	asl mt16
	rol
	asl mt16
	rol
	asl mt16
	rol
	asl mt16
	rol                     ; (mt16 >> 4, fits a byte)
.s0:
	rts
; start the total: A up (X = 1) or down
.addS:
	ldy #0
	sty btL
	sty btH
.add:
	cpx #0
	beq .sub
	clc
	adc btL
	sta btL
	lda btH
	adc #0
	sta btH
	rts
.sub:
	sta t0
	lda btL
	sec
	sbc t0
	sta btL
	lda btH
	sbc #0
	sta btH
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
	lda sidBaseLo,y
	sta bT2
	sta mulA
	lda sidBaseHi,y
	sta bT3
	sta mulA+1
	ldx bendMag
	beq .w
	lda bendUp
	bne .up
	lda sidDnL,x
	sta mulB
	lda sidDnH,x
	sta mulB+1
	jsr Mul16               ; f x k / 65536 = bytes 2-3
	lda bT2
	sec
	sbc mulR+2
	sta bT2
	lda bT3
	sbc mulR+3
	sta bT3
	jmp .w
.up:
	lda sidUpL,x
	sta mulB
	lda sidUpH,x
	sta mulB+1
	jsr Mul16
	lda bT2
	clc
	adc mulR+2
	sta bT2
	lda bT3
	adc mulR+3
	bcc .u
	lda #$FF                ; (the top of the SID's range)
	sta bT2
.u:
	sta bT3
.w:
	lda vinylSid            ; VINYL STOP's second octave (SID only)
	beq .w2
	lda bT2
	sta mulA
	lda bT3
	sta mulA+1
	ldx vinylSid
	lda sidDnL,x
	sta mulB
	lda sidDnH,x
	sta mulB+1
	jsr Mul16
	lda bT2
	sec
	sbc mulR+2
	sta bT2
	lda bT3
	sbc mulR+3
	sta bT3
.w2:
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

; Game Boy voice t0 (bend range 12)
GbBendVoice:
	subroutine
	ldx t0
	lda vIdx,x
	clc
	adc gbBase
	and #15
	ora #$E0
	sta mS
	lda #<683               ; m x 8192 / 192 = m x 683 / 16
	sta mulA
	lda #>683
	sta mulA+1
	lda bendMag
	sta mulB
	lda #0
	sta mulB+1
	jsr Mul16
	ldx #4
.d:
	lsr mulR+2
	ror mulR+1
	ror mulR
	dex
	bne .d
	lda mulR+1
	sta bT2
	lda mulR
	sta bT3
	jsr BendFromAmt
	jmp GbPut

; MidiNES voice t0, sounding note A (vOut style, NO_NOTE = centre): the bend
; (SPACE, wheel, VINYL STOP) plus the voice's own effects (nesfx.asm:
; vibrato, glide, detune). (MidiTo also calls this before a new NES note.)
NesBendVoice:
	subroutine
	sta nbNote
	ldx t0
	jsr NesTotal
	ldx t0
	lda nfxL
	sta nesFxSL,x
	lda nfxH
	sta nesFxSH,x
	lda nbL
	sta nesTotL,x
	lda nbH
	sta nesTotH,x
	lda nbNote
	sta nesBNote,x
	lda bendMag
	sta nbMag
	lda bendUp
	sta nbUp
	; a pulse, no SPACE / wheel / VINYL bend, a small one: unit x m (quick)
	lda bendMag
	bne .full
	ldx t0
	lda nesUnL,x
	ora nesUnH,x
	beq .full
	ldy #1
	lda nbH
	beq .q
	cmp #$FF
	bne .full
	ldy #0
	lda nbL
	eor #$FF
	clc
	adc #1
	bmi .full
	bpl .qm
.q:
	lda nbL
	bmi .full
.qm:
	sty bendUp
	sta nbL                 ; m (0-127)
	lda vIdx,x
	clc
	adc nesBase
	and #15
	ora #$E0
	sta mS
	lda nesUnL,x
	sta mulA
	lda nesUnH,x
	sta mulA+1
	lda nbL
	sta nesBent,x
	jsr Mul16x8             ; / 16
	ldx #4
.d:
	lsr mulR+2
	ror mulR+1
	ror mulR
	dex
	bne .d
	lda mulR+1
	sta bT2
	lda mulR
	and #$FC                ; (MidiNES bends move in steps of 4)
	sta bT3
	jsr BendFromAmt
	jsr NesPut
	jmp .back
.full:
	lda nbH
	; -> magnitude (at most 192) and direction
	bmi .neg
	ldy #1
	lda nbH
	bne .cap
	lda nbL
	beq .zero
	cmp #193
	bcc .set
	bcs .cap
.neg:
	ldy #0
	lda #0
	sec
	sbc nbL
	sta nbL
	lda #0
	sbc nbH
	bne .cap
	lda nbL
	cmp #193
	bcc .set
.cap:
	lda #192
	bne .set
.zero:
	ldy #0
.set:
	sta bendMag
	sty bendUp
	ldx t0
	sta nesBent,x
	lda nbNote
	jsr NesBendRaw
.back:
	lda nbMag
	sta bendMag
	lda nbUp
	sta bendUp
	rts

; nbH:nbL = NES voice X's whole bend, signed 1/16 semitones: the bend (up +,
; down -) + its own effects (nfxH:nfxL, NesFxVal). Keeps X.
NesTotal:
	subroutine
	jsr NesFxVal
	ldy #0
	lda bendMag
	beq .p
	ldy bendUp
	bne .p0
	eor #$FF
	clc
	adc #1
	ldy #$FF
	bne .p
.p0:
	ldy #0
.p:
	sty nbH
	clc
	adc nfxL
	sta nbL
	lda nbH
	adc nfxH
	sta nbH
	rts

; ... the bend for bendMag / bendUp
NesBendRaw:
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
	jsr MidiNoteValue       ; (Fat Bass, octaves)
	sta bT1
	lda bendUp
	bne .calc               ; (going up can't wrap at the bottom)
	lda bendMag             ; going down: room for ceil(m / 16) semitones
	clc
	adc #15
	lsr
	lsr
	lsr
	lsr
	sta bT0
	ldx t0
	lda vIdx,x
	cmp #2
	beq .tri
	lda #TRI_FLOOR+12       ; pulses: the lowest note is an octave up
	bne .fl
.tri:
	lda #TRI_FLOOR
.fl:
	clc
	adc bT0
	sta bT0
	lda bT1
	cmp bT0
	bcc .send               ; no room: no bend
.calc:
	ldx bT1
	lda triPbLo,x
	sta mulA
	lda triPbHi,x
	sta mulA+1
	ldx bendMag
	lda bendUp
	bne .u
	lda nesDnL,x
	sta mulB
	lda nesDnH,x
	sta mulB+1
	jmp .mul
.u:
	lda nesUpL,x
	sta mulB
	lda nesUpH,x
	sta mulB+1
.mul:
	jsr Mul16
	; triangle >> 13, pulses >> 12 (bytes 1-3 >> 5 or 4)
	ldx #4
	ldy t0
	lda vIdx,y
	cmp #2
	bne .sh
	inx
.sh:
	lsr mulR+3
	ror mulR+2
	ror mulR+1
	dex
	bne .sh
	lda mulR+2
	sta bT2
	lda mulR+1
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
