; Fat Chip 64 - the visualizer (F7: GLITCH on / off; v0.28 dropped the BARS)
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

; F7: GLITCH on / off (not from the menu)
VizKey:
	subroutine
	lda menuOn
	bne .x
	jsr GlitchCalm
	ldx #2                  ; GLITCH on / off
	lda vizOn
	beq .s
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

; the visualizer's screen (v0.28: GLITCH only; the BARS are gone)
VizDraw:
	jmp GlitchDraw

; one screen step, every 8 ms at most (the main loop can come round much
; quicker than that)
VizStep:
	subroutine
	lda ticks
	sec
	sbc vizAt
	cmp #8
	bcs .due
	rts
.due:
	lda ticks
	sta vizAt
	jmp GlitchStep

pitchCol:   .byte 2,8,7,13,5,3,14,6,4,10,15,1   ; C red ... B white

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

