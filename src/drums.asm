; Fat Chip 64 - drums on the MidiNES
;
; Two sources, one kit:
;   the keytar's rhythm   MIDI in channel 16 (Yamaha SHS-10: 45 kick, 48 tom,
;                         52 snare, 57 hat, 62 cymbal; velocity 127 = accent,
;                         64 = hit, 56 = ghost)
;   the beat demos        G picks one of six Beat Lab beats (and its kit),
;                         RETURN starts / stops it, at its own tempo (B taps
;                         a new one)
; Kick, snare, toms and percussion are samples on the MidiNES's sample
; channel (one at a time: a hit within DRUM_WINDOW ms of a more important one
; is dropped; kick > snare > tom > perc). Hats and cymbals are NES noise:
; a note-on, then a note-off after the sound's length, the level set with
; CC7; closed hats vary their note and level a little on each hit (the Beat
; Lab's noise hats). Kits are in beats.asm (tools/gen_beats.py).

KIT_SIZE    equ 12
DRUM_WINDOW equ 12              ; ms
DK_KICK     equ 0
DK_SNARE    equ 1
DK_CH       equ 2
DK_OH       equ 3
DK_CY       equ 4
DK_TOM      equ 5
DK_PERC     equ 6

; A = kind, X = level (0 ghost, 1 hit, 2 accent), Y = tom (0 hi, 1 mid, 2 lo)
DrumHit:
	subroutine
	sta drumKind
	stx drumLvl
	sty drumTom
	lda devOn+DEV_NES
	bne .on
	rts
.on:
	jsr GetTicks
	lda drumKind
	cmp #DK_CH
	bcc .dmc
	cmp #DK_TOM
	bcs .dmc
	jmp NoiseHit
.dmc:
	ldx drumKind
	lda dmcPrioT,x
	sta t0
	lda nowL
	sec
	sbc dmcAt
	tay
	lda nowH
	sbc dmcAt+1
	bne .ok                 ; (16 bits: a hit 256 ms ago isn't "just now")
	cpy #DRUM_WINDOW
	bcs .ok
	lda t0                  ; soon after another hit: only if this one matters more
	cmp dmcPrio
	bcc .ok
	rts
.ok:
	; the sample: kit[beat][kitOfs[kind] + level, or + tom]
	ldx drumKind
	lda kitOfs,x
	cpx #DK_TOM
	bne .lv
	clc
	adc drumTom
	jmp .k
.lv:
	clc
	adc drumLvl
.k:
	sta t1
	lda beatSel             ; x 12
	asl
	asl
	sta t2
	asl
	adc t2
	adc t1
	tax
	lda kits,x
	sta t1
	; bank (CC14 on the sample channel) when it changes
	lda #4
	jsr NesChStatus         ; mS = CC, sample channel
	lda #0
	ldx t1
	bpl .a
	lda #127
.a:
	cmp dmcBank
	beq .note
	sta dmcBank
	sta mD2
	lda #14
	sta mD1
	jsr NesPut
.note:
	lda mS
	and #$0F
	sta t2                  ; channel
	lda t1                  ; (no note-off for the last sample: a note-on
	                        ;  cuts it anyway, and the hit lands 1 ms sooner)
	and #$7F
	sta dmcNote
	sta mD1
	lda t2
	ora #$90
	sta mS
	lda #127
	sta mD2
	jsr NesPut
	lda t0
	sta dmcPrio
	lda nowL
	sta dmcAt
	lda nowH
	sta dmcAt+1
	rts

dmcPrioT:   .byte 0,1,0,0,0,2,3   ; kick, snare, -, -, -, tom, perc
kitOfs:     .byte 0,3,0,0,0,6,9

; mS = control change on MidiNES channel nesBase + A
NesChStatus:
	subroutine
	clc
	adc nesBase
	and #15
	ora #$B0
	sta mS
	rts

; hats and cymbals: NES noise (one at a time; cymbal > open > closed)
NoiseHit:
	subroutine
	lda drumKind
	sec
	sbc #DK_CH
	sta t0                  ; 0 closed, 1 open, 2 cymbal
	lda #2
	sec
	sbc t0
	sta t3                  ; priority (0 = most important)
	lda nowL
	sec
	sbc nzAt
	tay
	lda nowH
	sbc nzAt+1
	bne .ok
	cpy #DRUM_WINDOW
	bcs .ok
	lda t3
	cmp nzPrio
	bcc .ok
	rts
.ok:
	lda t0                  ; preset = sound x 3 + level
	asl
	adc t0
	adc drumLvl
	tax
	lda nzNoteT,x
	sta t1
	lda nzVolT,x
	sta t2
	lda nzLenT,x
	sta nzLen
	lda t0
	bne .send
	; closed hats: a third of the time a neighbouring noise note, a third
	; of the time a level up or down
	jsr Random
	sta drumTom
	and #3
	beq .send
	cmp #1
	bne .nd
	inc t1
	bne .lv
.nd:
	cmp #2
	bne .lv
	dec t1
.lv:
	lda drumTom
	lsr
	lsr
	and #3
	beq .send
	cmp #1
	bne .vd
	inc t2
	bne .send
.vd:
	cmp #2
	bne .send
	dec t2
.send:
	lda #3
	jsr NesChStatus
	lda mS
	and #$0F
	sta drumKind            ; (channel; the kind isn't needed any more)
	lda nzNote              ; the last noise note off
	cmp #$FF
	beq .vol
	sta mD1
	lda drumKind
	ora #$80
	sta mS
	lda #0
	sta mD2
	jsr NesPut
.vol:
	lda t2                  ; level: CC7 = level x 8, when it changes
	cmp nzVol
	beq .on
	sta nzVol
	asl
	asl
	asl
	sta mD2
	lda #7
	sta mD1
	lda drumKind
	ora #$B0
	sta mS
	jsr NesPut
.on:
	lda t1
	sta nzNote
	sta mD1
	lda drumKind
	ora #$90
	sta mS
	lda #127
	sta mD2
	jsr NesPut
	; it stops after its length (4 ms units)
	lda nzLen
	asl
	sta t2
	lda #0
	rol
	sta t1
	asl t2
	rol t1
	lda nowL
	clc
	adc t2
	sta nzOffL
	lda nowH
	adc t1
	sta nzOffH
	lda t3
	sta nzPrio
	lda nowL
	sta nzAt
	lda nowH
	sta nzAt+1
	rts

; noise presets: closed hat, open hat, cymbal x ghost / hit / accent
; (MidiNES long-mode noise: note = 51 - period; the Beat Lab's closed hat
; is period 1, open 2, crash 3)
nzNoteT:    .byte 50,50,50, 49,49,49, 48,48,48
nzVolT:     .byte 4,6,8, 5,6,7, 5,6,7
nzLenT:     .byte 8,11,15, 50,65,80, 150,225,255

; main loop: the noise note's time is up
DrumTick:
	subroutine
	lda nzNote
	cmp #$FF
	beq .x
	jsr GetTicks
	lda nowL
	sec
	sbc nzOffL
	lda nowH
	sbc nzOffH
	bmi .x
NoiseOff:
	lda nzNote
	cmp #$FF
	beq .x
	sta mD1
	lda #$FF
	sta nzNote
	lda devOn+DEV_NES
	beq .x
	lda #3
	jsr NesChStatus
	and #$0F
	ora #$80
	sta mS
	lda #0
	sta mD2
	jmp NesPut
.x:
	rts

; ------------------------------------------------------------ keytar
; MIDI in channel 16 note-on (rxD1, velocity rxD2)
KeytarDrum:
	subroutine
	ldx #4
.f:
	lda keytarNote,x
	cmp rxD1
	beq .hit
	dex
	bpl .f
	rts
.hit:
	lda keytarKind,x
	pha
	ldx #2                  ; 80 = the SHS-10's accent (measured), 64 hit, 56 ghost
	lda rxD2
	cmp #72
	bcs .l
	dex
	cmp #61
	bcs .l
	dex
.l:
	ldy #1                  ; the keytar's one tom: mid
	pla
	jmp DrumHit

keytarNote: .byte 45,48,52,57,62
keytarKind: .byte DK_KICK,DK_TOM,DK_SNARE,DK_CH,DK_CY

; ------------------------------------------------------------ beat demos
; G: next beat (its kit and tempo)
BeatKey:
	subroutine
	ldx beatSel
	inx
	cpx #NUM_BEATS
	bcc .s
	ldx #0
.s:
	txa
; A = beat: chosen (G, or the keytar's rhythm buttons)
BeatChoose:
	sta beatSel
	tax
	lda beatStep
	cmp beatLen,x
	bcc .t
	lda #0
	sta beatStep
	sta beatSub
.t:
	lda beatBpm,x
	jsr SetBpm
	jmp Dirty

; RETURN: start / stop
BeatRunKey:
	subroutine
	lda beatRun
	beq BeatBegin
	lda #0
	sta beatRun
	jsr NoiseOff
	jmp Dirty

; the beat starts now, from step 1
BeatBegin:
	subroutine
	lda #1
	sta beatRun
	lda #0
	sta beatStep
	sta beatSub
	sta beatFrac
	sta beatWait
	ldx beatSel             ; at the beat's own tempo (unless the keytar's)
	lda beatBpm,x
	jsr SetBpm              ; (first: it takes a moment)
	jsr GetTicks
	lda nowL
	sta beatBaseL
	sta beatAtL
	lda nowH
	sta beatBaseH
	sta beatAtH
	jmp Dirty

; A = BPM, the beat's own: the tempo, unless the keytar's clock sets it
; (Synthcart: snapped to its nearest)
SetBpm:
	subroutine
	sta t3
	jsr FollowActive
	bne .x
	lda t3
	sta bpm
	lsr
	clc
	adc #<60000             ; 60000 / bpm, rounded
	sta dvdL
	lda #>60000
	adc #0
	sta dvdH
	lda t3
	sta dvsL
	lda #0
	sta dvsH
	jsr Div16
	lda dvdL
	sta beatMs
	lda dvdH
	sta beatMs+1
	jsr TempoChosen
	jsr SendTempo
	lda #1
	sta screenDirty
.x:
	rts

; main loop: play a step when it's due
BeatTick:
	subroutine
	lda beatRun
	bne .on
	sta beatClkNew          ; (stopped: no beat clock left waiting)
	rts
.on:
	jsr BeatFollow
.wait:
	lda beatWait
	beq .due0
	jsr FollowActive        ; the clock stopped: carry on by ourselves
	beq .free
	rts
.free:
	lda #0
	sta beatWait
.due0:
	jsr GetTicks
	lda nowL
	sec
	sbc beatAtL
	lda nowH
	sbc beatAtH
	bpl .due
	rts
.due:
	jsr BeatPlay
	; step length in 1/16 ms = beat / steps per beat
	lda beat16L
	sta dvdL
	lda beat16H
	sta dvdH
	ldx beatSel
	lda beatSpb,x
	sta dvsL
	lda #0
	sta dvsH
	jsr Div16
	lda dvdL
	sta step16L
	lda dvdH
	sta step16H
	lda vinylLvl            ; VINYL STOP: slower, down to half speed
	beq .nv
	lda step16L
	sta mulA
	lda step16H
	sta mulA+1
	lda vinylLvl
	jsr Mul16x8
	lda step16L
	clc
	adc mulR+1
	sta step16L
	lda step16H
	adc mulR+2
	sta step16H
.nv:
	; base += (frac + step) / 16
	lda step16L
	clc
	adc beatFrac
	sta t0
	lda step16H
	adc #0
	sta t1
	lda t0
	and #15
	sta beatFrac
	ldx #4
.d16:
	lsr t1
	ror t0
	dex
	bne .d16
	lda beatBaseL
	clc
	adc t0
	sta beatBaseL
	lda beatBaseH
	adc t1
	sta beatBaseH
	; more than 255 ms behind (a long pass, or the clock changed): from now
	lda nowL
	sec
	sbc beatBaseL
	lda nowH
	sbc beatBaseH
	bmi .ok
	beq .ok
	lda nowL
	sta beatBaseL
	lda nowH
	sta beatBaseH
.ok:
	ldx beatSel
	inc beatStep
	lda beatStep
	cmp beatLen,x
	bcc .n
	lda #0
	sta beatStep
.n:
	inc beatSub
	lda beatSub
	cmp beatSpb,x
	bcc .sw
	lda #0
	sta beatSub
.sw:
	lda beatBaseL
	sta beatAtL
	lda beatBaseH
	sta beatAtH
	; swing: odd steps late by step x swing / 256
	lda beatStep
	and #1
	beq .x
	lda beatSwing,x
	beq .x
	pha
	lda step16L
	sta mulA
	lda step16H
	sta mulA+1
	pla
	jsr Mul16x8
	lda mulR+1              ; / 4096 (1/16 ms -> ms, and / 256)
	lsr
	lsr
	lsr
	lsr
	sta t0
	lda mulR+2
	asl
	asl
	asl
	asl
	ora t0
	clc
	adc beatAtL
	sta beatAtL
	bcc .x
	inc beatAtH
.x:
	rts

; BeatTick, first: a keytar beat clock came in
BeatFollow:
	subroutine
	; following the keytar: the beat runs on by itself, and each of its beat
	; clocks corrects it. k = steps of this beat already played:
	;   0          the clock is ahead of us: this beat starts now
	;   1 .. spb/2  we're in step: the rest of the beat counts from the clock
	;   more        the clock is early: skip to the next beat, starting now
	; (After a keytar Start, step 1 waits for the first clock: beatWait.)
	lda beatWait
	beq .flag
	lda beatClkNum          ; after a Start: the beat clock that followed it (or
	sec                     ;  a later one, if the Start was seen late)
	sbc beatWaitBeat
	bmi .no
	lda #0
	sta beatClkNew
	jmp .anchor
.flag:
	lda beatClkNew
	bne .new
.no:
	rts
.new:
	lda #0
	sta beatClkNew
	jsr FollowActive
	beq .no
	ldx beatSel
	lda beatSub
	bne .k
.anc:
	jmp .anchor
.k:
	lda beatSpb,x
	lsr
	cmp beatSub
	bcc .skip
	; rebase: the next step = clock + k steps
	lda beatClkL
	sta t0
	lda beatClkH
	sta t1
	lda #0
	sta beatFrac
	ldy beatSub
.rb:
	lda step16L
	clc
	adc beatFrac
	sta beatFrac
	lda step16H
	adc #0
	sta t2
	lda beatFrac
	lsr t2
	ror
	lsr t2
	ror
	lsr t2
	ror
	lsr t2
	ror                     ; whole ms of (frac + step)
	clc
	adc t0
	sta t0
	lda t1
	adc t2
	sta t1
	lda beatFrac
	and #15
	sta beatFrac
	dey
	bne .rb
	lda t0
	sta beatBaseL
	sta beatAtL
	lda t1
	sta beatBaseH
	sta beatAtH
	rts
.skip:
	lda beatSpb,x           ; jump to the next beat
	sec
	sbc beatSub
	clc
	adc beatStep
	cmp beatLen,x
	bcc .st
	sbc beatLen,x
.st:
	sta beatStep
.anchor:
	lda #0
	sta beatSub
	sta beatFrac
	sta beatWait
	lda beatClkL
	sta beatBaseL
	sta beatAtL
	lda beatClkH
	sta beatBaseH
	sta beatAtH
.x:
	rts

; the current step's hits: one sample (kick, snare, tom, perc: the first
; there is) and one noise sound (cymbal, open hat, closed hat)
BeatPlay:
	subroutine
	ldx beatSel
	lda beatLo,x
	sta ptr
	lda beatHi,x
	sta ptr+1
	lda beatStep
	asl
	tay
	lda (ptr),y
	sta bA
	iny
	lda (ptr),y
	sta bB
	lda bA
	and #3
	beq .s
	tax
	dex
	lda #DK_KICK
	jsr DrumHit
	jmp .noise
.s:
	lda bA
	lsr
	lsr
	and #3
	beq .t
	tax
	dex
	lda #DK_SNARE
	jsr DrumHit
	jmp .noise
.t:
	lda bA
	lsr
	lsr
	lsr
	lsr
	and #3
	beq .p
	tay
	dey
	ldx #1
	lda #DK_TOM
	jsr DrumHit
	jmp .noise
.p:
	lda bA
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	beq .noise
	tax
	dex
	lda #DK_PERC
	jsr DrumHit
.noise:
	lda bB
	lsr
	lsr
	lsr
	lsr
	and #3
	beq .o
	tax
	dex
	lda #DK_CY
	jmp DrumHit
.o:
	lda bB
	lsr
	lsr
	and #3
	beq .c
	tax
	dex
	lda #DK_OH
	jmp DrumHit
.c:
	lda bB
	and #3
	beq .x
	tax
	dex
	lda #DK_CH
	jmp DrumHit
.x:
	rts
