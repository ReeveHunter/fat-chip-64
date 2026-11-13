; Fat Chip 64 - bends (SPACE / the keytar's buttons and wheel), v0.13
;
; What everything is bent by: m = 0-384 sixteenths of a semitone (two
; octaves at most), up or down: bendMag (0-192, the first octave) + bendHi
; (0-192, the second), bendUp. From three things added together:
;   the BEND DOWN / BEND UP actions (SPACE or a keytar button, held): bendLvl
;     0-255 ramps up over about 1 s while held, back over about 0.5 s; full =
;     the menu's BEND RANGE (1-24 semitones, default 2)
;   the keytar's wheel: wheelMag 0-255 up or down, full = BEND RANGE
;   VINYL STOP (held): vinylLvl 0-255 the same way, like a record stopping:
;     speed (256 - lvl) / 256, the pitch 12 log2(1 / speed) down (vinP: an
;     octave by lvl 128, two by 192); the SID fades out from lvl 192; the
;     beat and arp slow (up to 8x); at lvl 248 everything has stopped:
;     silent, no drums (vinylCut). Let go, it winds back up in 0.5 s.
; Then:
;   SID       its frequency x 2^(+-m/192), from tables (bendtab.asm): the
;             first octave, then the second the same way
;   Game Boy  bend range 24 (CC 85, sent with the sound), bend = 8192 +- m x 8192 / 384
;   MidiNES   p(n) x the table / 8192 for the triangle, twice for the pulses
;             (p = the MidiNES triangle bend scale, 1710 at MIDI 36)
; Going down, a Game Boy or NES note bends only as far as the bottom of
; that channel's range (lower would wrap round to a high note): it holds
; there. Game Boy pulses C2 (MIDI 36), wave C1; NES pulses A1, triangle A0.
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
	ora bendHi
	ora bendSidHi
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
	lda #0                  ; stopped?
	cpx #VINYL_CUT
	bcc .vk
	lda #1
.vk:
	cmp vinylCut
	beq .vf
	sta vinylCut
	cmp #0
	bne .vm
	lda nowL                ; turning again: the beat and arp go on from now
	sta beatAtL             ;  (not after the long step they had while stopped)
	sta arpNext
	lda nowH
	sta beatAtH
	sta arpNext+1
.vm:
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
	jsr BendKey
	cmp btIn+3
	beq .same
	bne .tot2
.tot:
	jsr BendKey
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
	lda bendMag             ; the SID: when anything in it moved
	cmp bendSidMag
	bne .sid
	lda bendUp
	cmp bendSidUp
	bne .sid
	lda bendHi
	cmp bendSidHi
	beq .mid2
.sid:
	lda bendMag
	sta bendSidMag
	lda bendUp
	sta bendSidUp
	lda bendHi
	sta bendSidHi
	jsr SidBendAll
.mid2:
	lda bendMag
	cmp bendSent
	bne .chg
	lda bendUp
	cmp bendSentUp
	bne .chg
	lda bendHi
	cmp bendSentHi
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
	lda bendHi
	sta bendSentHi
	jmp BendMidiAll
.x:
	rts

; A = what the total depends on besides the levels: the directions (bits 7,
; 6) and BEND RANGE (0-23)
BendKey:
	subroutine
	lda bendRange
	ldx bendDir
	beq .w
	ora #$80
.w:
	ldx wheelUp
	beq .x
	ora #$40
.x:
	rts

; bendMag + bendHi / bendUp = the actions' bend + the wheel - vinyl, in 1/16
; semitones (at most two octaves)
BendTotal:
	subroutine
	ldy bendRange
	iny                     ; 1-24 semitones
	lda bendLvl
	jsr .scale              ; mt16 = (lvl + 1) x range / 16: 0-384
	ldx bendDir
	jsr .addS
	ldy bendRange
	iny
	lda wheelMag
	jsr .scale
	ldx wheelUp
	jsr .add
	ldx vinylLvl            ; like a record: 0-384, always down
	lda vinPL,x
	sta mt16
	lda vinPH,x
	sta mt16+1
	ldx #0
	jsr .add
	; -> magnitude (at most 384) and direction
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
	stx bendUp
	lda btH                 ; at most 384 ($180)
	cmp #2
	bcs .cap
	cmp #1
	bne .lo
	lda btL
	cmp #$81
	bcs .cap
	adc #256-192            ; 256 + lo - 192: the second octave (carry clear)
	bne .hi
.lo:
	lda btL
	cmp #193
	bcc .one
	sbc #192
.hi:
	sta bendHi
	lda #192
	sta bendMag
	rts
.cap:
	lda #192
	sta bendHi
	sta bendMag
	rts
.one:
	sta bendMag
	lda #0
	sta bendHi
	rts
; A = level 0-255, Y = semitones: mt16 = 0 if 0, else (A + 1) x Y / 16
.scale:
	cmp #0
	bne .s1
	sta mt16
	sta mt16+1
	rts
.s1:
	sty t0
	jsr Mul8
	lda mt16
	clc
	adc t0
	sta mt16
	bcc .div16
	inc mt16+1
.div16:
	ldx #4
.d:
	lsr mt16+1
	ror mt16
	dex
	bne .d
	rts
; start the total: mt16 up (X = 1) or down
.addS:
	ldy #0
	sty btL
	sty btH
.add:
	cpx #0
	beq .sub
	lda btL
	clc
	adc mt16
	sta btL
	lda btH
	adc mt16+1
	sta btH
	rts
.sub:
	lda btL
	sec
	sbc mt16
	sta btL
	lda btH
	sbc mt16+1
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
	ldx bendHi              ; the second octave: the same again
	beq .w2
	lda bT2
	sta mulA
	lda bT3
	sta mulA+1
	lda bendUp
	bne .up2
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
	jmp .w2
.up2:
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
	bcc .u2
	lda #$FF
	sta bT2
.u2:
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

; Game Boy voice t0 (bend range 24): m x 8192 / 384; going
; down, no further than the bottom of the channel (pulses C2, wave C1)
GbBendVoice:
	subroutine
	ldx t0
	lda vIdx,x
	clc
	adc gbBase
	and #15
	ora #$E0
	sta mS
	jsr BendM               ; bmL / bmH = m (0-384)
	lda bendUp
	bne .go
	ldx t0
	lda vOut,x
	cmp #NO_NOTE
	beq .go
	lda vSent,x             ; (the note it sounds)
	ldx t0
	ldy #36                 ; pulses
	pha
	lda vIdx,x
	cmp #2
	pla
	bcc .fl
	ldy #24                 ; wave
.fl:
	jsr BendRoom
.go:
	lda #<1365              ; m x 8192 / 384 = m x 1365 / 64
	sta mulA
	lda #>1365
	sta mulA+1
	lda bmL
	sta mulB
	lda bmH
	sta mulB+1
	jsr Mul16
	ldx #6
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

; bmH:bmL = the whole bend, m = bendMag + bendHi (0-384)
BendM:
	lda bendMag
	clc
	adc bendHi
	sta bmL
	lda #0
	adc #0
	sta bmH
	rts

; Going down from note A, with the channel's bottom note Y: bm no more than
; (A - Y) x 16 (none if A is at the bottom already)
BendRoom:
	subroutine
	sty bT0
	sec
	sbc bT0
	bcs .r
	lda #0
.r:
	sta bT0                 ; semitones of room
	lda #0
	ldx #4
.s:
	asl bT0                 ; x 16 (16-bit: bT0 lo, A hi)
	rol
	dex
	bne .s
	cmp bmH
	bcc .cut
	bne .x
	ldy bT0                 ; (high bytes equal: A stays)
	cpy bmL
	bcs .x
.cut:
	sta bmH                 ; the room
	lda bT0
	sta bmL
.x:
	rts

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
	lda bendHi
	sta nbHi
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
	; -> magnitude (at most 384: bendMag + bendHi) and direction
	ldy #1
	lda nbH
	bpl .pos
	ldy #0
	lda #0
	sec
	sbc nbL
	sta nbL
	lda #0
	sbc nbH
	sta nbH
.pos:
	sty bendUp
	lda #0
	sta bendHi
	lda nbH
	cmp #2
	bcs .cap
	cmp #1
	beq .two
	lda nbL
	cmp #193
	bcc .set
	sbc #192
	sta bendHi
	lda #192
	bne .set
.two:
	lda nbL
	cmp #$81
	bcs .cap
	adc #256-192            ; (carry clear)
	sta bendHi
	lda #192
	bne .set
.cap:
	lda #192
	sta bendHi
.set:
	sta bendMag
	ora bendHi
	ora bendUp
	bne .s1
	ldy #0                  ; (nothing: centre)
	sty bendUp
.s1:
	ldx t0
	lda bendMag
	sta nesBent,x
	lda nbNote
	jsr NesBendRaw
.back:
	lda nbMag
	sta bendMag
	lda nbUp
	sta bendUp
	lda nbHi
	sta bendHi
	rts

; nbH:nbL = NES voice X's whole bend, signed 1/16 semitones: the bend (up +,
; down -) + its own effects (nfxH:nfxL, NesFxVal). Keeps X.
NesTotal:
	subroutine
	jsr NesFxVal
	stx nfxX
	jsr BendM
	ldx nfxX
	lda bendUp
	bne .p
	lda #0                  ; down: negative
	sec
	sbc bmL
	sta bmL
	lda #0
	sbc bmH
	sta bmH
.p:
	lda bmL
	clc
	adc nfxL
	sta nbL
	lda bmH
	adc nfxH
	sta nbH
	rts

; ... the bend for bendMag + bendHi / bendUp. Going down, no further than
; the bottom of the channel (pulses A1, triangle A0): it holds there.
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
	jsr BendM
	lda bmL
	ora bmH
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
	ldx t0
	ldy #TRI_FLOOR+12       ; pulses: the lowest note is an octave up
	lda vIdx,x
	cmp #2
	bne .fl
	ldy #TRI_FLOOR
.fl:
	lda bT1
	jsr BendRoom
	lda bmL
	ora bmH
	beq .send0              ; at the bottom: no bend down
.calc:
	ldx bT1
	lda triPbLo,x
	sta mulA
	lda triPbHi,x
	sta mulA+1
	ldx bmL
	lda bendUp
	bne .u
	lda bmH
	bne .d2
	lda nesDnL,x
	sta mulB
	lda nesDnH,x
	sta mulB+1
	jmp .mul
.d2:
	lda nesDnL+256,x
	sta mulB
	lda nesDnH+256,x
	sta mulB+1
	jmp .mul
.u:
	lda bmH
	bne .u2
	lda nesUpL,x
	sta mulB
	lda nesUpH,x
	sta mulB+1
	jmp .mul
.u2:
	lda nesUpL+256,x
	sta mulB
	lda nesUpH+256,x
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
	lda mulR+3              ; (more than 16 bits: the end of the range)
	beq .send
	lda #$FF
	sta bT2
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
