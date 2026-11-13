; Fat Chip 64 - chord changes, DRONE and One Key Play (v0.27)
;
; CHORD CHANGE (PLAYING): how the voices move when the chord changes.
;   AS MODE  DRONE wanders, the other modes ATTACK
;   ATTACK   as always: the new notes start
;   GLIDE    every voice slides to its new note (a glide even if the patch
;            has none)
;   SPLIT    the SID and the bass voices glide, the Game Boy and NES pulses
;            start again
;   WANDER   each voice moves at its own moment within WANDER TIME, the bass
;            late; some glide, some start again (fade out, come back in)
; DRONE (C= + Z): the lowest key held is the root: open fifths up from it
;   (DRONE VOICING: FIFTHS, FIFTHS + 9TH, SUS4). A new key moves the drone.
; ONE KEY PLAY: the cursor keys step through a phrase (pentatonic pairs or
;   the chord's notes); alternate the two for fast runs. See OkpPress.

CHG_ATTACK  equ 1
CHG_GLIDE   equ 2
CHG_SPLIT   equ 3
CHG_WANDER  equ 4
CHG_K       equ 6               ; CHORD CHANGE's glide (as a patch's glideK)

; A = the chord change style now (keeps X, Y)
ChgEff:
	subroutine
	lda chgMode
	bne .x
	lda effMode
	cmp #MODE_DRONE
	bne .a
	lda #CHG_WANDER
	rts
.a:
	lda #CHG_ATTACK
.x:
	rts

; ApplyVoices, voice X changes note: how. A = 0 (Z): change it now (t3,
; legatoNow, vsGlide set); A = 1: not yet (WANDER). Keeps X.
ChgStyle:
	subroutine
	lda vNote,x
	cmp #NO_NOTE
	bne .snd
	lda vWant,x             ; from silence: at once (GLIDE, SPLIT: from the
	cmp #NO_NOTE            ;  voice's last note, like a portamento)
	beq .now0
	lda hardCut
	ora monoMode
	bne .now0
	jsr ChgEff
	cmp #CHG_GLIDE
	beq .gs
	cmp #CHG_SPLIT
	bne .now0
	lda vDev,x
	beq .gs
	lda vIdx,x
	cmp #2
	bne .now0
.gs:
	lda glideK
	sta vsGlide
.now0:
	lda #0
	rts
.snd:
	lda vWant,x
	cmp #NO_NOTE
	beq .now
	lda hardCut
	ora vArpHit,x           ; (the arp, MONO: their own way)
	ora monoMode
	bne .now
	lda okpHit              ; One Key Play's notes: at once, new attacks
	beq .s
	lda vWant,x
	cmp okpNotes
	beq .okp
	cmp okpNotes+1
	beq .okp
.s:
	jsr ChgEff
	cmp #CHG_ATTACK
	beq .now
	cmp #CHG_GLIDE
	beq .glide
	cmp #CHG_SPLIT
	bne .wander
	lda vDev,x              ; SPLIT: the SID and the bass glide
	beq .glide
	lda vIdx,x
	cmp #2
	beq .glide
	bne .attack
.wander:
	lda vWaitOn,x
	bne .waiting
	lda #1
	sta vWaitOn,x
	jsr WanderDelay
	clc
	adc unitNow
	sta vDue,x
	bne .wait               ; (always: a later pass)
.waiting:
	lda unitNow
	sec
	sbc vDue,x
	bmi .wait
	lda #0
	sta vWaitOn,x
	jsr IsBass              ; the bass glides; the others: either way
	beq .glide
	jsr Random
	cmp #64
	bcc .glide
.attack:
	lda #1
	sta t3
	lda #0
	sta vsGlide
	rts
.okp:
	lda #1
	sta t3
.now:
	lda #0
	rts
.glide:
	lda #0
	sta t3
	lda #1
	sta legatoNow
	lda glideK
	sta vsGlide
	lda #0
	rts
.wait:
	lda #1
	sta applyRetry          ; (ApplyVoices again on the next pass)
	rts

; Z set if voice X is a bass voice (Game Boy wave, NES triangle, Fat Bass)
IsBass:
	subroutine
	lda vFat,x
	bne .y
	lda vDev,x
	beq .n
	lda vIdx,x
	cmp #2
	rts
.y:
	lda #0
	rts
.n:
	lda #1
	rts

; A = a random wait within WANDER TIME, in 64 ms units (the bass: the later
; half). Keeps X.
WanderDelay:
	subroutine
	stx exI
	ldy wanderT
	lda wanderU,y
	sta exS
	jsr Random              ; 0-127
	tay
	lda exS
	jsr Mul8                ; units x r / 128
	asl mt16
	lda mt16+1
	rol
	sta exD
	ldx exI
	jsr IsBass
	bne .x
	lda exD                 ; the bass: (units + it) / 2
	clc
	adc exS
	ror
	sta exD
.x:
	lda exD
	ldx exI
	rts

; unitNow = the time in 64 ms units
UnitNow:
	jsr GetTicks
	lda nowH
	sta exS
	lda nowL
	asl
	rol exS
	asl
	rol exS
	lda exS
	sta unitNow
	rts

; ------------------------------------------------------------ DRONE
; (Expand, MODE_DRONE) the lowest note held -> open fifths up from it
DroneExpand:
	subroutine
	lda heldCount
	beq .x
	lda heldList            ; (ascending: the lowest)
	sta exR
	lda #0
	sta heldCount
	ldx droneVc
	ldy droneAt,x
.n:
	lda droneIvs,y
	bmi .x
	sty exK
	clc
	adc exR
	jsr InsertNote
	ldy exK
	iny
	bne .n
.x:
	rts

droneAt:    .byte 0,5,11
droneIvs:   .byte 0,7,12,19,$FF            ; FIFTHS
	.byte 0,7,12,14,19,$FF                 ; FIFTHS + 9TH
	.byte 0,5,7,12,17,$FF                  ; SUS4

; ------------------------------------------------------------ One Key Play
; CRSR DOWN or CRSR RIGHT (A = 1 / 2: which) pressed, ONE KEY PLAY on: the
; phrase's next step sounds. PENTATONIC PAIRS: two notes of the key's
; pentatonic scale, one apart (a third or a fourth), across the overlay's two
; octaves. CHORD NOTES: one note of the chord (the keys held or latched),
; over two octaves. EACH PRESS CUTS the last step or lets it RING ON (until
; the next). The notes sound while either key is down (latch: until the next
; press).
OkpPress:
	subroutine
	ora okpDown
	sta okpDown
	lda okpRing             ; RINGS ON: the last step stays
	beq .cut
	lda okpCount
	beq .cut
	lda okpNotes
	sta okpNotes+2
	lda okpNotes+1
	sta okpNotes+3
	lda #4
	bne .c
.cut:
	lda #2
.c:
	sta okpCount
	jsr OkpBuild
	lda okpLen
	bne .go
	lda #0                  ; (nothing to play)
	sta okpCount
	rts
.go:
	jsr OkpStep
	ldx okpPos
	lda okpList,x
	sta okpNotes
	lda #NO_NOTE
	ldy okpSrc
	bne .one
	lda okpList+2,x         ; pairs: two scale notes up
.one:
	sta okpNotes+1
	lda #1
	sta okpHit
	sta reallocFlag
	rts

; A = 1 / 2 (which cursor key) let go
OkpRelease:
	subroutine
	eor #$FF
	and okpDown
	sta okpDown
	bne .x
	lda latch
	bne .x
	sta okpCount            ; (0)
	lda #1
	sta reallocFlag
.x:
	rts

; okpList / okpLen = the phrase (ascending); okpLen = the steps
OkpBuild:
	subroutine
	lda #0
	sta okpLen
	lda okpSrc
	beq .pent
	lda okpChordN           ; (no chord: single notes of the pentatonic scale)
	beq .pent
	; CHORD NOTES: the chord, and again an octave up
	ldx #0
.c1:
	cpx okpChordN
	beq .c2
	lda okpChord,x
	sta okpList,x
	inx
	bne .c1
.c2:
	stx okpLen
	ldy #0
.c3:
	cpy okpChordN
	beq .cx
	lda okpChord,y
	clc
	adc #12
	sta okpList,x
	inx
	iny
	bne .c3
.cx:
	stx okpLen
	rts
.pent:
	jsr ScalePtr            ; minor-ish (a minor third in the scale): minor pentatonic
	ldx #0
	ldy #2
	lda (ptr),y
	cmp #3
	beq .min
	dey
	lda (ptr),y
	cmp #3
	bne .maj
.min:
	ldx #5
.maj:
	stx exK                 ; pentIvs offset
	; from the key's root at or below the overlay's lowest key, up two octaves
	lda octBase
	sec
	sbc effRoot
	clc
	adc #120
.m:
	cmp #12
	bcc .r
	sbc #12
	bcs .m
.r:
	sta exV                 ; octBase - root, mod 12
	lda octBase
	sec
	sbc exV
	sta exR                 ; the root below
	ldx #0                  ; list index
.oct:
	ldy exK
	lda #5
	sta exS
.iv:
	lda pentIvs,y
	clc
	adc exR
	cmp octBase
	bcc .skip
	sta exD
	lda octBase
	clc
	adc #24
	cmp exD
	bcc .done               ; (past the top)
	lda exD
	sta okpList,x
	inx
	cpx #16
	beq .done
.skip:
	iny
	dec exS
	bne .iv
	lda exR
	clc
	adc #12
	sta exR
	jmp .oct
.done:
	txa
	sec
	sbc #2                  ; pairs: the top two notes start none
	bcs .l
	lda #0
.l:
	sta okpLen
	rts

pentIvs:    .byte 0,2,4,7,9, 0,3,5,7,10

; okpPos -> the next step (MOTION, TURN, DIRECTION)
OkpStep:
	subroutine
	ldx okpTurn
	jsr Random
	cmp okpTurnP,x
	lda #0
	rol
	eor #1                  ; 1 = turn this step
	sta exS
	; the ends: forward runs to "end", the start is the other end
	lda #0
	sta exK                 ; end (DOWN: 0)
	ldx okpLen
	dex
	stx exD                 ; start (DOWN: the top)
	lda okpDir
	beq .d
	stx exK
	lda #0
	sta exD
.d:
	lda okpPos
	cmp okpLen
	bcc .in
	lda exD                 ; (new or the phrase shrank: from the start)
	sta okpPos
	lda #0
	sta okpGoing
	rts
.in:
	lda okpMotion
	beq .down
	cmp #1
	beq .mostly
	cmp #2
	beq .pong
	; RANDOM WALK: turn now and then; bounce at the ends
	lda exS
	beq .walk
	lda okpGoing
	eor #1
	sta okpGoing
.walk:
	jsr .move
	bcc .x
	lda okpGoing            ; (at an end: back the other way)
	eor #1
	sta okpGoing
	jmp .move
.pong:
	lda exS
	beq .p
	lda okpGoing
	eor #1
	sta okpGoing
.p:
	jsr .move
	bcc .x
	lda okpGoing
	eor #1
	sta okpGoing
	jmp .move
.mostly:
	lda exS                 ; a turn: one step back, then on as before
	beq .down
	lda #1
	sta okpGoing
	jsr .move
	lda #0
	sta okpGoing
	bcc .x
.down:
	lda exS                 ; DOWN: to the end, then from the start again; a
	bne .restart            ;  turn: from the start at once
	lda #0
	sta okpGoing
	jsr .move
	bcc .x
.restart:
	lda exD
	sta okpPos
.x:
	rts
; okpPos one step: forward (okpGoing 0) or back. Carry set: at that end,
; didn't move.
.move:
	lda okpGoing
	eor okpDir              ; 0: towards 0, 1: up
	bne .up
	lda okpPos
	beq .end
	dec okpPos
	clc
	rts
.up:
	ldx okpPos
	inx
	cpx okpLen
	bcs .end
	stx okpPos
	clc
	rts
.end:
	sec
	rts

okpTurnP:   .byte 0,12,26,46   ; TURN: chance in 128 (never, 9%, 20%, 36%)

; BuildHeld, after the chord is built: the chord kept for CHORD NOTES, then
; One Key Play's notes join (never expanded into chords)
OkpAdd:
	subroutine
	ldx heldCount
	stx okpChordN
.c:
	dex
	bmi .a
	lda heldList,x
	sta okpChord,x
	jmp .c
.a:
	ldx #0
.n:
	cpx okpCount
	beq .x
	lda okpNotes,x
	cmp #NO_NOTE
	beq .s
	stx exI
	jsr InsertNote
	ldx exI
.s:
	inx
	bne .n
.x:
	rts

; ONE KEY PLAY or its NOTES changed: from the start, nothing sounding
OkpHook:
	lda #$FF
	sta okpPos
	lda #0
	sta okpCount
	sta okpDown
	lda #1
	sta reallocFlag
	rts

; CHORD CHANGE changed: glide or not
SoundVarsHook:
	jmp FxVars
