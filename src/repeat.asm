; Fat Chip 64 - REPEAT (v0.13): echoes of the notes you play
;
; Each key pressed (overlay or MIDI in) is played again REPEATS times, every
; REPEAT TIME, each one REPEAT LEVEL as loud as the one before (velocity:
; the Game Boy and MidiNES scale their level by it). The echoes play on one
; or two "echo voices" (Game Boy pulse 2 and NES pulse 2 first, then pulse
; 1s), taken out of the chord while REPEAT is on - unless the notes held need
; them (then held notes come first and the echoes wait). Each echo sounds for
; 3/4 of the time between echoes. The SID doesn't echo.
;
; REPEAT on / off: the sound's default, the menu's REPEAT (AS SOUND / ON /
; OFF; ON uses the ADVANCED SOUND values), or the REPEAT action held (SPACE
; or a keytar button).
; REPEAT TIME: 1/4, 1/8 dotted, 1/8, 1/8T, 1/16 of the tempo, or FREE
; 80-500 ms. REPEATS: 1-8. REPEAT LEVEL: FULL, 90, 80, 70, 60, 50 %.

RP_SLOTS    equ 16
RP_SYNCED   equ 5               ; REPEAT TIME 0-4 follow the tempo, 5- are ms

; REPEAT is on now?
RepeatActive:
	lda repeatOn
	ora actCnt+A_REPEAT
	rts

; Allocate, after SPARKLE took its pair: the echo voices (vSkip keeps them
; out of the chord, vEcho marks them)
RepeatSet:
	subroutine
	ldx #NUM_VOICES-1
	lda #0
.c:
	sta vEcho,x
	dex
	bpl .c
	jsr RepeatActive
	beq .x
	; enough voices for the notes and two echoes? (held notes first)
	lda #0
	sta t1
	ldx #NUM_VOICES-1
.n:
	jsr VoiceEnabled
	beq .nn
	inc t1
.nn:
	dex
	bpl .n
	lda allocCount
	clc
	adc #2
	cmp t1
	beq .ok
	bcs .x
.ok:
	lda #0
	sta t2                  ; echo voices taken
	ldy #0
.p:
	sty t3
	ldx rpCand,y
	jsr VoiceEnabled        ; (uses Y)
	ldy t3
	cmp #0
	beq .pn
	lda #1
	sta vSkip,x
	sta vEcho,x
	inc t2
	lda t2
	cmp #2
	beq .x
.pn:
	iny
	cpy #4
	bne .p
.x:
	rts

rpCand:     .byte 4, 5, 1, 2        ; GB pulse 2, NES pulse 2, GB pulse 1, NES pulse 1

; Allocate's end: the echo voices keep whatever echo they're playing
EchoKeep:
	subroutine
	ldx #NUM_VOICES-1
.e:
	lda vEcho,x
	beq .n
	lda vNote,x
	sta vWant,x
.n:
	dex
	bpl .e
	rts

; A key was pressed (NoteDown, X = note index): its echoes. Keeps X.
RepeatPress:
	subroutine
	stx rpKey
	jsr RepeatActive
	bne .go
	rts
.go:
	lda t0                  ; (NoteDown's temporaries stay as they were)
	pha
	lda t1
	pha
	lda t2
	pha
	lda t3
	pha
	jsr IdxNote
	sta t3                  ; the note
	jsr RepeatGap           ; t1:t0 = ms between echoes
	jsr GetTicks
	lda nowL
	sta t2                  ; (time of the next echo: lo in t2, hi in rpHi)
	lda nowH
	sta rpHi
	lda #VELOCITY
	sta rpVelNow
	lda #1
	sta rpK
.k:
	; next echo time
	lda t2
	clc
	adc t0
	sta t2
	lda rpHi
	adc t1
	sta rpHi
	; quieter: x REPEAT LEVEL
	ldy rpLevel
	lda rpRatio,y
	tay
	lda rpVelNow
	jsr Mul8
	lda mt16+1
	ldy rpLevel
	bne .q
	lda rpVelNow            ; FULL: the same
.q:
	cmp #8
	bcc .x                  ; too quiet to hear: stop here
	sta rpVelNow
	; a free slot
	ldy #RP_SLOTS-1
.f:
	lda rpOn,y
	beq .put
	dey
	bpl .f
	bmi .x                  ; all busy
.put:
	lda #1
	sta rpOn,y
	sta rpBusy
	lda t2
	sta rpAtL,y
	lda rpHi
	sta rpAtH,y
	lda t3
	sta rpNote,y
	lda rpVelNow
	sta rpVel,y
	lda rpK
	sta rpNum,y
	inc rpK
	lda rpK
	sec
	sbc #1
	cmp rpCount             ; (rpCount = REPEATS - 1)
	bcc .k
	beq .k
.x:
	pla
	sta t3
	pla
	sta t2
	pla
	sta t1
	pla
	sta t0
	ldx rpKey
	rts

rpRatio:    .byte 0, 230, 205, 179, 154, 128    ; FULL, 90 .. 50 % (x 256)

; t1:t0 = ms between echoes (REPEAT TIME)
RepeatGap:
	subroutine
	ldx rpTime
	cpx #RP_SYNCED
	bcs .free
	lda beatMs
	sta t0
	lda beatMs+1
	sta t1
	cpx #0
	beq .x                  ; 1/4
	cpx #1
	bne .e8
	; 1/8 dotted = 3/4 beat
	lsr t1
	ror t0
	lda t0
	sta bT0
	lda t1
	sta bT1
	lsr bT1
	ror bT0
	lda t0
	clc
	adc bT0
	sta t0
	lda t1
	adc bT1
	sta t1
	rts
.e8:
	cpx #2
	bne .t8
	lsr t1                  ; 1/8
	ror t0
	rts
.t8:
	cpx #3
	bne .s16
	lda t0                  ; 1/8T: / 3
	sta dvdL
	lda t1
	sta dvdH
	lda #3
	sta dvsL
	lda #0
	sta dvsH
	jsr Div16
	lda dvdL
	sta t0
	lda dvdH
	sta t1
	rts
.s16:
	lsr t1                  ; 1/16
	ror t0
	lsr t1
	ror t0
.x:
	rts
.free:
	lda rpFreeLo-RP_SYNCED,x
	sta t0
	lda rpFreeHi-RP_SYNCED,x
	sta t1
	rts

rpFreeLo:   .byte <80,<100,<125,<150,<200,<250,<300,<400,<500
rpFreeHi:   .byte >80,>100,>125,>150,>200,>250,>300,>400,>500

; Main loop, every pass: echoes due play, finished ones stop
RepeatTick:
	subroutine
	lda rpBusy
	bne .go
	rts
.go:
	lda #0
	sta rpBusy              ; (set again while anything is pending)
	jsr GetTicks
	; ---- echoes that are due
	ldy #RP_SLOTS-1
.s:
	lda rpOn,y
	beq .sn
	lda #1
	sta rpBusy
	lda nowL
	sec
	sbc rpAtL,y
	lda nowH
	sbc rpAtH,y
	bmi .sn
	lda #0
	sta rpOn,y
	sty rpY
	jsr EchoPlay
	ldy rpY
.sn:
	dey
	bpl .s
	; ---- echo notes whose time is up
	ldx #NUM_VOICES-1
.o:
	lda rpOffOn,x
	beq .on
	lda #1
	sta rpBusy
	lda nowL
	sec
	sbc rpOffL,x
	lda nowH
	sbc rpOffH,x
	bmi .on
	lda #0
	sta rpOffOn,x
	lda vEcho,x             ; (no longer an echo voice: the chord has it now)
	beq .on
	stx t0
	lda #NO_NOTE
	sta vNote,x
	jsr MidiTo
	ldx t0
.on:
	dex
	bpl .o
	rts

; slot rpY is due: play it on an echo voice (they take turns)
EchoPlay:
	subroutine
	; the voice: echo voices in turn (odd / even echoes)
	ldx #NUM_VOICES-1
	lda rpNum,y
	and #1
	sta t3                  ; which of the two
.f:
	lda vEcho,x
	beq .n
	lda t3
	beq .got
	dec t3
.n:
	dex
	bpl .f
	; only one echo voice: that one
	ldx #NUM_VOICES-1
.f1:
	lda vEcho,x
	bne .got
	dex
	bpl .f1
	rts                     ; none now (held notes need them all)
.got:
	stx t0
	stx rpVoiceX
	lda rpVel,y
	sta mtVel
	lda rpNote,y
	sta vNote,x
	jsr MidiTo
	lda #VELOCITY
	sta mtVel
	; it stops after 3/4 of the gap
	jsr RepeatGap
	lsr t1
	ror t0
	lda t0
	sta bT0
	lda t1
	sta bT1
	lsr bT1
	ror bT0
	lda t0
	clc
	adc bT0
	sta t0
	lda t1
	adc bT1
	sta t1
	ldx rpVoiceX
	lda nowL
	clc
	adc t0
	sta rpOffL,x
	lda nowH
	adc t1
	sta rpOffH,x
	lda #1
	sta rpOffOn,x
	sta rpBusy
	rts

; REPEAT turned on / off (sound, menu, action): echo voices again; pending
; echoes go
RepeatChanged:
	subroutine
	jsr RepeatActive
	bne .x
	ldy #RP_SLOTS-1
	lda #0
.c:
	sta rpOn,y
	dey
	bpl .c
.x:
	lda #1
	sta reallocFlag
	sta rpBusy
	rts

; REPEAT from the sound; the menu's REPEAT ON: the ADVANCED SOUND values
RepeatFromSound:
	subroutine
	ldx soundMode
	lda rpLock
	cmp #1
	beq .user
	lda sndRp,x             ; a sound without REPEAT: REPEAT held uses these too
	bne .snd
.user:
	lda uRpTime
	sta rpTime
	lda uRpCount
	sta rpCount
	lda uRpLevel
	sta rpLevel
	jmp RepeatLockSet
.snd:
	ldx soundMode
	lda sndRpTime,x
	sta rpTime
	lda sndRpCount,x
	sta rpCount
	lda sndRpLevel,x
	sta rpLevel
RepeatLockSet:
	ldx soundMode
	lda sndRp,x
	ldy rpLock
	beq .s
	lda #1
	cpy #1
	beq .s
	lda #0
.s:
	sta repeatOn
	jmp RepeatChanged
