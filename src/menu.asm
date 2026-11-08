; Fat Chip 64 - the menu (v0.13): SHIFT+RETURN in and out
;
; CRSR DOWN / SHIFT+CRSR DOWN (up): choose a setting. CRSR RIGHT or RETURN /
; SHIFT+CRSR RIGHT: its next / previous value. Every other key works as
; usual (notes play; V, F keys, = ... too: the values here follow).
; The play screen pauses while the menu is up and redraws when it closes.

MENU_ITEMS  equ 17
MENU_VALCOL equ 23


MenuOpen:
	subroutine
	lda #1
	sta menuOn
	jsr ClearScreen
	lda #$80
	sta t2
	PRINT 0, 0, mTitle
	lda #0
	sta t2
	PRINT 1, 0, mHdrSound
	PRINT 7, 0, mHdrPlay
	PRINT 11, 0, mHdrSync
	PRINT 22, 0, mHelp1
	PRINT 23, 0, mHelp2
	PRINT 24, 0, mHelp3
	ldx #0
.i:
	stx exK
	ldy menuRowY,x
	lda menuLblLo,x
	sta ptr
	lda menuLblHi,x
	sta ptr+1
	ldx #2
	jsr PrintAt
	ldx exK
	inx
	cpx #MENU_ITEMS
	bne .i
	jmp MenuVals

MenuClose:
	lda #0
	sta menuOn
	jsr ClearScreen
	jsr ScreenStatic
	lda #0
	sta scrStage
	lda #1
	sta screenDirty
	rts

; screen memory blank (leaves the VIC alone: RESTORE may have it off)
ClearScreen:
	subroutine
	lda #32
	ldx #0
.c:
	sta SCREEN,x
	sta SCREEN+$100,x
	sta SCREEN+$200,x
	sta SCREEN+$2E8,x
	inx
	bne .c
	rts

; every value and the cursor
MenuVals:
	subroutine
	ldx #0
.i:
	stx exK
	jsr MenuVal
	ldx exK
	inx
	cpx #MENU_ITEMS
	bne .i
	rts

; item X: cursor and value
MenuVal:
	subroutine
	stx exK
	ldy menuRowY,x
	lda #32
	cpx menuRow
	bne .c
	lda #62                 ; >
.c:
	pha
	ldx #0
	jsr ScreenAddr
	pla
	ldy #0
	sta (ptr2),y
	ldx exK
	lda menuVarLo,x
	sta ptr
	lda menuVarHi,x
	sta ptr+1
	ldy #0
	lda (ptr),y             ; the value
	asl
	tay
	lda menuValLo,x
	sta ptr
	lda menuValHi,x
	sta ptr+1
	lda (ptr),y
	pha
	iny
	lda (ptr),y
	sta ptr+1
	pla
	sta ptr
	ldy menuRowY,x
	ldx #MENU_VALCOL
	lda #$80                ; (reversed)
	sta t2
	jsr PrintAt
	lda #0
	sta t2
	rts

; A = key code (commands only: notes never come here)
MenuKey:
	subroutine
	cmp #K_CRSR_DOWN
	bne .r
	ldx menuRow
	lda shiftDown
	bne .upr
	inx
	cpx #MENU_ITEMS
	bcc .mv
	ldx #0
	beq .mv
.upr:
	dex
	bpl .mv
	ldx #MENU_ITEMS-1
.mv:
	lda menuRow
	stx menuRow
	tax
	jsr MenuVal             ; old row: cursor off
	ldx menuRow
	jmp MenuVal
.r:
	cmp #K_CRSR_RIGHT
	bne .ret
	lda shiftDown
	bne .prev
	beq .next
.ret:
	cmp #K_RETURN
	bne .other
	lda shiftDown
	beq .next
	jmp MenuClose
.other:
	jsr KeyCmdPlay          ; the key's usual job
	jmp MenuVals            ; (it may have changed a value shown here)
.next:
	jsr .ptr
	lda (ptr),y
	clc
	adc #1
	cmp menuCount,x
	bcc .set
	lda #0
	beq .set
.prev:
	jsr .ptr
	lda (ptr),y
	sec
	sbc #1
	bcs .set
	lda menuCount,x
	sbc #0                  ; (carry clear: count - 1)
.set:
	sta (ptr),y
	lda menuHookHi,x
	beq .drawn
	sta ptr+1
	lda menuHookLo,x
	sta ptr
	jsr .call
.drawn:
	jmp MenuVals
.call:
	jmp (ptr)
.ptr:
	ldx menuRow
	lda menuVarLo,x
	sta ptr
	lda menuVarHi,x
	sta ptr+1
	ldy #0
	rts

; ---- what a change does
LatchStyleHook:
	subroutine
	lda latch
	beq .x
	ldx latchStyle
	inx
	stx latch
.x:
	rts

SpaceHook:
	ldx spaceAct
	jmp SpaceSet

TempoHook:
	subroutine
	lda syncTempo
	cmp #TEMPO_SC
	bne .x
	jmp TempoChosen         ; Synthcart: snap the tempo now
.x:
	rts

WheelHook:
	lda #0
	sta wheelMag
	sta wheelUp
	rts

mTitle:     .byte " FAT CHIP 64 MENU    SHIFT+RETURN: BACK ",0
mHdrSound:  .byte "SOUND",0
mHdrPlay:   .byte "PLAYING",0
mHdrSync:   .byte "DEVICE SYNC: KEYTAR (MIDI IN), SYNTHCART",0
mHelp1:     .byte "CRSR DOWN / SHIFT+CRSR DOWN: CHOOSE",0
mHelp2:     .byte "CRSR RIGHT OR RETURN: NEXT VALUE",0
mHelp3:     .byte "SHIFT+CRSR RIGHT: PREVIOUS VALUE",0
menuRowY:   .byte 2,3,4,5,6, 8,9,10, 12,13,14,15,16,17,18,19,20
menuCount:  .byte 3,3,14,8,6, 3,NUM_ACTS,12, 3,2,2,2,2,2,NUM_ACTS,NUM_ACTS,NUM_ACTS
menuLblLo:  .byte <mL0,<mLP,<mLT,<mLN,<mLV,<mL1,<mL2,<mLR,<mL3,<mL4,<mL5,<mL6,<mL7,<mL8,<mL9,<mL10,<mL11
menuLblHi:  .byte >mL0,>mLP,>mLT,>mLN,>mLV,>mL1,>mL2,>mLR,>mL3,>mL4,>mL5,>mL6,>mL7,>mL8,>mL9,>mL10,>mL11
menuVarLo:  .byte <fbLock,<rpLock,<rpTime,<rpCount,<rpLevel,<latchStyle,<spaceAct,<bendRange,<syncTempo,<syncStart,<syncRhythm,<syncDrums,<syncVoice,<syncWheel,<btnTask,<[btnTask+1],<[btnTask+2]
menuVarHi:  .byte >fbLock,>rpLock,>rpTime,>rpCount,>rpLevel,>latchStyle,>spaceAct,>bendRange,>syncTempo,>syncStart,>syncRhythm,>syncDrums,>syncVoice,>syncWheel,>btnTask,>[btnTask+1],>[btnTask+2]
menuValLo:  .byte <mV0,<mVR,<mRT,<mRN,<mRV,<mV1,<mActs,<mRange,<mV3,<mV4,<mV5,<mV6,<mV7,<mV8,<mActs,<mActs,<mActs
menuValHi:  .byte >mV0,>mVR,>mRT,>mRN,>mRV,>mV1,>mActs,>mRange,>mV3,>mV4,>mV5,>mV6,>mV7,>mV8,>mActs,>mActs,>mActs
menuHookLo: .byte <FatBassMenu,<RepeatLockSet,0,0,0,<LatchStyleHook,<SpaceHook,0,<TempoHook,0,0,0,0,<WheelHook,0,0,0
menuHookHi: .byte >FatBassMenu,>RepeatLockSet,0,0,0,>LatchStyleHook,>SpaceHook,0,>TempoHook,0,0,0,0,>WheelHook,0,0,0
mLP:     .byte "REPEAT ............. ",0
mVR:     .word mV0_0,mVR1,mVR2
mVR1:    .byte "ON              ",0
mVR2:    .byte "OFF             ",0
mLT:     .byte "REPEAT TIME ........ ",0
mRT:     .word mRT0,mRT1,mRT2,mRT3,mRT4,mRT5,mRT6,mRT7,mRT8,mRT9,mRT10,mRT11,mRT12,mRT13
mRT0:    .byte "1/4             ",0
mRT1:    .byte "1/8 DOTTED      ",0
mRT2:    .byte "1/8             ",0
mRT3:    .byte "1/8 TRIPLET     ",0
mRT4:    .byte "1/16            ",0
mRT5:    .byte "FREE 80 MS      ",0
mRT6:    .byte "FREE 100 MS     ",0
mRT7:    .byte "FREE 125 MS     ",0
mRT8:    .byte "FREE 150 MS     ",0
mRT9:    .byte "FREE 200 MS     ",0
mRT10:   .byte "FREE 250 MS     ",0
mRT11:   .byte "FREE 300 MS     ",0
mRT12:   .byte "FREE 400 MS     ",0
mRT13:   .byte "FREE 500 MS     ",0
mLN:     .byte "REPEATS ............ ",0
mRN:     .word mRN1,mRN2,mRN3,mRN4,mRN5,mRN6,mRN7,mRN8
mRN1:    .byte "1               ",0
mRN2:    .byte "2               ",0
mRN3:    .byte "3               ",0
mRN4:    .byte "4               ",0
mRN5:    .byte "5               ",0
mRN6:    .byte "6               ",0
mRN7:    .byte "7               ",0
mRN8:    .byte "8               ",0
mLV:     .byte "REPEAT LEVEL ....... ",0
mRV:     .word mRV0,mRV1,mRV2,mRV3,mRV4,mRV5
mRV0:    .byte "FULL            ",0
mRV1:    .byte "90 PERCENT      ",0
mRV2:    .byte "80 PERCENT      ",0
mRV3:    .byte "70 PERCENT      ",0
mRV4:    .byte "60 PERCENT      ",0
mRV5:    .byte "50 PERCENT      ",0
mL0:     .byte "FAT BASS ........... ",0
mV0:     .word mV0_0,mV0_1,mV0_2
mV0_0: .byte "AS SOUND        ",0
mV0_1: .byte "ALWAYS          ",0
mV0_2: .byte "NEVER           ",0
mL1:     .byte "LATCH STYLE (=) .... ",0
mV1:     .word mV1_0,mV1_1,mV1_2
mV1_0: .byte "SMART           ",0
mV1_1: .byte "HOLD            ",0
mV1_2: .byte "ADD             ",0
mL2:     .byte "SPACE .............. ",0
mLR:     .byte "BEND RANGE ......... ",0
mRange:  .word mR1,mR2,mR3,mR4,mR5,mR6,mR7,mR8,mR9,mR10,mR11,mR12
mR1:     .byte "1 SEMITONE      ",0
mR2:     .byte "2 SEMITONES     ",0
mR3:     .byte "3 SEMITONES     ",0
mR4:     .byte "4 SEMITONES     ",0
mR5:     .byte "5 SEMITONES     ",0
mR6:     .byte "6 SEMITONES     ",0
mR7:     .byte "7 SEMITONES     ",0
mR8:     .byte "8 SEMITONES     ",0
mR9:     .byte "9 SEMITONES     ",0
mR10:    .byte "10 SEMITONES    ",0
mR11:    .byte "11 SEMITONES    ",0
mR12:    .byte "12 SEMITONES    ",0
mL3:     .byte "TEMPO FROM ......... ",0
mV3:     .word mV3_0,mV3_1,mV3_2
mV3_0: .byte "KEYTAR          ",0
mV3_1: .byte "OWN             ",0
mV3_2: .byte "SYNTHCART       ",0
mL4:     .byte "START/STOP ......... ",0
mV4:     .word mV4_0,mV4_1
mV4_0: .byte "KEYTAR          ",0
mV4_1: .byte "OWN             ",0
mL5:     .byte "RHYTHM BUTTONS ..... ",0
mV5:     .word mV5_0,mV5_1
mV5_0: .byte "PICK BEAT       ",0
mV5_1: .byte "IGNORE          ",0
mL6:     .byte "DRUM NOTES ......... ",0
mV6:     .word mV6_0,mV6_1
mV6_0: .byte "IGNORE          ",0
mV6_1: .byte "PLAY            ",0
mL7:     .byte "VOICE BUTTONS ...... ",0
mV7:     .word mV7_0,mV7_1
mV7_0: .byte "PICK SOUND      ",0
mV7_1: .byte "IGNORE          ",0
mL8:     .byte "WHEEL .............. ",0
mV8:     .word mV8_0,mV8_1
mV8_0: .byte "BEND            ",0
mV8_1: .byte "OFF             ",0
mL9:     .byte "VIBRATO BUTTON ..... ",0
mL10:    .byte "PORTAMENTO BUTTON .. ",0
mL11:    .byte "SUSTAIN BUTTON ..... ",0
; the actions (SPACE, the keytar's buttons), in A_ order
mActs:      .word mA0,mA1,mA2,mA3,mA4,mA5,mA6,mA7,mA8,mA9,mA10,mAR,mA11,mA12,mA13,mA14,mA15
mA0:     .byte "MUTE            ",0
mA1:     .byte "BEND DOWN       ",0
mA2:     .byte "BEND UP         ",0
mA3:     .byte "VIBRATO         ",0
mA4:     .byte "TREMOLO         ",0
mA5:     .byte "ARP             ",0
mA6:     .byte "STUTTER         ",0
mA7:     .byte "VINYL STOP      ",0
mA8:     .byte "GLIDE           ",0
mA9:     .byte "SUSTAIN         ",0
mA10:    .byte "OCTAVE UP       ",0
mAR:     .byte "REPEAT          ",0
mA11:    .byte "NEW CHORD       ",0
mA12:    .byte "TAP TEMPO       ",0
mA13:    .byte "BEAT ON/OFF     ",0
mA14:    .byte "NEXT SOUND      ",0
mA15:    .byte "NOTHING         ",0
