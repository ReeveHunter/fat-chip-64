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
;   WHEEL           BEND / OFF: +-BEND RANGE on everything (bend.asm)
;   VIBRATO / PORTAMENTO / SUSTAIN BUTTON  an action each (CC 1 / 65 / 64,
;                   127 held, 0 let go), the same list as SPACE (actions below)
;
; The IRQ (RxByte) counts clocks itself and stamps every 24th (clkAt*, to the
; 1/4 ms); a Start makes the next clock a beat.

TEMPO_KEYTAR equ 0
TEMPO_OWN    equ 1
TEMPO_SC     equ 2
CLK_ALIVE    equ 300            ; ms: no clock for this long = not following



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
.meas:
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
	jsr TremSyncCalc        ; (TREMOLO SYNC follows)
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
	sty scIdx
	jmp ScBeat              ; (with TRIM: devices.asm)

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
	lda useShs
	beq .x
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
	lda useShs
	bne .shs
	lda useDh
	beq .x
	jmp DhTone              ; (the DH-100's tone buttons)
.shs:
	lda syncVoice
	bne .x
	ldx rxD1                ; voice n: bank n / 5, slot n mod 5
	cpx #25
	bcs .x
	lda bankSlot,x
	cmp #$FF
	beq .x                  ; (an empty slot)
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

; Control change rxD1 = rxD2 on a key channel: the three buttons
KeytarCC:
	subroutine
	lda rxD1
	cmp #65
	bne .shs
	lda useDh
	beq .shs
	lda rxD2                ; the DH-100's portamento button: its own task
	cmp #64
	lda #0
	rol
	cmp dhCC65
	beq .x
	sta dhCC65
	sta t3
	beq .dup
	lda dhPort
	sta dhAct
	jmp DoAction
.dup:
	lda dhAct
	jmp DoAction
.shs:
	lda useShs
	beq .x
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
	beq .up
	lda btnTask,x           ; pressed: its action now (let go: the same one)
	sta btnAct,x
	jmp DoAction
.up:
	lda btnAct,x
	jmp DoAction
.x:
	rts

btnCC:      .byte 1, 65, 64     ; vibrato, portamento, sustain (the keytar's order)

; ------------------------------------------------------------ actions
; What SPACE and the keytar's buttons do (menu: SPACE, ... BUTTON):
;   held     MUTE, BEND DOWN, BEND UP, VIBRATO, TREMOLO, ARP, STUTTER,
;            VINYL STOP, GLIDE, SUSTAIN, OCTAVE UP, REPEAT, FILTER SWEEP,
;            BEAT FILL, TAPE WOBBLE, WIDE
;   a press  TAP TEMPO, BEAT ON/OFF, NEXT SOUND; or NOTHING
; A held action can be held by several at once; it ends when the last lets go.
;
; A = action, t3 = 1 pressed / 0 let go
DoAction:
	subroutine
	cmp #A_HELD
	bcs .press
	tax
	lda t3
	beq .rel
	inc actCnt,x
	lda actCnt,x
	cmp #1
	bne .x
	beq .go
.rel:
	lda actCnt,x
	beq .x
	dec actCnt,x
	bne .x
.go:
	lda actCnt,x            ; (1 on, 0 off)
	beq .z
	lda #1
.z:
	sta t3
	txa
	asl
	tax
	lda heldJump+1,x
	pha
	lda heldJump,x
	pha
	lda t3
	rts                     ; (jump: A = on / off)
.press:
	cmp #A_NOTHING
	bcs .x
	ldx t3
	beq .x
	sec
	sbc #A_HELD
	asl
	tax
	lda pressJump+1,x
	pha
	lda pressJump,x
	pha
.x:
	rts

heldJump:   .word ActMute-1, ActNone-1, ActNone-1, ActVib-1, ActTrem-1, ActArp-1
	        .word ActStut-1, ActNone-1, ActGlide-1, ActSus-1, ActOctUp-1, ActRepeat-1
	        .word ActSweep-1, ActFill-1, ActWobble-1, ActWide-1
pressJump:  .word TapTempo-1, BeatRunKey-1, ActSound-1

; Panic: every held action ends
ActionsEnd:
	subroutine
	lda #0
	ldx #A_HELD-1
.c:
	sta actCnt,x
	dex
	bpl .c
	sta spaceDown
	sta btnHeld
	sta btnHeld+1
	sta btnHeld+2
	sta moment
	sta stutCut
	sta tremBtn
	sta vibBtn
	sta glideBtn
	sta sustainOn
	sta vinylLvl
	sta bendHi
	sta vinylCut
	sta bendLvl
	sta fillEnd
	lda fillSolo            ; a fill that started the beat: it stops
	beq .fs
	lda #0
	sta fillSolo
	sta beatRun
	jsr NoiseOff
.fs:
	jsr WideWobble          ; WIDE, TAPE WOBBLE: the Game Boy back
	lda arpTemp
	beq .a
	lda #0
	sta arpTemp
	sta arpMode
	jsr ArpModeApply
.a:
	ldy #RP_SLOTS-1         ; no echoes waiting
	lda #0
.r:
	sta rpOn,y
	dey
	bpl .r
	jsr RepeatChanged
	jsr FxButtons
	jmp MuteChanged

ActNone:                        ; (BEND DOWN / UP, VINYL STOP: BendTick reads actCnt)
	rts

ActMute:
	sta moment
	jmp MuteChanged

ActVib:
	sta vibBtn
	jmp FxButtons

ActGlide:
	sta glideBtn
	jmp FxButtons

ActRepeat:                      ; REPEAT held: echoes on (RepeatActive reads actCnt)
	jmp RepeatChanged

ActTrem:
	sta tremBtn             ; (TremTick does it)
	rts

ActSus:
	subroutine
	sta sustainOn
	bne .x
	lda latch               ; let go: keys not down any more stop (unless latched)
	bne .x
	jmp KeepPhysical
.x:
	rts

; OCTAVE UP held: everything you play an octave up (the overlay and MIDI
; in), held notes too
ActOctUp:
	subroutine
	cmp #0
	beq .s
	lda #12
.s:
	sta octUpAdd
	lda #1
	sta reallocFlag
	jmp Dirty

; ARP held: the arp on (in the last mode A chose), off again when let go
ActArp:
	subroutine
	cmp #0
	beq .off
	lda arpMode
	bne .x                  ; already on: leave it
	lda arpLast
	sta arpMode
	lda #1
	sta arpTemp
	jmp ArpModeApply
.off:
	lda arpTemp
	beq .x
	lda #0
	sta arpTemp
	sta arpMode
	jmp ArpModeApply
.x:
	rts

; STUTTER held: the notes keep sounding but cut out on some 16ths
ActStut:
	subroutine
	cmp #0
	beq .off
	jsr GetTicks
	lda nowL
	sta stutAtL
	lda nowH
	sta stutAtH
	lda #$FF
	sta stutStep
	lda beatRun             ; a beat playing: on its grid
	beq .x
	lda beatAtL
	sta stutAtL
	lda beatAtH
	sta stutAtH
	ldx beatStep
	dex
	stx stutStep
.x:
	rts
.off:
	lda stutCut
	beq .x
	lda #0
	sta stutCut
	jmp MuteChanged

ActSound:
	lda #0
	sta shiftDown
	jmp SoundKey

; Main loop: STUTTER's 16ths. The first 16th of each beat always sounds; on
; the others a sounding chord cuts out about a third of the time, and a cut
; comes back three times in four.
StutterTick:
	subroutine
	lda actCnt+A_STUT
	bne .go
	rts
.go:
	jsr GetTicks
	lda nowL
	sec
	sbc stutAtL
	lda nowH
	sbc stutAtH
	bpl .due
	rts
.due:
	lda beatMs+1            ; next 16th: a quarter beat on (slower with VINYL STOP)
	lsr
	sta t1
	lda beatMs
	ror
	lsr t1
	ror
	sta t0
	ldx vinylLvl
	beq .add
	lda t0
	sta mulA
	lda t1
	sta mulA+1
	txa
	jsr Mul16x8
	lda t0
	clc
	adc mulR+1
	sta t0
	lda t1
	adc mulR+2
	sta t1
.add:
	lda stutAtL
	clc
	adc t0
	sta stutAtL
	lda stutAtH
	adc t1
	sta stutAtH
	inc stutStep
	lda stutStep
	and #3
	beq .on
	jsr Random              ; 0-127
	ldx stutCut
	bne .cut
	cmp #45
	bcs .x
	lda #1
	sta stutCut
	jmp MuteChanged
.cut:
	cmp #32
	bcc .x                  ; stays cut
.on:
	lda stutCut
	beq .x
	lda #0
	sta stutCut
	jmp MuteChanged
.x:
	rts

; Pitch Bend rxD1 / rxD2 on a key channel: the wheel
KeytarWheel:
	subroutine
	lda useShs
	beq .x
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
