; Fat Chip 64 - the menu (v0.14): RETURN in, SHIFT+RETURN back out
;
; Three pages: the main one (SOUND, PLAYING), ADVANCED SOUND and DEVICE SYNC
; (RETURN on their lines opens them, SHIFT+RETURN comes back).
; CRSR DOWN / SHIFT+CRSR DOWN (up): choose a setting. CRSR RIGHT / SHIFT+CRSR
; RIGHT: its next / previous value. Every other key works as usual (notes
; play; V, F keys, = ... too: the values here follow).
; The play screen pauses while the menu is up and redraws when it closes.

MENU_VALCOL equ 23

MenuOpen:
	jsr GlitchCalm          ; (GLITCH may have the picture shaking)
	lda #1
	sta menuOn
	lda #0
; page A on screen (the cursor stays on its line if it was on this page)
MenuPage:
	subroutine
	sta menuPage
	tax
	lda menuRow
	sec
	sbc pgFirst,x
	cmp pgCount,x
	bcc .in
	lda pgFirst,x
	sta menuRow
.in:
	jsr ClearScreen
	ldx menuPage
	lda pgTitleLo,x
	sta ptr
	lda pgTitleHi,x
	sta ptr+1
	lda #$80
	sta t2
	ldx #0
	ldy #0
	jsr PrintAt
	lda #0
	sta t2
	; headers: row, text ... $FF
	ldx menuPage
	lda pgHdrLo,x
	sta exS
	lda pgHdrHi,x
	sta exK
	ldy #0
.h:
	sty exI
	lda exS
	sta ptr
	lda exK
	sta ptr+1
	lda (ptr),y
	cmp #$FF
	beq .hd
	pha
	iny
	lda (ptr),y
	tax
	iny
	lda (ptr),y
	sta ptr+1
	stx ptr
	pla
	tay
	ldx #0
	jsr PrintAt
	lda exI
	clc
	adc #3
	tay
	bne .h
.hd:
	PRINT 21, 0, mHelp1
	PRINT 22, 0, mHelp2
	PRINT 23, 0, mHelp3
	PRINT 24, 0, mHelp4
	ldx menuPage
	lda pgFirst,x
	tax
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
	jsr .last
	bne .i
	jmp MenuVals
.last:                          ; Z set: X is past the page's items
	ldy menuPage
	txa
	sec
	sbc pgFirst,y
	cmp pgCount,y
	rts

MenuClose:
	subroutine
	lda #0
	sta menuOn
	jsr ClearScreen
	lda vizOn
	beq .play
	jmp VizDraw
.play:
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

; every value on the page and the cursor
MenuVals:
	subroutine
	ldx menuPage
	lda pgFirst,x
	tax
.i:
	stx exK
	jsr MenuVal
	ldx exK
	inx
	ldy menuPage
	txa
	sec
	sbc pgFirst,y
	cmp pgCount,y
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
	lda menuCount,x
	bne .val
	lda #<mOpen             ; a page to open
	sta ptr
	lda #>mOpen
	sta ptr+1
	bne .pr
.val:
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
.pr:
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
	ldy menuPage
	lda menuRow
	sec
	sbc pgFirst,y           ; (the line within the page)
	tax
	lda shiftDown
	bne .upr
	inx
	txa
	cmp pgCount,y
	bcc .mv
	lda #0
	beq .mv
.upr:
	dex
	txa
	bpl .mv
	lda pgCount,y
	sec
	sbc #1
.mv:
	clc
	adc pgFirst,y
	ldx menuRow
	sta menuRow
	jsr MenuVal             ; old line: cursor off
	ldx menuRow
	jmp MenuVal
.r:
	cmp #K_CRSR_RIGHT
	bne .ret
	jsr .isPage
	beq .open
	lda shiftDown
	bne .prev
	beq .next
.ret:
	cmp #K_RETURN
	bne .other
	lda shiftDown
	bne .back
	jsr .isPage
	beq .open
	rts                     ; (RETURN changes nothing)
.back:
	ldx menuPage
	beq .close
	lda pgLink,x            ; back to the main page, on this page's line
	sta menuRow
	lda #0
	jmp MenuPage
.close:
	jmp MenuClose
.open:
	lda menuVarLo,x
	pha
	tax
	lda pgFirst,x
	sta menuRow
	pla
	jmp MenuPage
.other:
	cmp #K_F7               ; (no visualizer from in here)
	beq .x
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
.x:
	rts
.isPage:                        ; Z set: the line opens a page (X = the line)
	ldx menuRow
	lda menuCount,x
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

mHelp1:     .byte "CRSR DOWN, SHIFT+CRSR DOWN: CHOOSE",0
mHelp2:     .byte "CRSR RIGHT, SHIFT+CRSR RIGHT: CHANGE",0
mHelp3:     .byte "RETURN: OPEN A PAGE",0
mHelp4:     .byte "SHIFT+RETURN: BACK",0
MENU_ITEMS  equ 35
menuRowY:   .byte 2,3,4,5,6,7,8,9,10,13,14,15,16,18,4,5,6,7,8,9,10,11,12,13,14,15,3,4,5,6,7,8,9,10,11
menuCount:  .byte 3,3,3,3,3,3,3,3,0,3,NUM_ACTS,24,2,0,4,7,5,4,4,5,2,4,3,14,8,6,3,2,2,2,2,2,NUM_ACTS,NUM_ACTS,NUM_ACTS
menuLblLo:  .byte <mI0,<mI1,<mI2,<mI3,<mI4,<mI5,<mI6,<mI7,<mI8,<mI9,<mI10,<mI11,<mI12,<mI13,<mI14,<mI15,<mI16,<mI17,<mI18,<mI19,<mI20,<mI21,<mI22,<mI23,<mI24,<mI25,<mI26,<mI27,<mI28,<mI29,<mI30,<mI31,<mI32,<mI33,<mI34
menuLblHi:  .byte >mI0,>mI1,>mI2,>mI3,>mI4,>mI5,>mI6,>mI7,>mI8,>mI9,>mI10,>mI11,>mI12,>mI13,>mI14,>mI15,>mI16,>mI17,>mI18,>mI19,>mI20,>mI21,>mI22,>mI23,>mI24,>mI25,>mI26,>mI27,>mI28,>mI29,>mI30,>mI31,>mI32,>mI33,>mI34
menuVarLo:  .byte <monoLock,<fbLock,<vibLock,<glideLock,<tremLock,<detLock,<warbLock,<rpLock,1,<latchStyle,<spaceAct,<bendRange,<beatTempo,2,<uVibDep,<uVibRate,<uVibDel,<uGlide,<uTremDep,<uTremRate,<uTremShape,<uDet,<uWarb,<uRpTime,<uRpCount,<uRpLevel,<syncTempo,<syncStart,<syncRhythm,<syncDrums,<syncVoice,<syncWheel,<btnTask,<[btnTask+1],<[btnTask+2]
menuVarHi:  .byte >monoLock,>fbLock,>vibLock,>glideLock,>tremLock,>detLock,>warbLock,>rpLock,0,>latchStyle,>spaceAct,>bendRange,>beatTempo,0,>uVibDep,>uVibRate,>uVibDel,>uGlide,>uTremDep,>uTremRate,>uTremShape,>uDet,>uWarb,>uRpTime,>uRpCount,>uRpLevel,>syncTempo,>syncStart,>syncRhythm,>syncDrums,>syncVoice,>syncWheel,>btnTask,>[btnTask+1],>[btnTask+2]
menuValLo:  .byte <mV0,<mV1,<mV2,<mV2,<mV2,<mV2,<mV2,<mV2,<mOpen,<mV3,<mActs,<mV4,<mV5,<mOpen,<mV6,<mV7,<mV8,<mV9,<mV10,<mV11,<mV12,<mV13,<mV14,<mV15,<mV16,<mV17,<mV18,<mV19,<mV20,<mV21,<mV22,<mV23,<mActs,<mActs,<mActs
menuValHi:  .byte >mV0,>mV1,>mV2,>mV2,>mV2,>mV2,>mV2,>mV2,>mOpen,>mV3,>mActs,>mV4,>mV5,>mOpen,>mV6,>mV7,>mV8,>mV9,>mV10,>mV11,>mV12,>mV13,>mV14,>mV15,>mV16,>mV17,>mV18,>mV19,>mV20,>mV21,>mV22,>mV23,>mActs,>mActs,>mActs
menuHookLo: .byte <MonoMenu,<FatBassMenu,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,0,<LatchStyleHook,<SpaceHook,0,0,0,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<SoundLocks,<TempoHook,0,0,0,0,<WheelHook,0,0,0
menuHookHi: .byte >MonoMenu,>FatBassMenu,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,0,>LatchStyleHook,>SpaceHook,0,0,0,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>SoundLocks,>TempoHook,0,0,0,0,>WheelHook,0,0,0
pgFirst:    .byte 0,14,26
pgCount:    .byte 14,12,9
pgLink:     .byte 0,8,13
pgTitleLo:  .byte <mT0,<mT1,<mT2
pgTitleHi:  .byte >mT0,>mT1,>mT2
pgHdrLo:    .byte <mH0,<mH1,<mH2
pgHdrHi:    .byte >mH0,>mH1,>mH2
mT0:     .byte " FAT CHIP 64 MENU    SHIFT+RETURN: BACK ",0
mH0:     .byte 1,<mH0_0,>mH0_0,12,<mH0_1,>mH0_1,$FF
mH0_0:   .byte "SOUND   (ON: THE ADVANCED SOUND VALUES)",0
mH0_1:   .byte "PLAYING",0
mT1:     .byte " ADVANCED SOUND      SHIFT+RETURN: BACK ",0
mH1:     .byte 1,<mH1_0,>mH1_0,2,<mH1_1,>mH1_1,$FF
mH1_0:   .byte "USED WHERE THE MENU SAYS ON, AND BY",0
mH1_1:   .byte "VIBRATO, GLIDE, TREMOLO, REPEAT HELD",0
mT2:     .byte " DEVICE SYNC         SHIFT+RETURN: BACK ",0
mH2:     .byte 1,<mH2_0,>mH2_0,$FF
mH2_0:   .byte "KEYTAR (MIDI IN), SYNTHCART",0
mOpen:    .byte "RETURN: OPEN    ",0
mI0:     .byte "MONO/POLY .......... ",0
mV0:     .word mV0_0,mV0_1,mV0_2
mV0_0:   .byte "AS SOUND        ",0
mV0_1:   .byte "MONO            ",0
mV0_2:   .byte "POLY            ",0
mI1:     .byte "FAT BASS ........... ",0
mV1:     .word mV1_0,mV1_1,mV1_2
mV1_0:   .byte "AS SOUND        ",0
mV1_1:   .byte "ALWAYS          ",0
mV1_2:   .byte "NEVER           ",0
mI2:     .byte "VIBRATO ............ ",0
mV2:     .word mV2_0,mV2_1,mV2_2
mV2_0:   .byte "AS SOUND        ",0
mV2_1:   .byte "ON              ",0
mV2_2:   .byte "OFF             ",0
mI3:     .byte "GLIDE .............. ",0
mI4:     .byte "TREMOLO ............ ",0
mI5:     .byte "DETUNE ............. ",0
mI6:     .byte "WARBLE (GAME BOY) .. ",0
mI7:     .byte "REPEAT ............. ",0
mI8:     .byte "ADVANCED SOUND ..... ",0
mI9:     .byte "LATCH STYLE (=) .... ",0
mV3:     .word mV3_0,mV3_1,mV3_2
mV3_0:   .byte "SMART           ",0
mV3_1:   .byte "HOLD            ",0
mV3_2:   .byte "ADD             ",0
mI10:    .byte "SPACE .............. ",0
mI11:    .byte "BEND RANGE ......... ",0
mV4:     .word mV4_0,mV4_1,mV4_2,mV4_3,mV4_4,mV4_5,mV4_6,mV4_7,mV4_8,mV4_9,mV4_10,mV4_11,mV4_12,mV4_13,mV4_14,mV4_15,mV4_16,mV4_17,mV4_18,mV4_19,mV4_20,mV4_21,mV4_22,mV4_23
mV4_0:   .byte "1 SEMITONE      ",0
mV4_1:   .byte "2 SEMITONES     ",0
mV4_2:   .byte "3 SEMITONES     ",0
mV4_3:   .byte "4 SEMITONES     ",0
mV4_4:   .byte "5 SEMITONES     ",0
mV4_5:   .byte "6 SEMITONES     ",0
mV4_6:   .byte "7 SEMITONES     ",0
mV4_7:   .byte "8 SEMITONES     ",0
mV4_8:   .byte "9 SEMITONES     ",0
mV4_9:   .byte "10 SEMITONES    ",0
mV4_10:  .byte "11 SEMITONES    ",0
mV4_11:  .byte "12 SEMITONES    ",0
mV4_12:  .byte "13 SEMITONES    ",0
mV4_13:  .byte "14 SEMITONES    ",0
mV4_14:  .byte "15 SEMITONES    ",0
mV4_15:  .byte "16 SEMITONES    ",0
mV4_16:  .byte "17 SEMITONES    ",0
mV4_17:  .byte "18 SEMITONES    ",0
mV4_18:  .byte "19 SEMITONES    ",0
mV4_19:  .byte "20 SEMITONES    ",0
mV4_20:  .byte "21 SEMITONES    ",0
mV4_21:  .byte "22 SEMITONES    ",0
mV4_22:  .byte "23 SEMITONES    ",0
mV4_23:  .byte "24 SEMITONES    ",0
mI12:    .byte "BEAT TEMPO ......... ",0
mV5:     .word mV5_0,mV5_1
mV5_0:   .byte "DEFAULT         ",0
mV5_1:   .byte "IGNORE          ",0
mI13:    .byte "DEVICE SYNC ........ ",0
mI14:    .byte "VIBRATO DEPTH ...... ",0
mV6:     .word mV6_0,mV6_1,mV6_2,mV6_3
mV6_0:   .byte "1/8 SEMITONE    ",0
mV6_1:   .byte "1/4 SEMITONE    ",0
mV6_2:   .byte "3/8 SEMITONE    ",0
mV6_3:   .byte "1/2 SEMITONE    ",0
mI15:    .byte "VIBRATO RATE ....... ",0
mV7:     .word mV7_0,mV7_1,mV7_2,mV7_3,mV7_4,mV7_5,mV7_6
mV7_0:   .byte "2 HZ            ",0
mV7_1:   .byte "3 HZ            ",0
mV7_2:   .byte "4 HZ            ",0
mV7_3:   .byte "5 HZ            ",0
mV7_4:   .byte "6 HZ            ",0
mV7_5:   .byte "7 HZ            ",0
mV7_6:   .byte "8 HZ            ",0
mI16:    .byte "VIBRATO DELAY ...... ",0
mV8:     .word mV8_0,mV8_1,mV8_2,mV8_3,mV8_4
mV8_0:   .byte "NONE            ",0
mV8_1:   .byte "100 MS          ",0
mV8_2:   .byte "250 MS          ",0
mV8_3:   .byte "500 MS          ",0
mV8_4:   .byte "1 SECOND        ",0
mI17:    .byte "GLIDE TIME ......... ",0
mV9:     .word mV9_0,mV9_1,mV9_2,mV9_3
mV9_0:   .byte "FAST            ",0
mV9_1:   .byte "MEDIUM          ",0
mV9_2:   .byte "SLOW            ",0
mV9_3:   .byte "VERY SLOW       ",0
mI18:    .byte "TREMOLO DEPTH ...... ",0
mV10:    .word mV10_0,mV10_1,mV10_2,mV10_3
mV10_0:  .byte "LIGHT           ",0
mV10_1:  .byte "MEDIUM          ",0
mV10_2:  .byte "DEEP            ",0
mV10_3:  .byte "FULL            ",0
mI19:    .byte "TREMOLO RATE ....... ",0
mV11:    .word mV11_0,mV11_1,mV11_2,mV11_3,mV11_4
mV11_0:  .byte "2 HZ            ",0
mV11_1:  .byte "4 HZ            ",0
mV11_2:  .byte "6 HZ            ",0
mV11_3:  .byte "8 HZ            ",0
mV11_4:  .byte "10 HZ           ",0
mI20:    .byte "TREMOLO SHAPE ...... ",0
mV12:    .word mV12_0,mV12_1
mV12_0:  .byte "SMOOTH          ",0
mV12_1:  .byte "SQUARE          ",0
mI21:    .byte "DETUNE ............. ",0
mV13:    .word mV13_0,mV13_1,mV13_2,mV13_3
mV13_0:  .byte "SUBTLE          ",0
mV13_1:  .byte "FAT             ",0
mV13_2:  .byte "WIDE            ",0
mV13_3:  .byte "HUGE            ",0
mI22:    .byte "WARBLE (GAME BOY) .. ",0
mV14:    .word mV14_0,mV14_1,mV14_2
mV14_0:  .byte "LIGHT           ",0
mV14_1:  .byte "MEDIUM          ",0
mV14_2:  .byte "DEEP            ",0
mI23:    .byte "REPEAT TIME ........ ",0
mV15:    .word mV15_0,mV15_1,mV15_2,mV15_3,mV15_4,mV15_5,mV15_6,mV15_7,mV15_8,mV15_9,mV15_10,mV15_11,mV15_12,mV15_13
mV15_0:  .byte "1/4             ",0
mV15_1:  .byte "1/8 DOTTED      ",0
mV15_2:  .byte "1/8             ",0
mV15_3:  .byte "1/8 TRIPLET     ",0
mV15_4:  .byte "1/16            ",0
mV15_5:  .byte "FREE 80 MS      ",0
mV15_6:  .byte "FREE 100 MS     ",0
mV15_7:  .byte "FREE 125 MS     ",0
mV15_8:  .byte "FREE 150 MS     ",0
mV15_9:  .byte "FREE 200 MS     ",0
mV15_10: .byte "FREE 250 MS     ",0
mV15_11: .byte "FREE 300 MS     ",0
mV15_12: .byte "FREE 400 MS     ",0
mV15_13: .byte "FREE 500 MS     ",0
mI24:    .byte "REPEATS ............ ",0
mV16:    .word mV16_0,mV16_1,mV16_2,mV16_3,mV16_4,mV16_5,mV16_6,mV16_7
mV16_0:  .byte "1               ",0
mV16_1:  .byte "2               ",0
mV16_2:  .byte "3               ",0
mV16_3:  .byte "4               ",0
mV16_4:  .byte "5               ",0
mV16_5:  .byte "6               ",0
mV16_6:  .byte "7               ",0
mV16_7:  .byte "8               ",0
mI25:    .byte "REPEAT LEVEL ....... ",0
mV17:    .word mV17_0,mV17_1,mV17_2,mV17_3,mV17_4,mV17_5
mV17_0:  .byte "FULL            ",0
mV17_1:  .byte "90 PERCENT      ",0
mV17_2:  .byte "80 PERCENT      ",0
mV17_3:  .byte "70 PERCENT      ",0
mV17_4:  .byte "60 PERCENT      ",0
mV17_5:  .byte "50 PERCENT      ",0
mI26:    .byte "TEMPO FROM ......... ",0
mV18:    .word mV18_0,mV18_1,mV18_2
mV18_0:  .byte "KEYTAR          ",0
mV18_1:  .byte "OWN             ",0
mV18_2:  .byte "SYNTHCART       ",0
mI27:    .byte "START/STOP ......... ",0
mV19:    .word mV19_0,mV19_1
mV19_0:  .byte "KEYTAR          ",0
mV19_1:  .byte "OWN             ",0
mI28:    .byte "RHYTHM BUTTONS ..... ",0
mV20:    .word mV20_0,mV20_1
mV20_0:  .byte "PICK BEAT       ",0
mV20_1:  .byte "IGNORE          ",0
mI29:    .byte "DRUM NOTES ......... ",0
mV21:    .word mV21_0,mV21_1
mV21_0:  .byte "IGNORE          ",0
mV21_1:  .byte "PLAY            ",0
mI30:    .byte "VOICE BUTTONS ...... ",0
mV22:    .word mV22_0,mV22_1
mV22_0:  .byte "PICK SOUND      ",0
mV22_1:  .byte "IGNORE          ",0
mI31:    .byte "WHEEL .............. ",0
mV23:    .word mV23_0,mV23_1
mV23_0:  .byte "BEND            ",0
mV23_1:  .byte "OFF             ",0
mI32:    .byte "VIBRATO BUTTON ..... ",0
mI33:    .byte "PORTAMENTO BUTTON .. ",0
mI34:    .byte "SUSTAIN BUTTON ..... ",0
; the actions (SPACE, the keytar's buttons), in A_ order
mActs:      .word mA0,mA1,mA2,mA3,mA4,mA5,mA6,mA7,mA8,mA9,mA10,mA11,mA12,mA13,mA14,mA15,mA16,mA17,mA18,mA19
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
mA11:    .byte "REPEAT          ",0
mA12:    .byte "FILTER SWEEP    ",0
mA13:    .byte "BEAT FILL       ",0
mA14:    .byte "TAPE WOBBLE     ",0
mA15:    .byte "WIDE            ",0
mA16:    .byte "TAP TEMPO       ",0
mA17:    .byte "BEAT ON/OFF     ",0
mA18:    .byte "NEXT SOUND      ",0
mA19:    .byte "NOTHING         ",0

