; Fat Chip 64 - ATTACK, BEND IN, BEND OUT (v0.30): how each note starts and
; ends in pitch
;
; ATTACK (the SID): BLIP: an octave up for one BLIP STEP, then the note
;   (OCTAVE + 5TH: an octave, a fifth, the note; 2 OCTAVES: two up, one up,
;   the note); CLICK: the first 20 ms as noise.
; BEND IN: each new note starts AMOUNT semitones away (above: a drop, below:
;   a scoop) and bends to its pitch over TIME: the SID and NES slide it (the
;   SID per voice, the NES with its glide), the Game Boy has its own pitch
;   envelope (CC 80 / 81).
; BEND OUT (the SID): a note let go sags AMOUNT semitones over TIME while its
;   release rings.

; SidFxs pitch loop, SID voice envY: ATTACK's clock; the CLICK ends
AtkStep:
	subroutine
	ldy envY
	lda atkT,y
	clc
	adc fxN
	bcc .t
	lda #255
.t:
	sta atkT,y
	lda clickOn,y
	beq .x
	lda atkT,y
	cmp #5                  ; (20 ms of noise)
	bcc .x
	lda #0
	sta clickOn,y
	ldx sidOfs,y
	lda sidGate,y
	sta SID+4,x
.x:
	rts

; a SID voice's gate went on (Y = SID voice, t2 = its registers): the CLICK
; starts, the BLIP is there from the start. Keeps Y.
ClickOn:
	subroutine
	lda sndClick
	beq .b
	lda #1
	sta clickOn,y
	lda sidGate,y
	and #1
	ora #$80                ; noise
	ldx t2
	sta SID+4,x
.b:
	lda sndBlip
	beq .x
	jmp SidFreqOut
.x:
	rts

; SidFreqOut: bT3:bT2 (and mulA) up by the BLIP's step now (Y = SID voice).
; Keeps Y and the temps (t0-t3).
BlipApply:
	subroutine
	lda atkT,y
	ldx #0
.d:
	cmp sndBlipT            ; step = time / BLIP STEP
	bcc .s
	sbc sndBlipT
	inx
	cpx #2
	bcc .d
	rts                     ; (past the blip)
.s:
	txa
	sta blT
	lda sndBlip
	asl
	adc blT
	tax
	lda blipTab-2,x         ; 0 none, 1 x 2, 2 x 4, 3 x 1.5
	beq .x
	cmp #3
	beq .f
	tax
.o:
	asl bT2
	rol bT3
	bcc .on
	lda #$FF                ; (the top of the SID's range)
	sta bT2
	sta bT3
	bne .w
.on:
	dex
	bne .o
	beq .w
.f:
	lda bT3                 ; x 1.5
	lsr
	sta blT
	lda bT2
	ror
	clc
	adc bT2
	sta bT2
	lda blT
	adc bT3
	bcc .f1
	lda #$FF
	sta bT2
.f1:
	sta bT3
.w:
	lda bT2
	sta mulA
	lda bT3
	sta mulA+1
.x:
	rts

blipTab:    .byte 1,0, 1,3, 2,1     ; OCTAVE, OCTAVE + 5TH, 2 OCTAVES: steps 0 and 1

; VoiceSet, a SID voice's new note (Y = SID voice, t0 = the voice, t3 = a new
; press): BEND IN starts it away from its pitch
BendIn:
	subroutine
	lda sndPenv
	beq .x
	ldx t0
	lda legatoNow
	bne .x                  ; (legato: no new start)
	lda vNote,x
	cmp #NO_NOTE
	beq .go                 ; from silence
	lda t3
	beq .x                  ; (a glide to a new note, no new attack)
.go:
	lda vWant,x
	clc
	adc sndPenv
	jsr NoteClamp
	jsr SidPitch            ; -> ptr
	lda ptr
	sta sidBaseLo,y
	lda ptr+1
	sta sidBaseHi,y
	lda sndPenvK
	sta sK,y
.x:
	rts

; VoiceSet, a SID voice let go (X = the voice, Y = SID voice): BEND OUT
RelDrop:
	subroutine
	lda sndRdrop
	beq .x
	lda vNote,x
	cmp #NO_NOTE
	beq .x
	sec
	sbc sndRdrop
	jsr NoteClamp
	jsr SidPitch
	lda ptr
	sta sidTgtLo,y
	lda ptr+1
	sta sidTgtHi,y
	lda sndRdropK
	sta sK,y
	lda #1
	sta rdOn,y
.x:
	rts

; A = a note, kept within the SID's table (0-127; a signed overflow: 0)
NoteClamp:
	subroutine
	cmp #0
	bpl .x
	lda #0
.x:
	rts
