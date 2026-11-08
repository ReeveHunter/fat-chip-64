; Fat Chip 64 - the menu (v0.13): SHIFT+RETURN in and out
;
; CRSR DOWN / SHIFT+CRSR DOWN (up): choose a setting. CRSR RIGHT or RETURN /
; SHIFT+CRSR RIGHT: its next / previous value. Every other key works as
; usual (notes play; V, F keys, = ... too: the values here follow).
; The play screen pauses while the menu is up and redraws when it closes.

MENU_ITEMS  equ 12
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
	PRINT 2, 0, mHdrSound
	PRINT 5, 0, mHdrPlay
	PRINT 9, 0, mHdrSync
	PRINT 21, 0, mHelp1
	PRINT 22, 0, mHelp2
	PRINT 23, 0, mHelp3
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
	ldx spaceMode
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

; a button got a new task: whatever the buttons were holding ends
BtnHook:
	subroutine
	lda #0
	sta btnHeld
	sta btnHeld+1
	sta btnHeld+2
	sta vibBtn
	sta glideBtn
	sta bendBtn
	sta moment
	jsr MuteChanged
	jsr FxButtons
	lda sustainOn
	beq .x
	lda #0
	sta sustainOn
	lda latch
	bne .x
	jmp KeepPhysical
.x:
	rts

mTitle:     .byte " FAT CHIP 64 MENU    SHIFT+RETURN: BACK ",0
mHdrSound:  .byte "SOUND",0
mHdrPlay:   .byte "PLAYING",0
mHdrSync:   .byte "DEVICE SYNC: KEYTAR (MIDI IN), SYNTHCART",0
mHelp1:     .byte "CRSR DOWN / SHIFT+CRSR DOWN: CHOOSE",0
mHelp2:     .byte "CRSR RIGHT OR RETURN: NEXT VALUE",0
mHelp3:     .byte "SHIFT+CRSR RIGHT: PREVIOUS VALUE",0
menuRowY:   .byte 3,6,7,10,11,12,13,14,15,16,17,18
menuCount:  .byte 3,3,2,3,2,2,2,2,2,11,11,11
menuLblLo:  .byte <mL0,<mL1,<mL2,<mL3,<mL4,<mL5,<mL6,<mL7,<mL8,<mL9,<mL10,<mL11
menuLblHi:  .byte >mL0,>mL1,>mL2,>mL3,>mL4,>mL5,>mL6,>mL7,>mL8,>mL9,>mL10,>mL11
menuVarLo:  .byte <fbLock,<latchStyle,<spaceMode,<syncTempo,<syncStart,<syncRhythm,<syncDrums,<syncVoice,<syncWheel,<btnTask,<[btnTask+1],<[btnTask+2]
menuVarHi:  .byte >fbLock,>latchStyle,>spaceMode,>syncTempo,>syncStart,>syncRhythm,>syncDrums,>syncVoice,>syncWheel,>btnTask,>[btnTask+1],>[btnTask+2]
menuValLo:  .byte <mV0,<mV1,<mV2,<mV3,<mV4,<mV5,<mV6,<mV7,<mV8,<mTasks,<mTasks,<mTasks
menuValHi:  .byte >mV0,>mV1,>mV2,>mV3,>mV4,>mV5,>mV6,>mV7,>mV8,>mTasks,>mTasks,>mTasks
menuHookLo: .byte <FatBassMenu,<LatchStyleHook,<SpaceHook,<TempoHook,0,0,0,0,<WheelHook,<BtnHook,<BtnHook,<BtnHook
menuHookHi: .byte >FatBassMenu,>LatchStyleHook,>SpaceHook,>TempoHook,0,0,0,0,>WheelHook,>BtnHook,>BtnHook,>BtnHook
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
mV2:     .word mV2_0,mV2_1
mV2_0: .byte "MUTES           ",0
mV2_1: .byte "BENDS           ",0
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
mTasks:     .word mT0,mT1,mT2,mT3,mT4,mT5,mT6,mT7,mT8,mT9,mT10
mT0:     .byte "VIBRATO         ",0
mT1:     .byte "GLIDE           ",0
mT2:     .byte "SUSTAIN         ",0
mT3:     .byte "MUTE            ",0
mT4:     .byte "BEND DOWN       ",0
mT5:     .byte "OCTAVE UP       ",0
mT6:     .byte "NEW CHORD       ",0
mT7:     .byte "TAP TEMPO       ",0
mT8:     .byte "BEAT ON/OFF     ",0
mT9:     .byte "NEXT SOUND      ",0
mT10:    .byte "NOTHING         ",0
