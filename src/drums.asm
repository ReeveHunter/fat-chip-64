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
	cmp #DK_KICK
	bne .nk
	lda #1
	sta vizKick             ; (the visualizer's border flash)
.nk:
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
	tax
	lda kitBuf,x
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

; ------------------------------------------------------------ v0.60: beats under the I/O
; BeatLoad: copy beat beatSel's kit, name and steps from under the I/O at
; $D000 (beatsio.asm) into kitBuf, nameBuf and beatBuf
BeatLoad:
	subroutine
	ldx beatSel
	lda beatIoLo,x
	sta ptr
	lda beatIoHi,x
	sta ptr+1
	lda beatSize,x          ; kit 12 + name 9 + its lanes
	tax
	php
	sei
	lda #$34                ; all RAM: what's under the I/O
	sta $01
	ldy #0
.c:
	lda (ptr),y
	sta kitBuf,y            ; (kitBuf, nameBuf and beatBuf follow each other)
	iny
	dex
	bne .c
	lda #$35
	sta $01
	plp
	rts

; ------------------------------------------------------------ v0.61: the 25 beats
; Each beat's lanes say per step: A, B or both (beatsio.asm). The part
; (RUN/STOP N) picks which play; a hat layer (H) stands in for the beat's own
; hats, an accent layer (J) sets each step's level, the time signature (K)
; takes runs of the beat's steps (the cycle), swing (L) delays the off-beats.
; The hits go to the MidiNES (one sample, one noise sound: DrumHit) and / or
; Fat Chip GB (notes on its drum channel: two at once, its own hats), as the
; menu's BEATS ON / BOTH say.

; A = beat: chosen (RUN/STOP keys, the keytar's rhythm buttons). A beat that's
; playing keeps the tempo (Reeve, v0.61); stopped, BEAT TEMPO DEFAULT gives it
; its own.
BeatChoose:
	subroutine
	sta beatSel
	jsr BeatLoad
	lda beatRun
	bne .d
	lda beatTempo
	bne .d
	sta beatFresh
	ldx beatSel
	lda beatBpm,x
	jsr SetBpm
.d:
	jmp Dirty

; menu TIME: the new time signature's cycle
BeatTsHook:
	jsr MakeCycle
	jmp Dirty

; the time signature's runs of the beat's 32 steps -> the cycle
MakeCycle:
	subroutine
	ldx beatTs
	lda tsLo,x
	sta ptr
	lda tsHi,x
	sta ptr+1
	ldy #0
	ldx #0
	lda #$FF
	sta t2                  ; bar
.seg:
	lda (ptr),y
	cmp #$FF
	beq .end
	iny
	sta t0                  ; first step (bit 7: a bar starts)
	bpl .same
	inc t2
	lda #0
	sta t3                  ; place in the bar
.same:
	lda (ptr),y
	iny
	sta t1                  ; steps
	lda t0
	and #$7F
	sta t0
.st:
	lda t0
	sta cycSrc,x
	lda t3
	sta cycPos,x
	lda t2
	sta cycBar,x
	inc t0
	inc t3
	inx
	dec t1
	bne .st
	beq .seg
.end:
	stx cycLen
	lda beatStep
	cmp cycLen
	bcc .x
	lda #0
	sta beatStep
.x:
	rts

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
	sta beatLoop
	lda #3
	sta tripK
	lda beatFresh           ; BEAT TEMPO DEFAULT, and no tempo set since the
	beq .t                  ;  beat was chosen (power on): the beat's own
	lda beatTempo
	bne .t
	sta beatFresh
	ldx beatSel
	lda beatBpm,x
	jsr SetBpm              ; (first: it takes a moment)
.t:
	jsr GetTicks
	lda nowL
	sta beatBaseL
	sta beatAtL
	lda nowH
	sta beatBaseH
	sta beatAtH
	jmp Dirty

; Z clear (A = 1) if the Game Boy plays the beats: on, Fat Chip GB, BEATS ON
; GAME BOY or BOTH
GbBeats:
	subroutine
	lda devOn+DEV_GB
	beq .x
	lda gbFc
	bne .no
	lda beatDev
	beq .x
	lda #1
	rts
.no:
	lda #0
.x:
	rts

; main loop: the Game Boy's side of the beats. While it plays them its wave
; channel is the drums' (the synth gets no note on it), and its drum kit and
; HATS follow the beat and the menu
GbBeatsTick:
	subroutine
	jsr GbTremHeld          ; (v0.66: the tremolo off / back when that changes)
	lda #0
	rol
	cmp gbTremOff
	beq .t
	sta gbTremOff
	jsr GbTrem
.t:
	lda beatRun
	beq .w
	jsr GbBeats
.w:
	cmp vDrum+7             ; (voice 7: the Game Boy's wave)
	beq .k
	sta vDrum+7
	lda #1
	sta reallocFlag
.k:
	jsr GbBeats
	beq .x
	ldx beatSel             ; CC 70: the kit
	lda beatGbKit,x
	tax
	inx
	cpx gbKitSent
	beq .h
	stx gbKitSent
	dex
	lda #70
	jsr GbDrumCc
.h:
	ldx #1                  ; CC 71: HATS (0 SAMPLE, 127 NOISE)
	lda gbBtHats
	beq .hs
	ldx #128
.hs:
	cpx gbHatSent
	beq .x
	stx gbHatSent
	dex
	lda #71
	jmp GbDrumCc
.x:
	rts

; A = CC, X = value, on the Game Boy's drum channel
GbDrumCc:
	subroutine
	sta mD1
	stx mD2
	lda gbBase
	clc
	adc #4
	and #15
	ora #$B0
	sta mS
	jmp GbPut

; A = the swing for the next step (0: on time): BEAT'S or the chosen amount,
; on the odd sixteenths, and twice it on the off-beat eighth in a grid of 8ths
SwingNow:
	subroutine
	ldx beatSel
	lda beatSwing,x
	ldy beatSwg
	beq .v
	lda swingT-1,y
.v:
	sta t2
	ldy beatStep
	lda cycPos,y
	lsr
	bcs .one                ; odd: once
	and #1
	beq .no                 ; (on the beat)
	lda beatGrid8,x
	beq .no
	lda t2                  ; the off-beat eighth: twice
	asl
	rts
.one:
	lda t2
	rts
.no:
	lda #0
	rts

; A = lane (0-13): it plays this step
SetLane:
	subroutine
	cmp #8
	bcs .hi
	tax
	lda bitT,x
	ora hitLo
	sta hitLo
	rts
.hi:
	and #7
	tax
	lda bitT,x
	ora hitHi
	sta hitHi
	rts
bitT:       .byte 1,2,4,8,16,32,64,128

; X = hat layer, Y = place (0-15): its closed and open hats there
HatAt:
	subroutine
	cpy #8
	bcs .h
	lda hatChL,x
	and bitT,y
	beq .o0
	lda #7
	jsr SetLaneX
.o0:
	lda hatOhL,x
	and bitT,y
	beq .x
	lda #8
	jmp SetLaneX
.h:
	tya
	and #7
	tay
	lda hatChH,x
	and bitT,y
	beq .o1
	lda #7
	jsr SetLaneX
.o1:
	lda hatOhH,x
	and bitT,y
	beq .x
	lda #8
	jmp SetLaneX
.x:
	rts
SetLaneX:                       ; (SetLane keeping X and Y)
	stx t2
	sty t3
	jsr SetLane
	ldx t2
	ldy t3
	rts

; the hat layer in use (0: the beat's own hats)
CurHat:
	subroutine
	lda beatHats
	beq .d
	sec
	sbc #1
	rts
.d:
	ldx beatSel
	lda beatHatDef,x
	rts

; A = the step's accent (0 soft, 1 normal, 2 strong) at place Y in bar X
AccentAt:
	subroutine
	sty t2
	txa
	and #1
	asl
	asl
	asl
	asl
	ora t2
	and #31
	sta t2                  ; 0-31: the place in the layer's two bars
	lda beatAcc
	beq .d
	sec
	sbc #1
	jmp .l
.d:
	ldx beatSel
	lda beatAccDef,x
.l:
	cmp #ACC_HUMAN
	bne .t
	jsr Random              ; HUMAN: strong 15%, soft 25%
	cmp #38
	bcc .s
	cmp #102
	bcc .w
	lda #1
	rts
.t:
	asl
	asl
	asl
	sta t3                  ; layer x 8
	lda t2
	lsr
	lsr
	lsr
	clc
	adc t3
	tax                     ; its strong byte (soft: 4 on)
	lda t2
	and #7
	tay
	lda accBits,x
	and bitT,y
	bne .s
	lda accBits+4,x
	and bitT,y
	bne .w
	lda #1
	rts
.s:
	lda #2
	rts
.w:
	lda #0
	rts

; the current step: its lanes (the part, the hat layer), its accent, out to
; the devices
BeatPlay:
	subroutine
	lda beatStep            ; (the cycle starts: a synced TREMOLO starts its cycle)
	bne .vc
	lda nesTremSync
	beq .vc
	lda #0
	sta tremPhL
	sta tremPhH
.vc:
	lda vinylCut            ; VINYL STOP has stopped: no drums
	beq .run
	rts
.run:
	lda #0
	sta hitLo
	sta hitHi
	sta hitFill
	lda actCnt+A_FILL       ; BEAT FILL held: snare and toms instead
	beq .pat
	ldy fillK
	lda fillL,y
	sta hitLo
	lda fillV,y
	sta hitSt
	inc hitFill
	iny
	tya
	and #15
	sta fillK
	jmp BeatSend
.pat:
	; the part: A 1, B 2, A+B 3, A<->B: A on even loops, B on odd
	ldy beatPart
	lda partMaskT,y
	cpy #3
	bne .pm
	lda beatLoop
	and #1
	clc
	adc #1
.pm:
	sta bB
	jsr CurHat
	sta bA                  ; (0: the beat's own hats)
	ldx beatStep
	lda cycSrc,x
	sta t0                  ; the beat's step
	and #3
	asl
	sta t2                  ; its two bits' place in a lane's byte
	lda t0
	lsr
	lsr
	sta t1
	lda beatBuf             ; lanes
	sta t3
	sec
	adc t1                  ; (1 + n + byte)
	tay
	ldx #0
.ln:
	cpx t3
	bcs .lnd
	lda beatBuf,y
	stx drumTom             ; (a spare byte here)
	ldx t2
	beq .ns
.sh:
	lsr
	dex
	bne .sh
.ns:
	and bB                  ; the part
	beq .nx
	ldx drumTom
	lda beatBuf+1,x         ; the lane
	cmp #7                  ; (a hat layer stands in for the beat's hats)
	beq .hat
	cmp #8
	bne .set
.hat:
	ldx bA
	bne .nx
.set:
	sty t1
	jsr SetLane
	ldy t1
.nx:
	ldx drumTom
	inx
	tya
	clc
	adc #8
	tay
	jmp .ln
.lnd:
	ldx beatStep            ; the accent
	ldy cycPos,x
	lda cycBar,x
	tax
	jsr AccentAt
	sta hitSt
	ldx bA                  ; the hat layer's hats
	beq .fe
	ldy beatStep
	lda cycPos,y
	tay
	lda hatTrip,x
	bne .tr
	tya
	and #15
	tay
	jsr HatAt
	jmp .fe
.tr:
	tya                     ; triplets: three to a beat, from its start
	and #3
	bne .fe
	tya
	lsr
	lsr
	sta t0                  ; the beat in the bar
	asl
	adc t0                  ; x 3
.m12:
	cmp #12
	bcc .j
	sbc #12
	bcs .m12
.j:
	sta tripJ
	tay
	jsr HatAt               ; the first now
	lda #1
	sta tripK
	lda beat16L             ; a third of a beat, in ms (beat / 48 of 1/16 ms)
	sta dvdL
	lda beat16H
	sta dvdH
	lda #48
	sta dvsL
	lda #0
	sta dvsH
	jsr Div16
	lda dvdL
	sta tripMs
	lda dvdH
	sta tripMs+1
	lda beatBaseL
	clc
	adc tripMs
	sta tripAtL
	lda beatBaseH
	adc tripMs+1
	sta tripAtH
.fe:
	lda fillEnd             ; a fill just ended: crash and kick
	beq BeatSend
	lda hitLo
	ora #1
	sta hitLo
	lda hitHi
	ora #2
	sta hitHi
	lda #2
	sta hitSt
	lda fillEnd
	cmp #2
	bne .fe2
	lda #0                  ; the fill started the beat: it stops now
	sta beatRun
	sta fillSolo
	jsr Dirty
.fe2:
	lda #0
	sta fillEnd
	; (on to BeatSend)

; hitLo / hitHi / hitSt out: to the Game Boy (a note per lane on its drum
; channel), then the MidiNES (the most important sample, the most important
; noise sound). SPLIT: the NES the drums (kick .. lo tom), the Game Boy the
; hats, cymbals, shaker, cowbell and clave.
BeatSend:
	subroutine
	lda hitLo
	sta bA
	lda hitHi
	sta bB
	jsr GbBeats
	beq .nes
	lda beatDev
	cmp #2
	bne .gall
	lda beatSplit
	beq .gall
	lda bA                  ; SPLIT: the Game Boy's lanes
	and #$80
	sta bA
.gall:
	lda gbBase
	clc
	adc #4
	and #15
	ora #$90
	sta mS
	ldy #0
.g:
	cpy #14
	bcs .nes
	lsr bB
	ror bA
	bcc .gn
	lda gbDrumNote,y
	sta mD1
	jsr VelOf
	sta mD2
	sty t0
	jsr GbPut
	ldy t0
.gn:
	iny
	bne .g
.nes:
	lda beatDev
	cmp #1
	beq .x                  ; (GAME BOY only)
	lda hitLo
	sta bA
	lda hitHi
	sta bB
	lda beatDev
	beq .n2
	lda beatSplit
	beq .n2
	lda bA                  ; SPLIT: the NES's lanes
	and #$7F
	sta bA
	lda #0
	sta bB
.n2:
	ldy #0                  ; the sample: the first there is
.d:
	cpy #9
	bcs .z
	lda dmcOrder,y
	jsr LaneIn
	bne .dh
	iny
	bne .d
.dh:
	lda dmcOrder,y
	jsr NesLevel
	lda dmcTomT,y
	sta t0
	lda dmcKindT,y
	ldy t0
	jsr DrumHit
.z:
	ldy #0                  ; the noise sound
.e:
	cpy #5
	bcs .x
	lda nzOrder,y
	jsr LaneIn
	bne .zh
	iny
	bne .e
.zh:
	lda nzOrder,y
	jsr NesLevel
	lda nzKindT,y
	jmp DrumHit
.x:
	rts

; A = lane: Z clear if it's in bA / bB. Keeps Y.
LaneIn:
	subroutine
	cmp #8
	bcs .h
	tax
	lda bitT,x
	and bA
	rts
.h:
	and #7
	tax
	lda bitT,x
	and bB
	rts

; A = lane -> X = the NES level (0 ghost, 1 hit, 2 accent): kick, snare, clap
; and rim take only the strong steps, the shaker plays soft. Keeps Y.
NesLevel:
	subroutine
	ldx hitSt
	cmp #11
	beq .sh
	cmp #4
	bcs .x
	ldx hitFill             ; (a fill's levels are its own)
	bne .f
	ldx #1
	lda hitSt
	cmp #2
	bne .x
	ldx #2
.x:
	rts
.f:
	ldx hitSt
	rts
.sh:
	ldx #0
	lda hitSt
	cmp #2
	bne .x
	inx
	rts

; Y = lane -> A = the Game Boy velocity (as NesLevel: 56 / 100 / 127). Keeps Y.
VelOf:
	subroutine
	tya
	jsr NesLevel
	lda velT,x
	rts
velT:       .byte 56,100,127

; the sample's order (kick, snare, clap, toms, rim, cowbell, clave) and the
; noise sound's (crash, ride, open hat, closed hat, shaker)
dmcOrder:   .byte 0,1,2,4,5,6,3,12,13
dmcKindT:   .byte DK_KICK,DK_SNARE,DK_PERC,DK_TOM,DK_TOM,DK_TOM,DK_PERC,DK_PERC,DK_PERC
dmcTomT:    .byte 0,0,0,0,1,2,0,0,0
nzOrder:    .byte 9,10,8,7,11
nzKindT:    .byte DK_CY,DK_CY,DK_OH,DK_CH,DK_CH
partMaskT:  .byte 1,2,3

; BeatTick, first: the triplet hat layer's second and third hats of a beat
TripTick:
	subroutine
	lda tripK
	cmp #3
	bcs .x
	jsr GetTicks
	lda nowL
	sec
	sbc tripAtL
	lda nowH
	sbc tripAtH
	bmi .x
	lda #0
	sta hitLo
	sta hitHi
	sta hitFill
	lda #1                  ; (between the steps: normal)
	sta hitSt
	jsr CurHat
	tax
	lda hatTrip,x           ; (the layer changed meanwhile: no more)
	beq .stop
	lda tripJ
	clc
	adc tripK
	tay
	jsr HatAt
	inc tripK
	lda tripAtL
	clc
	adc tripMs
	sta tripAtL
	lda tripAtH
	adc tripMs+1
	sta tripAtH
	lda hitLo
	ora hitHi
	beq .x
	jmp BeatSend
.stop:
	lda #3
	sta tripK
.x:
	rts

; BEAT FILL: one bar of snare and toms, round again while held (lanes, level)
fillL:      .byte 2,2,2,2, $10,$10,$20,$20, 2,2,$20,$20, $40,$40,2,2
fillV:      .byte 2,0,1,1, 1,1,1,1, 2,1,1,1, 1,1,1,2


; F5: start / stop
BeatRunKey:
	subroutine
	lda beatRun
	bne .stop
	jmp BeatBegin
.stop:
	lda #0
	sta beatRun
	jsr NoiseOff
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
	jsr GbBeatsTick         ; (v0.61: the Game Boy's side)
	lda beatRun
	bne .on
	sta beatClkNew          ; (stopped: no beat clock left waiting)
	rts
.on:
	jsr TripTick            ; (v0.61: a triplet hat layer's hats between steps)
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
	lda #4                  ; (four steps to a beat)
	sta dvsL
	lda #0
	sta dvsH
	jsr Div16
	lda dvdL
	sta step16L
	lda dvdH
	sta step16H
	lda actCnt+A_VINYL      ; VINYL STOP held: slower, up to 8x (v0.61: let go,
	beq .nv                 ;  the beat's straight back while the pitch winds up)
	lda vinylLvl
	beq .nv
	lda step16L
	sta mulA
	lda step16H
	sta mulA+1
	jsr VinylExtra
	lda step16L
	clc
	adc mulA
	sta step16L
	lda step16H
	adc mulA+1
	sta step16H
	bcc .nv
	lda #$FF                ; (as long as it goes)
	sta step16L
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
	inc beatStep            ; (v0.61: through the cycle the time signature makes)
	lda beatStep
	cmp cycLen
	bcc .n
	lda #0
	sta beatStep
	inc beatLoop
.n:
	inc beatSub
	lda beatSub
	cmp #4
	bcc .sw
	lda #0
	sta beatSub
.sw:
	lda beatBaseL
	sta beatAtL
	lda beatBaseH
	sta beatAtH
	; swing: odd steps late by step x swing / 256 (grid of 8ths: the off-beat
	; eighth twice that); the step's place in its bar decides
	jsr SwingNow
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
	lda beatSub
	bne .k
.anc:
	jmp .anchor
.k:
	lda #2                  ; (half a beat)
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
	lda #4                  ; jump to the next beat
	sec
	sbc beatSub
	clc
	adc beatStep
	cmp cycLen
	bcc .st
	sbc cycLen
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

; BEAT FILL held (A = 1) / let go (0): with no beat playing, the fill starts
; it, and it stops after the crash
ActFill:
	subroutine
	cmp #0
	beq .rel
	lda #0
	sta fillK
	sta fillEnd
	lda beatRun
	bne .x
	lda #1
	sta fillSolo
	jmp BeatBegin
.rel:
	lda beatRun
	beq .x
	lda #1
	ldy fillSolo
	beq .e
	lda #2
.e:
	sta fillEnd
.x:
	rts

