; Fat Chip 64 - the visualizers (F7: BARS, GLITCH, back to play), demos
;
; BARS:
; Nine bars, one per voice, in three groups: SID, Game Boy, MidiNES. A new
; note throws its bar to the top; it falls back to a height set by the
; note's pitch (higher notes stand taller) while the note sounds, and to
; nothing when it stops. The tremolo makes the bars breathe. Each bar takes
; the colour of its note's pitch class (C red ... B white). Kick drums flash
; the border in the key's colour; row 24 has the sound, the tempo and, while
; a beat plays, which beat of the bar it's on.
;
; One bar is drawn per screen step (about every 8 ms), so the screen stays
; out of the way of the keyboard and the arp: about 13 frames a second.
;
; GLITCH (v0.15): the whole screen, no text. Each new note tears a streak of
; PETSCII blocks across a row picked by its pitch, in its colour; held notes
; keep spattering more; runs of the screen get copied over other places
; (datamosh) and wiped away, so it fills while you play and dissolves when
; you stop. Kick drums shake the picture (the VIC's fine scroll) and flash
; the background. VINYL STOP drags it down the screen.

VIZ_BOTTOM  equ 21              ; bars: rows 2-21 (20 rows, 40 half rows)
VIZ_NAMES   equ 22              ; note names
VIZ_FULL    equ 160             ; reversed space
VIZ_HALF    equ 98              ; lower half block

; F7: BARS -> GLITCH -> the play screen (not from the menu)
VizKey:
	subroutine
	lda menuOn
	bne .x
	jsr GlitchCalm
	ldx vizOn
	inx
	cpx #3
	bcc .s
	ldx #0
.s:
	stx vizOn
	cpx #0
	beq .off
	jmp VizDraw
.off:
	jsr ClearScreen
	lda #13
	jsr ColourAll
	jsr VizBorderBack
	jsr ScreenStatic
	lda #0
	sta scrStage
	lda #1
	sta screenDirty
.x:
	rts

; colour RAM all A
ColourAll:
	subroutine
	ldx #0
.c:
	sta COLRAM,x
	sta COLRAM+$100,x
	sta COLRAM+$200,x
	sta COLRAM+$2E8,x
	inx
	bne .c
	rts

; the border as the mute says (red while muted)
VizBorderBack:
	subroutine
	lda #0
	sta vizBorder
	lda muteVis
	beq .b
	lda #2
.b:
	sta BORDER
	rts

; the visualizer's screen, from empty bars (or empty glitch)
VizDraw:
	subroutine
	lda vizOn
	cmp #2
	bne .bars
	jmp GlitchDraw
.bars:
	jsr ClearScreen
	lda #11
	jsr ColourAll
	lda #$80
	sta t2
	PRINT 0, 0, txtVizHdr
	lda #0
	sta t2
	PRINT 23, 5, txtSid
	PRINT 23, 15, txtGb
	PRINT 23, 28, txtNes
	ldx #NUM_VOICES-1
.v:
	lda #0
	sta vizLvl,x
	lda #$FE                ; (no note yet: the first step names it)
	sta vizNote,x
	dex
	bpl .v
	lda #0
	sta vizV
	sta vizKick
	rts

; one screen step: the next bar (after the ninth, row 24 and the border)
VizStep:
	subroutine
	lda ticks               ; one step every 8 ms at most (the main loop can
	sec                     ;  come round much quicker than that now)
	sbc vizAt
	cmp #8
	bcs .due
	rts
.due:
	lda ticks
	sta vizAt
	lda vizOn
	cmp #2
	bne .bars
	jmp GlitchStep
.bars:
	ldx vizV
	jsr VizBar
	inc vizV
	lda vizV
	cmp #NUM_VOICES
	bcc .x
	lda #0
	sta vizV
	jmp VizInfo
.x:
	rts

; voice X's bar
VizBar:
	subroutine
	stx vizStep
	; ---- a new note: the bar jumps up, and its name changes
	lda vNote,x
	cmp vizNote,x
	beq .same
	sta vizNote,x
	cmp #NO_NOTE
	beq .name
	lda #40
	sta vizLvl,x
.name:
	ldy #VIZ_NAMES
	lda vizColT,x
	tax
	stx t3
	ldx #0
	jsr ScreenAddr
	ldx vizStep
	lda vizNote,x
	ldx t3
	jsr PutNote
	ldx vizStep
.same:
	; ---- where it heads: sounding, by pitch (and the tremolo); else down
	lda #0
	ldy muteNow
	bne .tg
	ldy vDev,x
	lda devOn,y
	beq .tg                 ; (A = 0)
	lda vNote,x
	cmp #NO_NOTE
	beq .z
	lsr
	lsr                     ; MIDI 24-96 -> 6-24
	clc
	adc #6
	cmp #36
	bcc .t1
	lda #36
.t1:
	sec
	sbc tremA
	cmp #4
	bcs .tg
	lda #4
	bne .tg
.z:
	lda #0
.tg:
	sta t2                  ; target
	lda vizLvl,x
	cmp t2
	beq .draw
	bcc .rise
	sbc #2                  ; falls 2 half rows a frame (carry set)
	bcc .to
	cmp t2
	bcs .st
.to:
	lda t2
	jmp .st
.rise:
	adc #4                  ; rises 4 (carry clear)
	cmp t2
	bcc .st
	lda t2
.st:
	sta vizLvl,x
.draw:
	; ---- the column, bottom row up: full, half or empty; the note's colour
	lda vizNote,x
	cmp #NO_NOTE
	bcs .grey
.pc:
	cmp #12
	bcc .pcd
	sbc #12
	bcs .pc
.pcd:
	tay
	lda pitchCol,y
	bne .cs
.grey:
	lda #11
.cs:
	sta t3                  ; colour
	lda vizLvl,x
	sta t1                  ; half rows left to draw
	lda vizColT,x
	clc
	adc #<(SCREEN+VIZ_BOTTOM*40)
	sta ptr2
	sta ptr
	lda #>(SCREEN+VIZ_BOTTOM*40)
	adc #0
	sta ptr2+1
	clc
	adc #>(COLRAM-SCREEN)
	sta ptr+1
	ldx #20
.row:
	lda t1
	beq .e
	cmp #1
	beq .h
	dec t1
	dec t1
	lda #VIZ_FULL
	bne .put
.h:
	lda #0
	sta t1
	lda #VIZ_HALF
	bne .put
.e:
	lda #32
.put:
	ldy #0
	sta (ptr2),y
	iny
	sta (ptr2),y
	iny
	sta (ptr2),y
	lda t3
	sta (ptr),y
	dey
	sta (ptr),y
	dey
	sta (ptr),y
	lda ptr2                ; up a row
	sec
	sbc #40
	sta ptr2
	sta ptr
	bcs .up
	dec ptr2+1
	dec ptr+1
.up:
	dex
	bne .row
	rts

; row 24: sound, tempo, the beat of the bar; the kick's border flash
VizInfo:
	subroutine
	lda vizKick
	beq .nk
	lda #0
	sta vizKick
	lda #1
	sta vizBorder
	ldy keyRoot
	lda pitchCol,y
	sta BORDER
	jmp .info
.nk:
	lda vizBorder
	beq .info
	jsr VizBorderBack
.info:
	lda #0
	sta t2
	ldx soundMode
	lda sndNameLo,x
	sta ptr
	lda sndNameHi,x
	sta ptr+1
	ldx #1
	ldy #24
	jsr PrintAt
	ldy #24
	ldx #0
	jsr ScreenAddr
	ldx #19
	lda #32
	jsr PutChar
	inx
	jsr PutChar
	inx
	jsr PutChar
	lda bpm
	sta t0
	lda #0
	sta t1
	ldx #19
	jsr PutDecZ
	PRINT 24, 23, txtVizBpm
	; beats of the bar: the one playing lit (stopped: none)
	ldy #24
	ldx #0
	jsr ScreenAddr
	ldx beatSel
	lda beatLen,x
	sta dvdL
	lda #0
	sta dvdH
	sta dvsH
	lda beatSpb,x
	sta dvsL
	jsr Div16               ; beats in the pattern
	lda beatStep
	sta t0
	ldx beatSel
	lda beatSpb,x
	sta t1
	ldx #0                  ; the beat playing = step / steps per beat
.b:
	lda t0
	cmp t1
	bcc .bn
	sbc t1
	sta t0
	inx
	bne .b
.bn:
	stx t1
	ldx #0
	ldy #31
.c:
	lda #32
	cpx dvdL
	bcs .p
	lda #46                 ; .
	cpx t1
	bne .p
	lda beatRun
	beq .p0
	lda #81                 ; (a ball)
	bne .p
.p0:
	lda #46
.p:
	sta (ptr2),y
	iny
	inx
	cpx #8
	bne .c
	rts

; voice -> its bar's column (three groups: SID, Game Boy, MidiNES)
vizColT:    .byte 1,14,27, 5,18,31, 9,22,35
; pitch class -> colour: C red, C# orange, D yellow, D# light green,
; E green, F cyan, F# light blue, G blue, G# purple, A light red,
; A# light grey, B white
pitchCol:   .byte 2,8,7,13,5,3,14,6,4,10,15,1
txtVizHdr:  .byte " FAT CHIP 64 VISUALIZER         F7: BACK",0
txtVizBpm:  .byte "BPM",0

; ================================================================ GLITCH
GlitchDraw:
	subroutine
	jsr ClearScreen
	ldx #NUM_VOICES-1
.v:
	lda #$FE
	sta vizNote,x
	dex
	bpl .v
	lda #0
	sta vizV
	sta vizKick
	sta gShake
	lda gR
	ora gR+1
	bne .x
	lda #$E1                ; (the random numbers' seed)
	sta gR
	lda #$AC
	sta gR+1
.x:
	rts

; the picture still, the background black (leaving GLITCH, opening the menu)
GlitchCalm:
	subroutine
	lda #0
	sta gShake
	sta BGCOL
	lda $D016
	and #$F8
	sta $D016
	lda VIC_CTRL1
	and #$F8
	ora #3
	sta VIC_CTRL1
	rts

; A = a random byte (16-bit Galois LFSR)
GRnd:
	lda gR
	asl
	rol gR+1
	bcc .n
	eor #$2D
.n:
	sta gR
	eor gR+1
	rts

; one screen step
GlitchStep:
	subroutine
	; ---- three voices a step (round the nine): a new note tears, a held
	; one spatters
	lda #3
	sta gV
.voice:
	ldx vizV
	inx
	cpx #NUM_VOICES
	bcc .vv
	ldx #0
.vv:
	stx vizV
	lda vNote,x
	cmp vizNote,x
	beq .held
	sta vizNote,x
	cmp #NO_NOTE
	beq .nv
	jsr GTear
	jmp .nv
.held:
	cmp #NO_NOTE
	beq .nv
	lda muteNow
	bne .nv
	ldy vDev,x
	lda devOn,y
	beq .nv
	jsr GSpatter
.nv:
	dec gV
	bne .voice
	; ---- datamosh: a run copied somewhere else
	jsr GMosh
	; ---- wiped away: a run of blank, 3-10 (VINYL STOP: things fall)
	jsr GRnd
	and #7
	clc
	adc #3
	sta gLen
	lda #32
	sta gChr
	jsr GSpot
	jsr GRun
	ldx #NUM_VOICES-1       ; nothing sounding: it clears faster
.q:
	lda vNote,x
	cmp #NO_NOTE
	bne .snd
	dex
	bpl .q
	lda #16
	sta gLen
	jsr GSpot
	jsr GRun
.snd:
	lda vinylLvl
	beq .kick
	jsr GDrip
	; ---- kick: shake and flash
.kick:
	lda vizKick
	beq .sh
	lda #0
	sta vizKick
	lda #5
	sta gShake
	ldy keyRoot
	lda pitchCol,y
	sta BGCOL
.sh:
	lda gShake
	beq .x
	dec gShake
	bne .jit
	jmp GlitchCalm
.jit:
	cmp #4
	bne .j
	lda #0                  ; (the flash is short)
	sta BGCOL
.j:
	jsr GRnd
	and #7
	sta gK
	lda $D016
	and #$F8
	ora gK
	sta $D016
	jsr GRnd
	and #7
	sta gK
	lda VIC_CTRL1
	and #$F8
	ora gK
	sta VIC_CTRL1
.x:
	rts

; voice X's new note: a streak across a row its pitch picks, 6-29 long
GTear:
	subroutine
	jsr GNoteLook           ; gChr, gCol from the note
	jsr GRnd
	and #15
	clc
	adc #6
	sta gLen
	jsr GRnd
	and #7
	adc #4                  ; (carry clear)
	cmp gLen
	bcs .l
	adc gLen
	sta gLen
.l:
	ldx vizV
	lda vizNote,x           ; row: the pitch (low notes low down) + a jolt
	eor #$7F
	lsr
	lsr
	sta gK
	jsr GRnd
	and #3
	clc
	adc gK
.m:
	cmp #25
	bcc .r
	sbc #25
	bcs .m
.r:
	tay
	jsr GRnd
	and #63
	cmp #40
	bcc .c
	sbc #40
.c:
	tax
	jmp GRun

; voice X sounding: a few cells spattered round its row
GSpatter:
	subroutine
	jsr GNoteLook
	jsr GRnd
	and #3
	clc
	adc #1
	sta gLen
	jsr GSpot
	jmp GRun

; gChr = a glitch character, gCol = the colour of voice vizV's note
GNoteLook:
	subroutine
	ldx vizV
	lda vizNote,x
.pc:
	cmp #12
	bcc .p
	sbc #12
	bcs .pc
.p:
	tay
	lda pitchCol,y
	sta gCol
	jsr GRnd
	and #15
	tay
	lda gChars,y
	sta gChr
	rts

; Y = a random row, X = a random column
GSpot:
	subroutine
	jsr GRnd
	and #31
	cmp #25
	bcc .r
	sbc #7
.r:
	tay
	jsr GRnd
	and #63
	cmp #40
	bcc .c
	sbc #40
.c:
	tax
	rts

; gLen cells of gChr in gCol from row Y, column X (on row 24 not past its
; end; others run on into the next row)
GRun:
	subroutine
	cpy #24
	bne .a
	txa
	clc
	adc gLen
	cmp #41
	bcc .a
	lda #40
	stx gK
	sec
	sbc gK
	sta gLen
.a:
	jsr ScreenAddr          ; ptr2 (Y = 0)
	lda ptr2
	sta ptr
	lda ptr2+1
	clc
	adc #>(COLRAM-SCREEN)
	sta ptr+1
	ldy gLen
	dey
.p:
	lda gChr
	sta (ptr2),y
	lda gCol
	sta (ptr),y
	dey
	bpl .p
	rts

; datamosh: 8-15 cells (and their colours) copied from one place to another
GMosh:
	subroutine
	jsr GRnd
	and #7
	clc
	adc #8
	sta gLen
	jsr GSpot
	cpy #24
	bne .s
	dey                     ; (keep runs inside the screen)
.s:
	jsr ScreenAddr
	lda ptr2
	sta gSrc
	lda ptr2+1
	sta gSrc+1
	jsr GSpot
	cpy #24
	bne .d
	dey
.d:
	jsr ScreenAddr
	lda ptr2
	sta ptr
	lda ptr2+1
	sta ptr+1
	ldy gLen
	dey
.c:
	lda (gSrc),y
	sta (ptr),y
	dey
	bpl .c
	; their colours
	lda gSrc+1
	clc
	adc #>(COLRAM-SCREEN)
	sta gSrc+1
	lda ptr+1
	clc
	adc #>(COLRAM-SCREEN)
	sta ptr+1
	ldy gLen
	dey
.cc:
	lda (gSrc),y
	sta (ptr),y
	dey
	bpl .cc
	rts

; VINYL STOP: a column slides down a row (more of them as it slows)
GDrip:
	subroutine
	lda vinylLvl
	asl                     ; 0-1
	rol
	and #1
	sta gK
	inc gK
.k:
	jsr GRnd
	and #63
	cmp #40
	bcc .c
	sbc #40
.c:
	clc
	adc #<(SCREEN+23*40)
	sta ptr
	lda #>(SCREEN+23*40)
	adc #0
	sta ptr+1
	ldx #23
.r:
	ldy #0
	lda (ptr),y
	ldy #40
	sta (ptr),y
	lda ptr
	sec
	sbc #40
	sta ptr
	bcs .u
	dec ptr+1
.u:
	dex
	bpl .r
	ldy #40                 ; the top cell empties
	lda #32
	sta (ptr),y
	dec gK
	bne .k
	rts

; the glitch characters: blocks, halves, checks, lines, diagonals
gChars:     .byte 160,102,230,98,226,97,225,127,255,95,223,105,233,99,119,81

