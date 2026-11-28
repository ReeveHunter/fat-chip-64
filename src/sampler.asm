; Fat Chip 64 - SAMPLER MODE, stage 1 (v0.68): 16 pads and the sample browser
;
; RUN/STOP + RETURN switches between the play screen and the sampler. Its
; 16 pads are 1234 / QWER / ASDF / ZXCV (PAD KEYS GRID) or the overlay's
; lowest 16 notes, Z's pad on Q (C3) and on up ZXCV ASDF QWER 1234 (OVERLAY).
; A pad plays its MidiNES sample at its rate, and on the Game Boy the drum its
; hit type matches, as the beats would (BEATS ON, BOTH LAYER / SPLIT); tonal,
; FX and vocal samples play on the MidiNES only. SHIFT + a pad: accented.
; Notes on PAD MIDI CHANNEL from PAD BASE NOTE up play the pads too (any
; screen), with their velocity on the Game Boy.
;
; The browser (the MidiNES's 256 samples, A0-A127, B0-B127):
;   CRSR DOWN (SHIFT: back)   the next sample of the TYPE, played
;   C= + CRSR DOWN            TYPE: ALL, K, S, H, P, L, T, F, V
;   CRSR RIGHT (SHIFT: down)  its rate, 0-15 (MidiNES CC 3 = rate x 8 + 7)
;   SPACE                     play it again
;   RETURN, then a pad        the pad gets it at that rate; RETURN, then SPACE:
;                             all 16, the rates low to high up the pads
;   C= + F1 / F3              pad kit 2 / 1 (two, kept until reset)
;   C= + RETURN               the menu (its SAMPLER page has the settings)
; Kit 1 starts as the beat's MidiNES kit on the standard pads (Z kick, X snare,
; C V hats, A S accents, D F R toms, E perc), the first time the sampler opens.

SMP_ACCENT  equ 127             ; the Game Boy's velocity: SHIFT + a pad, else
SMP_NORMAL  equ 100
SMP_LIT_MS  equ 90              ; a pad lights this long

; ---- RUN/STOP + RETURN
SmpToggle:
	subroutine
	lda smpOn
	eor #1
	sta smpOn
	jsr SmpKeysUsed
	lda smpOn
	beq .off
	lda smpInit             ; the first time: kit 1 from the beat's kit
	bne .on
	inc smpInit
	jsr SmpKit1
.on:
	lda #$FF
	sta padLitP
	lda #0
	sta smpArm
.off:
	lda #1                  ; (the Game Boy's wave channel: the drums' or not)
	sta reallocFlag
	jsr ClearScreen
	jsr ColourReset
	jsr ScreenStatic        ; (the sampler's, or the play screen's)
	lda #0
	sta scrStage
	lda #1
	sta screenDirty
	rts

; 1 and 4 are keys only for the sampler's GRID pads (the phantom-key filter
; leaves unused keys out: Q 2 E plays all three with 4 unused)
SmpKeysUsed:
	subroutine
	lda keyUsed+7           ; 1: column 7, row 0
	and #$FE
	sta keyUsed+7
	lda keyUsed+1           ; 4: column 1, row 3
	and #$F7
	sta keyUsed+1
	lda smpOn
	beq .x
	lda padKeys
	bne .x
	lda keyUsed+7
	ora #$01
	sta keyUsed+7
	lda keyUsed+1
	ora #$08
	sta keyUsed+1
.x:
	rts

; kit 1: the beat's samples (kitBuf: kick, snare, toms, perc at 3 levels)
SmpKit1:
	subroutine
	ldx #15
.c:
	ldy smpK1Src,x
	lda #$FF
	cpy #$FF
	beq .e
	lda kitBuf,y
	cpy #$80
	bcc .e
	tya                     ; ($80 +: a fixed sample, the hats)
	and #$7F
.e:
	sta t0
	txa
	asl
	tay
	lda t0
	sta padKit,y
	lda #15
	sta padKit+1,y
	dex
	bpl .c
	rts
; pad 0-15 (1 2 3 4 Q W E R A S D F Z X C V): kitBuf index, $80 + a sample, $FF none
smpK1Src:   .byte $FF,$FF,$FF,$FF, $FF,$FF,10,8, 2,5,6,7, 1,4,$80+12,$80+27

; ---- the keys in the sampler (KeyDown / KeyUp first ask here)
; A = key code -> C set: taken (A kept when not). A key taken is noted, so
; only its own release is (RUN/STOP + SPACE's FILL still ends, for one)
SmpKey:
	subroutine
	jsr SmpKeyIn
	bcc .x
	lda smpCode
	jsr SmpBit
	ora smpTaken,x
	sta smpTaken,x
	sec
.x:
	rts

; A = key code -> X = its byte in smpTaken, A = its bit
SmpBit:
	subroutine
	cmp #$80
	bcc .n
	sbc #$80-24
.n:
	pha
	lsr
	lsr
	lsr
	tax
	pla
	and #7
	tay
	lda bitT,y
	rts

SmpKeyIn:
	subroutine
	sta smpCode
	ldx ctrlDown
	bne .no
	ldx stopDown
	bne .no
	ldx cbmDown
	beq .plain
	cmp #K_CRSR_DOWN        ; C= + CRSR DOWN: the next TYPE
	bne .cr
	jmp SmpType
.cr:
	cmp #K_RETURN
	bne .cf
	jsr MenuOpen
	sec
	rts
.cf:
	ldx #1
	cmp #K_F1               ; C= + F1 / F3: kit 2 / 1
	beq .kit
	dex
	cmp #K_F3
	bne .no
.kit:
	stx smpKit
	lda #1
	sta screenDirty
	sec
	rts
.no:
	lda smpCode
	clc
	rts
.plain:
	jsr SmpPadOf            ; a pad?
	bcc .np
	ldy #SMP_NORMAL
	lda shiftDown
	beq .v
	ldy #SMP_ACCENT
.v:
	tya
	jmp PadPress
.np:
	lda smpCode
	cmp #24                 ; (the overlay's other notes: nothing)
	bcc .took
	cmp #K_CRSR_DOWN
	bne .n1
	jmp SmpStep1
.n1:
	cmp #K_CRSR_RIGHT
	bne .n2
	jmp SmpRate
.n2:
	cmp #K_SPACE
	bne .n3
	jmp SmpSpace
.n3:
	cmp #K_RETURN
	bne .no
	lda shiftDown
	bne .no
	lda smpArm              ; RETURN: arm (again: never mind)
	eor #1
	sta smpArm
	lda #1
	sta screenDirty
.took:
	sec
	rts

; a key let go (any screen): C set if the sampler took its press
SmpKeyUp:
	subroutine
	sta smpCode
	jsr SmpBit
	sta smpTmp
	and smpTaken,x
	beq .no
	lda smpTmp
	eor #$FF
	and smpTaken,x
	sta smpTaken,x
	sec
	rts
.no:
	lda smpCode
	clc
	rts

; smpCode -> C set and X = its pad (PAD KEYS)
SmpPadOf:
	subroutine
	lda smpCode
	ldx padKeys
	bne .ov
	ldx #15
.g:
	cmp smpGrid,x
	beq .y
	dex
	bpl .g
	clc
	rts
.ov:
	cmp #16
	bcs .n
	tax
	lda smpOvPad,x
	tax
.y:
	sec
	rts
.n:
	clc
	rts
; GRID: pad 0-15's key; OVERLAY: overlay note 0-15 -> its pad
smpGrid:    .byte K_1,1,3,K_4, 0,2,4,5, K_A,K_S,K_D,K_F, K_Z,K_X,K_C,K_V
smpOvPad:   .byte 12,13,14,15, 8,9,10,11, 4,5,6,7, 0,1,2,3

; CRSR DOWN: the next sample of the TYPE (SHIFT: the one before)
SmpStep1:
	subroutine
	ldy #0                  ; (at most all 256)
.n:
	lda shiftDown
	bne .b
	inc smpSel
	jmp .t
.b:
	dec smpSel
.t:
	lda smpFilt
	beq .play
	ldx smpSel
	jsr SmpTypeOf
	lsr
	lsr
	lsr
	lsr
	clc
	adc #1
	cmp smpFilt
	beq .play
	dey
	bne .n
.play:
	jmp SmpHear

; C= + CRSR DOWN: TYPE ALL -> K -> ... -> V -> ALL, on its first sample
SmpType:
	subroutine
	ldx smpFilt
	inx
	cpx #9
	bcc .s
	ldx #0
.s:
	stx smpFilt
	txa
	beq .h
	lda #$FF                ; from the top: its first
	sta smpSel
	lda shiftDown
	pha
	lda #0
	sta shiftDown
	jsr SmpStep1
	pla
	sta shiftDown
	sec
	rts
.h:
	jmp SmpHear

; CRSR RIGHT: the rate up (SHIFT: down)
SmpRate:
	subroutine
	ldx smpRate
	lda shiftDown
	bne .d
	cpx #15
	bcs SmpHear
	inx
	bne .s
.d:
	txa
	beq SmpHear
	dex
.s:
	stx smpRate
	; (falls through)

; the browser's sample on the MidiNES, the screen redrawn. C set (taken)
SmpHear:
	lda #1
	sta screenDirty
	lda smpSel
	sta t1
	lda smpRate
	jsr RateCC
	jsr DmcPlay
	sec
	rts

; SPACE: play it again, or (RETURN armed) on every pad, the rates spread
SmpSpace:
	subroutine
	lda smpArm
	beq SmpHear
	lda #0
	sta smpArm
	ldx #15
.p:
	ldy smpSpread,x         ; the pad at step x, low to high
	tya
	jsr KitSlot
	lda smpSel
	sta padKit,y
	txa
	sta padKit+1,y
	dex
	bpl .p
	jmp SmpHear
smpSpread:  .byte 12,13,14,15, 8,9,10,11, 4,5,6,7, 0,1,2,3

; A = pad -> Y = its two bytes in the kit (sample, rate). Keeps X.
KitSlot:
	asl
	ldy smpKit
	beq .k
	ora #32
.k:
	tay
	rts

; A = rate 0-15 -> MidiNES CC 3
RateCC:
	asl
	asl
	asl
	ora #7
	rts

; ---- a pad: X = pad, A = the Game Boy's velocity (a key, MIDI in)
PadPress:
	subroutine
	sta padVel
	stx padNow
	lda smpArm              ; RETURN armed: the pad gets the browser's sample
	beq .play
	lda #0
	sta smpArm
	txa
	jsr KitSlot
	lda smpSel
	sta padKit,y
	lda smpRate
	sta padKit+1,y
	lda #1
	sta screenDirty
	ldx padNow
.play:
	txa
	jsr KitSlot
	lda padKit,y
	cmp #$FF
	beq .x
	sta t1
	lda padKit+1,y
	jsr RateCC
	sta padCC
	jsr PadLight
	; the Game Boy: its drum for the hit type, when the beats would use it
	ldx t1
	jsr SmpTypeOf
	and #$0F
	sta padLane             ; lane + 1, 0: none
	beq .nes
	jsr GbBeats
	beq .nes
	ldy padLane
	lda gbDrumNote-1,y
	sta mD1
	lda padVel
	sta mD2
	lda gbBase
	clc
	adc #4
	and #15
	ora #$90
	sta mS
	jsr GbPut
	lda beatDev             ; GAME BOY only: not on the MidiNES
	cmp #1
	beq .x
	cmp #2
	bne .nes
	lda beatSplit           ; BOTH, SPLIT: the hats side is the Game Boy's
	beq .nes
	lda padLane
	cmp #8
	bcs .x
.nes:
	lda padCC
	jsr DmcPlay
.x:
	sec
	rts

; light pad padNow (its first line white) until SMP_LIT_MS later
PadLight:
	subroutine
	lda smpOn
	beq .x
	jsr PadUnlit
	lda padNow
	sta padLitP
	lda ticks
	sta padLitT
	lda #1
	jsr PadColour
.x:
	rts
PadUnlit:
	subroutine
	lda padLitP
	bmi .x
	lda #13
	jsr PadColour
	lda #$FF
	sta padLitP
.x:
	rts
; A = colour for pad padLitP's first line
PadColour:
	subroutine
	pha
	lda padLitP
	jsr PadRowCol           ; -> Y row, X column
	jsr ScreenAddr
	lda ptr2+1
	clc
	adc #>(COLRAM-SCREEN)
	sta ptr2+1
	pla
	ldy #8
.c:
	sta (ptr2),y
	dey
	bpl .c
	rts

; A = pad -> Y = its screen row, X = its column
PadRowCol:
	subroutine
	pha
	lsr
	lsr
	tax
	lda smpRowT,x
	tay
	pla
	and #3
	tax
	lda smpColT,x
	tax
	rts
smpRowT:    .byte 2,5,8,11
smpColT:    .byte 0,10,20,30

; main loop: a lit pad goes out
SmpTick:
	subroutine
	lda padLitP
	bmi .x
	lda ticks
	sec
	sbc padLitT
	cmp #SMP_LIT_MS
	bcc .x
	jmp PadUnlit
.x:
	rts

; X = sample -> A = its smpType byte (under the I/O)
SmpTypeOf:
	php
	sei
	lda #$34
	sta $01
	lda smpType,x
	sta smpTmp
	lda #$35
	sta $01
	plp
	lda smpTmp
	rts

; MIDI in, note-on on PAD MIDI CHANNEL (rxD1, velocity rxD2)
PadMidi:
	subroutine
	lda rxD1
	sec
	sbc padBase
	cmp #16
	bcs .x
	tax
	lda rxD2
	jmp PadPress
.x:
	rts

; ---- the screen
SmpStatic:
	subroutine
	jsr SmpKeysUsed         ; (PAD KEYS may have changed in the menu)
	lda #$80
	sta t2
	PRINT 0, 0, txtSmpHdr
	lda #0
	sta t2
	PRINT 18, 0, txtSmpH1
	PRINT 19, 0, txtSmpH2
	PRINT 20, 0, txtSmpH3
	PRINT 21, 0, txtSmpH4
	PRINT 22, 0, txtSmpH5
	rts

; the pads, the kit and the browser (screenDirty), a pad row a step
SmpScreen:
	subroutine
	lda scrStage
	bne .run
	lda screenDirty
	beq .x
	lda #0
	sta screenDirty
	lda #1
	sta scrStage
.run:
	cmp #5
	bcs .br
	sec
	sbc #1
	asl
	asl                     ; the row's first pad
	sta smpI
	lda #4
	sta smpN
.p:
	jsr SmpPad
	inc smpI
	dec smpN
	bne .p
	inc scrStage
	rts
.br:
	jsr SmpBrowse
	lda #0
	sta scrStage
.x:
	rts

; pad smpI's two lines: "Z A036 K" / "  RATE 15"
SmpPad:
	subroutine
	lda smpI
	jsr PadRowCol
	stx smpX
	sty smpY
	jsr ClrCell
	ldy smpY
	iny
	jsr ClrCell
	ldy smpY
	ldx #0
	jsr ScreenAddr
	ldx smpX
	lda smpI                ; its key
	ldy padKeys
	beq .g
	ora #16
.g:
	tay
	lda smpKeyCh,y
	jsr PutChar
	inx
	inx
	lda smpI
	jsr KitSlot
	lda padKit,y
	cmp #$FF
	bne .s
	lda #'-
	jsr PutChar
	inx
	jmp PutChar
.s:
	pha
	lda padKit+1,y
	sta smpR
	pla
	jsr SmpName             ; "A036 K"
	ldy smpY
	iny
	ldx #0
	jsr ScreenAddr
	ldx smpX
	inx
	inx
	lda #<txtRate
	ldy #>txtRate
	jsr PutStr
	lda smpR
	jmp PutNum
; GRID's keys, then OVERLAY's (the overlay key each pad sits on)
smpKeyCh:   .byte "1234QWERASDFZXCV"
	.byte "I9O0EY7U6RT5Q2W3"

; Y = row: its 9 cells from column smpX blank
ClrCell:
	subroutine
	ldx smpX
	jsr ScreenAddr
	ldy #8
	lda #32
.c:
	sta (ptr2),y
	dey
	bpl .c
	rts

; A = sample at column X of row ptr2: "A036 K". Returns X past it.
SmpName:
	subroutine
	sta smpS
	lda #'A
	bit smpS
	bpl .a
	lda #'B
.a:
	jsr PutChar
	inx
	lda smpS
	and #$7F
	ldy #0                  ; hundreds
	cmp #100
	bcc .h
	sbc #100
	iny
.h:
	pha
	tya
	ora #'0
	jsr PutChar
	inx
	pla
	ldy #0
.t:
	cmp #10
	bcc .u
	sbc #10
	iny
	bne .t
.u:
	pha
	tya
	ora #'0
	jsr PutChar
	inx
	pla
	ora #'0
	jsr PutChar
	inx
	inx
	stx smpX2
	ldx smpS
	jsr SmpTypeOf
	lsr
	lsr
	lsr
	lsr
	tay
	lda smpLetters,y
	ldx smpX2
	jsr PutChar
	inx
	rts
smpLetters: .byte "KSHPLTFV"

; A/Y = string at column X of row ptr2. Returns X past it.
PutStr:
	subroutine
	sta ptr
	sty ptr+1
	ldy #0
.c:
	sty smpN2
	lda (ptr),y
	beq .x
	jsr PutChar
	inx
	ldy smpN2
	iny
	bne .c
.x:
	rts

; row 14: the kit, the browser; row 16: what RETURN is waiting for
SmpBrowse:
	subroutine
	ldy #14
	ldx #0
	jsr ScreenAddr
	ldy #39
	lda #32
.c:
	sta (ptr2),y
	dey
	bpl .c
	ldx #0
	lda #<txtKit
	ldy #>txtKit
	jsr PutStr
	lda smpKit
	clc
	adc #1
	jsr PutNum
	ldx #8
	lda #<txtBrowse
	ldy #>txtBrowse
	jsr PutStr
	lda smpSel
	jsr SmpName
	inx
	lda #<txtRate
	ldy #>txtRate
	jsr PutStr
	lda smpRate
	jsr PutNum
	inx
	inx
	lda #<txtType
	ldy #>txtType
	jsr PutStr
	ldy smpFilt
	bne .l
	lda #<txtAll
	ldy #>txtAll
	jsr PutStr
	jmp .r
.l:
	lda smpLetters-1,y
	jsr PutChar
.r:
	lda #0
	sta t2
	lda smpArm
	bne .arm
	PRINT 16, 0, txtSmpIdle
	rts
.arm:
	lda #$80
	sta t2
	PRINT 16, 0, txtSmpArm
	lda #0
	sta t2
	rts

txtSmpHdr:  .byte " FAT CHIP SAMPLER       STOP+RETURN: OUT",0
txtSmpH1:   .byte "CRSR DOWN: NEXT  C= CRSR: TYPE",0
txtSmpH2:   .byte "CRSR RIGHT: RATE (SHIFT: BACK)",0
txtSmpH3:   .byte "SPACE: PLAY IT   SHIFT + PAD: ACCENT",0
txtSmpH4:   .byte "RETURN: PUT IT ON A PAD",0
txtSmpH5:   .byte "C= F1 / F3: KIT 2 / 1   C= RETURN: MENU",0
txtSmpIdle: .byte "                                        ",0
txtSmpArm:  .byte " PRESS A PAD (SPACE: ALL 16 PADS)       ",0
txtKit:     .byte "KIT ",0
txtBrowse:  .byte "SAMPLE ",0
txtRate:    .byte "RATE ",0
txtType:    .byte "TYPE ",0
txtAll:     .byte "ALL",0
