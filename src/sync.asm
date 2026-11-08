; Fat Chip 64 - device sync (v0.13): the keytar (Yamaha SHS-10) and Synthcart
;
; Menu, DEVICE SYNC (defaults first):
;   TEMPO FROM      KEYTAR / OWN / SYNTHCART
;                   KEYTAR: its MIDI clock (24 a beat, sent even while stopped)
;                   sets the tempo, averaged over beats (the clock jitters about
;                   4 ms). Without a clock for 300 ms, Fat Chip's own tempo
;                   (B taps) is back. SYNTHCART: taps and beat tempos snap to
;                   Synthcart's ten NTSC tempos (whole Atari frames a beat).
;   START/STOP      KEYTAR / OWN: its Start and Stop start / stop the beat demo
;                   (a start waits for the next beat clock: step 1 lands on it)
;   RHYTHM BUTTONS  PICK BEAT / IGNORE: its style (Program Change on channel 16)
;                   picks a beat demo (styleBeat)
;   DRUM NOTES      IGNORE / PLAY: its drum notes on the MidiNES (drums.asm)
;   VOICE BUTTONS   PICK SOUND / IGNORE: its voice (Program Change 0-24 on the
;                   key channel) picks a sound (voiceSound)
;   WHEEL           BEND / OFF: +-2 semitones on everything (bend.asm)
;   VIBRATO / PORTAMENTO / SUSTAIN BUTTON  a task each (CC 1 / 65 / 64, 127
;                   held, 0 let go): VIBRATO, GLIDE, SUSTAIN, MUTE, BEND DOWN,
;                   OCTAVE UP, NEW CHORD, TAP TEMPO, BEAT ON/OFF, NEXT SOUND,
;                   NOTHING. The first six act while held, the rest on a press.
;
; The IRQ (RxByte) counts clocks itself and stamps every 24th (clkAt*, to the
; 1/4 ms); a Start makes the next clock a beat.

TEMPO_KEYTAR equ 0
TEMPO_OWN    equ 1
TEMPO_SC     equ 2
CLK_ALIVE    equ 300            ; ms: no clock for this long = not following

T_VIBRATO   equ 0
T_GLIDE     equ 1
T_SUSTAIN   equ 2
T_MUTE      equ 3
T_BEND      equ 4
T_OCTUP     equ 5
T_NEWCHORD  equ 6
T_TAP       equ 7
T_BEAT      equ 8
T_SOUND     equ 9
T_NOTHING   equ 10
NUM_TASKS   equ 11

; ------------------------------------------------------------ clock
; Main loop, every pass
ClockTick:
	subroutine
	lda clkCount            ; any clock lately?
	cmp clkCountSeen
	beq .alive
	sta clkCountSeen
	jsr GetTicks
	lda nowL
	sta clkSeenL
	lda nowH
	sta clkSeenH
	jmp .beatq
.alive:
	lda clkHave             ; none for a while: start measuring afresh
	beq .beatq
	jsr GetTicks
	lda nowL
	sec
	sbc clkSeenL
	tax
	lda nowH
	sbc clkSeenH
	bne .lost
	cpx #<CLK_ALIVE
	bcc .beatq
.lost:
	lda #0
	sta clkHave
.beatq:
	lda clkBeat
	cmp clkBeatSeen
	bne .beat
	rts
.beat:
	sta clkBeatSeen
	; this beat clock's time in 1/4 ms (16 bits)
	sei
	lda clkAtL
	sta t0
	lda clkAtH
	sta t1
	lda clkAtS
	sta t2
	cli
	lda t0
	sta beatClkL            ; (ms, for the beat demo)
	lda t1
	sta beatClkH
	lda #1
	sta beatClkNew
	lda clkBeatSeen
	sta beatClkNum
	asl t0
	rol t1
	asl t0
	rol t1
	lda #3
	sec
	sbc t2
	and #3
	ora t0
	sta t0                  ; t1:t0 = ticks x 4 + quarters
	; the period since the last beat clock (none yet: this one is the start)
	lda t0
	sec
	sbc clkLastQL
	sta t2
	lda t1
	sbc clkLastQH
	sta t3
	lda t0
	sta clkLastQL
	lda t1
	sta clkLastQH
	lda clkSkip             ; (a Start moved the beat: no period this time)
	bne .start
	lda clkHave
	bne .have
.start:
	lda #0
	sta clkSkip
	lda clkHave
	bne .st2
	lda #1
	sta clkHave
.st2:
	rts
.have:
	; 250 ms .. 2 s (1000 .. 8000 quarters), else start the average again
	lda t3
	cmp #>1000
	bcc .bad0
	bne .hi
	lda t2
	cmp #<1000
	bcc .bad0
.hi:
	lda t3
	cmp #>8000
	bcc .ok
	beq .ok
.bad0:
	jmp .bad
.ok:
	; period in 1/16 ms
	asl t2
	rol t3
	asl t2
	rol t3
	lda clkHave
	cmp #2
	beq .avg
	lda t2
	sta clk16L
	lda t3
	sta clk16H
	lda #2
	sta clkHave
	jmp .use
.avg:
	; clk16 += (period - clk16) / 4; off by more than a quarter (the tempo
	; jumped): the new period at once
	lda clk16H              ; bT1:bT0 = clk16 / 4
	lsr
	sta bT1
	lda clk16L
	ror
	sta bT0
	lsr bT1
	ror bT0
	lda t2
	sec
	sbc clk16L
	sta exS
	lda t3
	sbc clk16H
	sta exK                 ; exK:exS = period - clk16
	bcs .pos
	lda exS                 ; |diff|
	eor #$FF
	clc
	adc #1
	sta bT2
	lda exK
	eor #$FF
	adc #0
	jmp .cmp
.pos:
	lda exS
	sta bT2
	lda exK
.cmp:
	cmp bT1                 ; |diff| > clk16 / 4 ?
	bcc .small
	bne .jump
	lda bT2
	cmp bT0
	bcc .small
.jump:
	lda t2
	sta clk16L
	lda t3
	sta clk16H
	jmp .use
.small:
	lda exS
	sta t2
	lda exK
	sta t3
	cmp #$80
	ror t3
	ror t2
	lda t3
	cmp #$80
	ror t3
	ror t2
	lda clk16L
	clc
	adc t2
	sta clk16L
	lda clk16H
	adc t3
	sta clk16H
.use:
	jsr FollowActive
	beq .x
	lda clk16L
	ldx clk16H
	jmp SetBeat16
.bad:
	lda #1                  ; (this clock is the new start)
	sta clkHave
.x:
	rts

; A = 1 (Z clear) when the keytar's clock sets the tempo right now
FollowActive:
	subroutine
	lda syncTempo
	cmp #TEMPO_KEYTAR
	bne .no
	lda clkHave
	cmp #2
	bne .no
	jsr GetTicks
	lda nowL
	sec
	sbc clkSeenL
	tax
	lda nowH
	sbc clkSeenH
	bne .no
	cpx #<CLK_ALIVE
	bcs .no                 ; (CLK_ALIVE < 256)
	lda #1
	rts
.no:
	lda #0
	rts

; ------------------------------------------------------------ tempo
; A / X = beat length in 1/16 ms (lo / hi): tempo, Game Boy tempo, arp speeds
SetBeat16:
	subroutine
	sta beat16L
	stx beat16H
	; beatMs = (beat16 + 8) / 16
	clc
	adc #8
	sta t0
	txa
	adc #0
	sta t1
	ldx #4
.d:
	lsr t1
	ror t0
	dex
	bne .d
	lda t0
	sta beatMs
	lda t1
	sta beatMs+1
	lda bpm
	pha
	jsr TempoFromBeat
	pla
	cmp bpm
	beq .same
	jsr SendTempo
	lda #1
	sta screenDirty
.same:
	jmp StepCalc

; beatMs was just set (tap tempo, a beat demo): beat16 from it, or snapped
; to Synthcart. Returns with the tempo applied.
TempoChosen:
	subroutine
	lda syncTempo
	cmp #TEMPO_SC
	beq .sc
	lda beatMs
	sta t0
	lda beatMs+1
	ldx #4
.m:
	asl t0
	rol
	dex
	bne .m
	tax
	lda t0
	jmp SetBeat16
.sc:
	; the nearest of Synthcart's ten (compare beatMs x 16 with each)
	lda beatMs
	sta t0
	lda beatMs+1
	sta t1
	ldx #4
.m2:
	asl t0
	rol t1
	dex
	bne .m2
	lda #$FF
	sta t3                  ; best |difference| so far (exS:t3)
	sta exS
	ldy #0
	sty exK                 ; its index
.f:
	lda t0
	sec
	sbc scBeatL,y
	sta t2
	lda t1
	sbc scBeatH,y
	sta exI
	bcs .pos
	lda t2                  ; negative: negate
	eor #$FF
	clc
	adc #1
	sta t2
	lda exI
	eor #$FF
	adc #0
	sta exI
.pos:
	lda exI
	cmp exS
	bcc .better
	bne .nb
	lda t2
	cmp t3
	bcs .nb
.better:
	lda exI
	sta exS
	lda t2
	sta t3
	sty exK
.nb:
	iny
	cpy #10
	bne .f
	ldy exK
	lda scBeatL,y
	ldx scBeatH,y
	jmp SetBeat16

; Synthcart (NTSC): a beat is N Atari frames, N = 16, 20 .. 52; in 1/16 of a
; Fat Chip tick (1024 C64 cycles): N x 17067.43 x 16 / 1024
scBeatL:    .byte <4267,<5334,<6400,<7467,<8534,<9600,<10667,<11734,<12801,<13867
scBeatH:    .byte >4267,>5334,>6400,>7467,>8534,>9600,>10667,>11734,>12801,>13867

; ------------------------------------------------------------ keytar messages
; Start / Stop (realtime, from MidiInService)
KeytarStart:
	subroutine
	lda #1                  ; the beat clock moves: skip one tempo measurement
	sta clkSkip
	lda syncStart
	bne .x
	jsr BeatBegin
	jsr FollowActive
	beq .x
	lda #1                  ; following: step 1 waits for the first beat clock
	sta beatWait            ;  after the Start (the IRQ noted which one)
	lda clkStartBeat
	clc
	adc #1
	sta beatWaitBeat
.x:
	rts

KeytarStop:
	subroutine
	lda syncStart
	bne .x
	lda beatRun
	beq .x
	lda #0
	sta beatRun
	jsr NoiseOff
	jmp Dirty
.x:
	rts

; Program Change rxD1 on channel 16: a rhythm style
KeytarStyle:
	subroutine
	lda syncRhythm
	bne .x
	ldx rxD1
	cpx #25
	bcs .x
	lda styleBeat,x
	jmp BeatChoose
.x:
	rts

; Program Change rxD1 on a key channel: a voice button
KeytarVoice:
	subroutine
	lda syncVoice
	bne .x
	ldx rxD1
	cpx #25
	bcs .x
	lda voiceSound,x
	cmp soundMode
	beq .x
	tax
	jmp SoundSet
.x:
	rts

; the keytar's 25 rhythm styles -> beat demos (0 ELECTRO, 1 JUNGLE, 2 DNB,
; 3 BOOMBAP, 4 ROCK, 5 6/8), by feel, until there are 20 beats
;   R&B 1/2, Fusion 1/2, Slow Rock, Swing, Big Band, Dixie, Boogie Woogie,
;   Jazz Waltz, R'n'R 1/2, Rock-a-Ballad, Hard Rock, Reggae, Bossa Nova,
;   Samba, Tango, Country, Bluegrass, March 1/2, Lullaby, Baroque, Fanfare
styleBeat:  .byte 3,3,0,2,5,3,1,4,4,5,4,4,5,4,3,0,1,0,4,2,4,4,5,0,4
; the keytar's 25 voices -> sounds (17 so far; the last eight repeat some)
voiceSound: .byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16, 3,6,7,10,12,13,15,16

; Control change rxD1 = rxD2 on a key channel: the three buttons
KeytarCC:
	subroutine
	ldx #2
.f:
	lda btnCC,x
	cmp rxD1
	beq .b
	dex
	bpl .f
	rts
.b:
	lda rxD2
	cmp #64
	lda #0
	rol                     ; 1 = held
	cmp btnHeld,x
	beq .x                  ; no change
	sta btnHeld,x
	sta t3
	lda btnTask,x
	jmp DoTask
.x:
	rts

btnCC:      .byte 1, 65, 64     ; vibrato, portamento, sustain (the keytar's order)

; A = task, t3 = 1 pressed / 0 let go
DoTask:
	subroutine
	cmp #T_NOTHING
	bcs .x
	asl
	tax
	lda taskJump+1,x
	pha
	lda taskJump,x
	pha
	lda t3
	rts                     ; (jump: A = held)
.x:
	rts

taskJump:   .word TaskVib-1, TaskGlide-1, TaskSustain-1, TaskMute-1, TaskBend-1
	        .word TaskOctUp-1, TaskNewChord-1, TaskTap-1, TaskBeat-1, TaskSound-1

TaskVib:
	sta vibBtn
	jmp FxButtons

TaskGlide:
	sta glideBtn
	jmp FxButtons

TaskSustain:
	subroutine
	sta sustainOn
	bne .x
	lda latch               ; let go: keys not down any more stop (unless latched)
	bne .x
	jmp KeepPhysical
.x:
	rts

TaskMute:
	sta moment
	jmp MuteChanged

TaskBend:
	sta bendBtn
	rts

TaskOctUp:
	subroutine
	cmp #0
	beq .dn
	jmp MidiOctUp
.dn:
	jmp MidiOctDown

TaskNewChord:
	subroutine
	beq .x
	jmp NewChordKey
.x:
	rts

TaskTap:
	subroutine
	beq .x
	jmp TapTempo
.x:
	rts

TaskBeat:
	subroutine
	beq .x
	jmp BeatRunKey
.x:
	rts

TaskSound:
	subroutine
	beq .x
	lda #0
	sta shiftDown
	jmp SoundKey
.x:
	rts

; Pitch Bend rxD1 / rxD2 on a key channel: the wheel
KeytarWheel:
	subroutine
	lda syncWheel
	bne .x
	lda rxD2
	sec
	sbc #64
	bcs .up
	eor #$FF                ; down: (64 - msb) x 4, to 255
	adc #1
	asl
	asl
	bcc .d
	lda #255
.d:
	sta wheelMag
	lda #0
	sta wheelUp
	rts
.up:
	asl
	asl
	sta t0
	lda rxD1                ; + the top 2 bits of the LSB (63, 127 -> 255)
	lsr
	lsr
	lsr
	lsr
	lsr
	ora t0
	sta wheelMag
	lda #1
	sta wheelUp
.x:
	rts
