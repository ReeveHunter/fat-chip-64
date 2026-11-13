; Fat Chip 64 - the devices plugged into MIDI IN (v0.24): DEVICES says which
; are in use, and each one in use gets its page on the main menu.
;
; YAMAHA SHS-10 (the keytar)
;   TEMPO           FOLLOW / IGNORE: its MIDI clock sets the tempo
;   SHS-10 RHYTHM   IGNORE / PLAY ON MIDINES: its drum notes (channel 16)
;   START/STOP      BUILT-IN BEATS / IGNORE: its Start and Stop start / stop
;                   Fat Chip's beat. (RUN/STOP always does too. Both rhythms
;                   can play at once.)
;   VOICE BUTTONS   PICK PATCH / IGNORE: its 25 voices pick the 25 bank slots
;                   (A1-A5, S1-S5 ... an empty slot does nothing)
;   RHYTHM BUTTONS, WHEEL, VIBRATO / PORTAMENTO / SUSTAIN BUTTON: sync.asm
; CASIO DH-100 (the horn: MIDI out only; breath = channel pressure)
;   BREATH          VOLUME / VOLUME+FILTER / FILTER / OFF: blowing harder is
;                   louder (the SID and the NES; the Game Boy would click) or
;                   brighter (the SID's filter: switched on if the patch has
;                   none)
;   BREATH FX1, FX2 a depth that follows the breath (VIBRATO, WARBLE, DETUNE:
;                   the patch's, or the ADVANCED amounts if it has none;
;                   FILTER), or an action held while blowing hard
;   BREATH FEEL     SOFT / NORMAL / HARD
;   NOTES           AS PLAYED / CHORD / HARMONY (a third above, in the key)
;   PORTAMENTO BUTTON  an action (CC 65)
;   TONE BUTTONS    PICK BANK / IGNORE: its six tones pick the banks FAT,
;                   PADS, LEADS, BASS, FX, and the sixth rolls the dice
; ATARI SYNTHCART
;   TEMPO           OFF / SYNC: tempos snap to Synthcart's ten; , . nudge
;                   about 3% while held, SHIFT + , . step through the ten
;   TRIM            -8..+8: about 0.1% a step, for clock drift

BREATH_HI   equ 64              ; a held action: on at this breath, off under BREATH_LO
BREATH_LO   equ 40
BFX_VIB     equ 1
BFX_WARB    equ 2
BFX_DET     equ 3
BFX_FILT    equ 4
BFX_HELD    equ 5

; the devices' settings -> what the MIDI code checks
SyncDerive:
	subroutine
	ldx #TEMPO_OWN
	lda useShs
	beq .t1
	lda shsTempo
	bne .t1
	ldx #TEMPO_KEYTAR
	bne .t
.t1:
	lda useSc
	beq .t
	lda scSync
	beq .t
	ldx #TEMPO_SC
.t:
	stx syncTempo
	lda #1                  ; start / stop: 0 = the keytar's
	ldx useShs
	beq .s
	lda shsStart
.s:
	sta syncStart
	lda #0                  ; drum notes: 1 = play them
	ldx useShs
	beq .d
	lda shsRhythm
.d:
	sta syncDrums
	jsr BreathFlags
	jsr ApplySettings       ; (DH-100 NOTES)
	lda #1
	sta reallocFlag
	jsr FxVars
	jsr WarbleSend
	lda syncTempo
	cmp #TEMPO_SC
	bne .x
	jmp TempoChosen         ; Synthcart: snap the tempo now
.x:
	rts

; BREATH, BREATH FX: which jobs the breath has
BreathFlags:
	subroutine
	lda #0
	sta brVol
	sta brVib
	sta brWarb
	sta brDet
	sta brFilt
	sta brAtt
	lda useDh
	beq .x
	lda dhBreath
	cmp #2
	bcs .nv
	inc brVol               ; VOLUME, VOLUME+FILTER
.nv:
	cmp #1
	beq .f
	cmp #2
	bne .fx
.f:
	inc brFilt
.fx:
	ldx #1
.l:
	lda dhFx1,x
	cmp #BFX_VIB
	bne .l2
	inc brVib
.l2:
	cmp #BFX_WARB
	bne .l3
	inc brWarb
.l3:
	cmp #BFX_DET
	bne .l4
	inc brDet
.l4:
	cmp #BFX_FILT
	bne .l5
	inc brFilt
.l5:
	dex
	bpl .l
	jsr BreathAtt
.x:
	rts

; BREATH FX changed: let go of what the old ones held
BreathFxHook:
	jsr BreathLetGo
	jmp SyncDerive

; DEVICES changed
UseHook:
	subroutine
	jsr BreathLetGo
	lda useDh
	bne .x
	lda #127                ; (no DH-100: full breath)
	sta breath
.x:
	jmp SyncDerive

DhNotesHook:
	jsr SyncDerive
	jmp SettingChanged

; the breath's held actions end
BreathLetGo:
	subroutine
	ldx #1
.l:
	lda breathHeld,x
	beq .n
	lda #0
	sta breathHeld,x
	sta t3
	stx exK
	lda dhFx1,x
	sec
	sbc #BFX_HELD
	jsr DoAction
	ldx exK
.n:
	dex
	bpl .l
	rts

; Channel pressure rxD1 (the DH-100's breath)
Breath:
	subroutine
	lda useDh
	bne .on
	rts
.on:
	lda rxD1
	sta breathRaw
	ldx dhFeel
	beq .soft
	dex
	beq .set
	tay                     ; HARD: raw x raw / 128
	jsr Mul8
	asl mt16
	lda mt16+1
	rol
	jmp .set
.soft:
	lsr                     ; SOFT: raw x 1.5, to 127
	clc
	adc breathRaw
	bpl .set
	lda #127
.set:
	sta breath
	jsr BreathAtt
	lda breath              ; depths: in 16 steps
	lsr
	lsr
	lsr
	cmp brLvl
	beq .held
	sta brLvl
	lda brVib
	ora brDet
	beq .w
	jsr FxVars
.w:
	lda brWarb
	beq .held
	jsr WarbleSend
.held:
	ldx #1
.h:
	lda dhFx1,x
	cmp #BFX_HELD
	bcc .hn
	lda breathHeld,x
	bne .isOn
	lda breath
	cmp #BREATH_HI
	bcc .hn
	lda #1
	bne .chg
.isOn:
	lda breath
	cmp #BREATH_LO
	bcs .hn
	lda #0
.chg:
	sta breathHeld,x
	sta t3
	stx exK
	lda dhFx1,x
	sec
	sbc #BFX_HELD
	jsr DoAction
	ldx exK
.hn:
	dex
	bpl .h
	rts

; brAtt: the tremolo's extra drop for BREATH VOLUME (0 loud - 15 silent)
BreathAtt:
	subroutine
	lda #0
	ldx brVol
	beq .s
	lda breath
	lsr
	lsr
	lsr
	eor #15
.s:
	sta brAtt
	rts

; A = a depth -> A x breath / 128 (keeps X)
BreathScale:
	ldy breath
	jsr Mul8
	asl mt16
	lda mt16+1
	rol
	rts

; A = the SID's cutoff -> closed down with the breath when it has the filter
BreathCut:
	subroutine
	ldy brFilt
	beq .x
	jsr BreathScale
	cmp #12
	bcs .x
	lda #12
.x:
	rts

; Program Change rxD1 from a DH-100 tone button (0-5)
DhTone:
	subroutine
	lda dhTone
	bne .x
	ldx rxD1
	cpx #5
	bcc .bank
	bne .x
	jmp DiceRoll            ; the sixth: the dice
.bank:
	jmp BankPick
.x:
	rts

; ------------------------------------------------------------ Synthcart tempo
; , / . with SYNTHCART SYNC: nudge (held) or, with SHIFT, the next of the ten.
; Carry set = handled.
ScTempoKey:
	subroutine
	ldy syncTempo
	cpy #TEMPO_SC
	beq .sc
	clc
	rts
.sc:
	sta t3                  ; 0 down (slower), 1 up
	lda shiftDown
	beq .nudge
	ldy scIdx               ; a slower tempo is a longer beat: up the list
	lda t3
	bne .faster
	cpy #9
	bcs .done
	iny
	bne .step
.faster:
	tya
	beq .done
	dey
.step:
	sty scIdx
	lda #0
	sta beatFresh
	jsr ScBeat
.done:
	sec
	rts
.nudge:
	lda nudgeOn
	bne .done               ; (already nudged: the key repeats)
	lda beat16L
	sta nudgeL
	lda beat16H
	sta nudgeH
	sta t1
	lda beat16L
	ldx #5                  ; beat / 32: about 3%
.d:
	lsr t1
	ror
	dex
	bne .d
	sta t0
	ldx t3
	inx
	stx nudgeOn             ; 1 slower, 2 faster
	cpx #2
	beq .fast
	lda nudgeL
	clc
	adc t0
	pha
	lda nudgeH
	adc t1
	tax
	pla
	jmp .go
.fast:
	lda nudgeL
	sec
	sbc t0
	pha
	lda nudgeH
	sbc t1
	tax
	pla
.go:
	jsr SetBeat16
	sec
	rts

; , or . let go: the nudge ends
ScNudgeEnd:
	subroutine
	lda nudgeOn
	beq .x
	lda #0
	sta nudgeOn
	lda nudgeL
	ldx nudgeH
	jmp SetBeat16
.x:
	rts

; Synthcart tempo scIdx, with TRIM (beat + beat / 1024 x (TRIM - 8))
ScBeat:
	subroutine
	ldy scIdx
	lda scBeatH,y
	lsr
	lsr                     ; beat / 1024
	sta t2
	lda scBeatL,y
	sta t0
	lda scBeatH,y
	sta t1
	lda scTrim
	sec
	sbc #8
	beq .go
	bcc .neg
	tax
.p:
	lda t0
	clc
	adc t2
	sta t0
	bcc .p1
	inc t1
.p1:
	dex
	bne .p
	beq .go
.neg:
	eor #$FF
	tax
	inx
.n:
	lda t0
	sec
	sbc t2
	sta t0
	bcs .n1
	dec t1
.n1:
	dex
	bne .n
.go:
	lda t0
	ldx t1
	jmp SetBeat16
