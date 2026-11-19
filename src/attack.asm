; Fat Chip 64 - BEND IN, BEND OUT (v0.30; v0.41: ATTACK folded into BEND IN):
; how each note starts and ends in pitch
;
; BEND IN: each new note starts AMOUNT semitones away (above: a drop, below:
;   a scoop) and comes to its pitch over TIME. SLIDE: the SID and NES slide
;   it (the SID per voice, the NES with its glide), the Game Boy has its own
;   pitch envelope (CC 80 / 81). STEP: the SID and NES hold it there for TIME,
;   then jump (the chip-tune BLIP); the Game Boy slides as fast as it can.
;   CLICK (the SID): the first 20 ms of each note as noise.
; BEND OUT (the SID): a note let go sags AMOUNT semitones over TIME while its
;   release rings.

; SidFxs pitch loop, SID voice envY: the note's clock; the CLICK ends; a STEP
; jumps to the note
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
	beq .s
	lda atkT,y
	cmp #5                  ; (20 ms of noise)
	bcc .s
	lda #0
	sta clickOn,y
	ldx sidOfs,y
	lda sidGate,y
	sta SID+4,x
.s:
	lda sK,y
	cmp #$FF                ; (STEP: held)
	bne .x
	lda atkT,y
	cmp sndStepT
	bcc .x
	lda sidTgtLo,y          ; TIME's up: the note
	sta sidBaseLo,y
	lda sidTgtHi,y
	sta sidBaseHi,y
	lda #0
	sta sK,y
.x:
	rts

; a SID voice's gate went on (Y = SID voice, t2 = its registers): the CLICK
; starts. Keeps Y.
ClickOn:
	subroutine
	lda sndClick
	beq .x
	lda #1
	sta clickOn,y
	lda sidGate,y
	and #1
	ora #$80                ; noise
	ldx t2
	sta SID+4,x
.x:
	rts

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
	ldx sndStep
	beq .k
	lda #$FF                ; (STEP: held; AtkStep jumps)
.k:
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
