; Fat Chip 64 - screen
;
;  row 0      header
;  row 2      sound, POLY / MONO, Fat Bass
;  rows 4-6   SID, Game Boy, MidiNES: on / off or channels, the three notes
;             each plays (row 7: a channel overlap warning)
;  row 9      key, notes mode, latch
;  row 10     arp
;  row 12     tempo, beat, mute
;  row 13     SPACE's action, octave (the lowest key)
;  row 15     held notes
;  row 16     MIDI in
;  row 24     F keys

; Print the 0-terminated ASCII string at (ptr) to screen row Y, column X.
; Letters become screen codes; bit 7 of t2 reverses.
PrintAt:
	subroutine
	jsr ScreenAddr
	ldy #0
.c:
	lda (ptr),y
	beq .done
	cmp #64
	bcc .noLetter
	sec
	sbc #64
.noLetter:
	ora t2
	sta (ptr2),y
	iny
	bne .c
.done:
	rts

; ptr2 = SCREEN + 40*Y + X (row table: no loop)
ScreenAddr:
	subroutine
	txa
	clc
	adc rowAddrLo,y
	sta ptr2
	lda rowAddrHi,y
	adc #0
	sta ptr2+1
	ldy #0                  ; (callers expect Y = 0, as the old loop left it)
	rts
rowAddrLo:
	.byte <(SCREEN+0),<(SCREEN+40),<(SCREEN+80),<(SCREEN+120),<(SCREEN+160),<(SCREEN+200),<(SCREEN+240),<(SCREEN+280),<(SCREEN+320),<(SCREEN+360),<(SCREEN+400),<(SCREEN+440),<(SCREEN+480),<(SCREEN+520),<(SCREEN+560),<(SCREEN+600),<(SCREEN+640),<(SCREEN+680),<(SCREEN+720),<(SCREEN+760),<(SCREEN+800),<(SCREEN+840),<(SCREEN+880),<(SCREEN+920),<(SCREEN+960)
rowAddrHi:
	.byte >(SCREEN+0),>(SCREEN+40),>(SCREEN+80),>(SCREEN+120),>(SCREEN+160),>(SCREEN+200),>(SCREEN+240),>(SCREEN+280),>(SCREEN+320),>(SCREEN+360),>(SCREEN+400),>(SCREEN+440),>(SCREEN+480),>(SCREEN+520),>(SCREEN+560),>(SCREEN+600),>(SCREEN+640),>(SCREEN+680),>(SCREEN+720),>(SCREEN+760),>(SCREEN+800),>(SCREEN+840),>(SCREEN+880),>(SCREEN+920),>(SCREEN+960)

; macro-ish helper: PRINT row, col, label
	mac PRINT
	ldx #{2}
	ldy #{1}
	lda #<{3}
	sta ptr
	lda #>{3}
	sta ptr+1
	jsr PrintAt
	endm

; Put the character in A at column X of the row in ptr2 (ScreenAddr first).
; Keeps X; uses Y.
PutChar:
	subroutine
	pha
	txa
	tay
	pla
	cmp #64
	bcc .nl
	sec
	sbc #64
.nl:
	sta (ptr2),y
	rts

; Decimal 0-99 in A at column X of row ptr2 (one or two digits). Returns X past it.
PutNum:
	subroutine
	ldy #0
.tens:
	cmp #10
	bcc .ones
	sbc #10
	iny
	bne .tens
.ones:
	pha
	tya
	beq .skip
	clc
	adc #'0
	jsr PutChar
	inx
.skip:
	pla
	clc
	adc #'0
	jsr PutChar
	inx
	rts

ScreenInit:
	subroutine
	lda #0
	sta BORDER
	sta BGCOL
	ldx #0
.c:
	lda #32
	sta SCREEN,x
	sta SCREEN+$100,x
	sta SCREEN+$200,x
	sta SCREEN+$2E8,x
	lda #13                 ; light green, a nod to the Game Boy
	sta COLRAM,x
	sta COLRAM+$100,x
	sta COLRAM+$200,x
	sta COLRAM+$2E8,x
	inx
	bne .c
	lda VIC_CTRL1
	ora #$10
	sta VIC_CTRL1
	lda #$15                ; uppercase character set
	sta $D018
	rts

ScreenDrawAll:
	jsr ScreenStatic
	jmp ScreenDynamic

; the labels that never change
ScreenStatic:
	subroutine
	lda #$80
	sta t2
	PRINT 0, 0, txtHeader
	lda #0
	sta t2

	PRINT 4, 0, txtSid
	PRINT 5, 0, txtGb
	PRINT 6, 0, txtNes
	PRINT 9, 0, txtKeyLn
	PRINT 10, 0, txtArp
	PRINT 12, 0, txtTempo
	PRINT 13, 0, txtSpaceLn
	PRINT 15, 0, txtHeld
	PRINT 16, 0, txtMidiIn
	PRINT 24, 0, txtHelp
	rts

ScreenDynamic:
	subroutine
	ldx #1
.s:
	stx scrStage
	jsr .one
	ldx scrStage
	inx
	cpx #SCR_STAGES+1
	bne .s
	lda #0
	sta scrStage
	rts
.one:
	lda stageLo-1,x
	sta ptr
	lda stageHi-1,x
	sta ptr+1
	jmp (ptr)

; Redraw in small steps, one per main loop pass, so a redraw never holds up
; the keyboard or the arp: 10 stages, each a line or two. (The visualizer has
; its own steps; nothing is drawn while the menu is up.)
ScreenStep:
	subroutine
	lda menuOn              ; (the menu is on screen)
	beq .play
	rts
.play:
	lda vizOn
	beq .scr
	jmp VizStep
.scr:
	lda scrStage
	bne .run
	lda screenDirty
	beq .x
	lda #0
	sta screenDirty
	lda #1
	sta scrStage
.run:
	tax
	lda stageLo-1,x
	sta ptr
	lda stageHi-1,x
	sta ptr+1
	jsr .call
	inc scrStage
	lda scrStage
	cmp #SCR_STAGES+1
	bcc .x
	lda #0
	sta scrStage
.x:
	rts
.call:
	jmp (ptr)

SCR_STAGES equ 10
stageLo:	.byte <ScrSound,<ScrSid,<ScrGb,<ScrNes,<ScrKey,<ScrArpLine,<ScrTempo,<ScrSpace,<ScrHeld,<ScrMidiIn
stageHi:	.byte >ScrSound,>ScrSid,>ScrGb,>ScrNes,>ScrKey,>ScrArpLine,>ScrTempo,>ScrSpace,>ScrHeld,>ScrMidiIn

; ---- row 2: sound, POLY / MONO, Fat Bass
ScrSound:
	subroutine
	lda #0
	sta t2
	lda #<txtBlank6         ; the bank and slot (v0.22): FAT  1, LEADS 4
	sta ptr
	lda #>txtBlank6
	sta ptr+1
	ldx #0
	ldy #2
	jsr PrintAt
	ldx soundMode
	cpx #NUM_SOUNDS
	bcs .nob                ; (a patch from Chip Lab: no bank)
	lda patchSlot,x
	cmp #$FF
	beq .nob
	ldy #0
.b5:
	cmp #5
	bcc .bs
	sbc #5
	iny
	bne .b5
.bs:
	sta t3                  ; slot
	tya
	asl
	asl
	sty t0
	adc t0                  ; bank x 5: its name
	sta t0
	ldx #0
.bn:
	ldy t0
	lda bankName,y
	jsr PutChar             ; (uses Y)
	inc t0
	inx
	cpx #5
	bne .bn
	lda t3
	clc
	adc #"1"
	ldx #6
	jsr PutChar
.nob:
	lda #<patchName
	sta ptr
	lda #>patchName
	sta ptr+1
	ldx #8
	ldy #2
	jsr PrintAt
	lda #<txtPoly
	ldy #>txtPoly
	ldx monoMode
	beq .pm
	lda #<txtMono
	ldy #>txtMono
.pm:
	sta ptr
	sty ptr+1
	ldx #25
	ldy #2
	jsr PrintAt
	lda #<txtNoBass
	ldy #>txtNoBass
	ldx fatBass
	beq .fb
	lda #<txtFatBass
	ldy #>txtFatBass
.fb:
	sta ptr
	sty ptr+1
	ldx #30
	ldy #2
	jmp PrintAt

; ---- rows 4-6: a chip, its on / off or channels, the notes its three
; voices play (voices X, X+3, X+6)
ScrSid:
	ldx #0
	beq ScrChip
ScrGb:
	ldx #1
	bne ScrChip
ScrNes:
	jsr ScrOverlap
	ldx #2
ScrChip:
	subroutine
	stx t3
	txa
	clc
	adc #4
	sta exV                 ; the row
	tay
	ldx #0
	jsr ScreenAddr
	; on / off, channels
	ldx t3
	lda devOn,x
	bne .on
	lda #<txtOff
	ldy #>txtOff
	bne .pt
.on:
	cpx #0
	bne .ch
	lda #<txtOn
	ldy #>txtOn
.pt:
	sta ptr
	sty ptr+1
	ldx #9
	ldy exV
	jsr PrintAt
	jmp .notes
.ch:
	lda gbBase              ; "11-15"
	cpx #1
	beq .cb
	lda nesBase
.cb:
	pha
	clc
	adc #1
	ldx #9
	jsr PutNum
	lda #'-
	jsr PutChar
	inx
	pla
	clc
	adc #5
	jsr PutNum
	lda #32
	jsr PutChar
	inx
	jsr PutChar
.notes:
	; the note each voice really plays: Fat Bass folds the bass voices, a
	; sound can put the Game Boy pulses or the SID an octave off
	lda #16
	sta exI                 ; column
	lda t3
	sta exD                 ; voice
.v:
	ldx exD
	lda vNote,x
	cmp #NO_NOTE
	beq .pn
	ldy vDev,x
	beq .sid
	stx t0
	jsr MidiNoteValue
	jmp .pn
.sid:
	ldy soundMode
	clc
	adc sndOct
	bpl .pn
	clc
	adc #12
.pn:
	pha
	ldy exV
	ldx #0
	jsr ScreenAddr
	pla
	ldx exI
	jsr PutNote
	lda exI
	clc
	adc #6
	sta exI
	lda exD
	clc
	adc #3
	sta exD
	cmp #NUM_VOICES
	bcc .v
	; an off chip is drawn dark
	ldx t3
	lda devOn,x
	beq .dark
	lda #13
	bne .col
.dark:
	lda #11
.col:
	sta t1
	ldy exV
	ldx #0
	jsr ScreenAddr
	lda ptr2+1
	clc
	adc #>(COLRAM-SCREEN)
	sta ptr2+1
	ldy #39
	lda t1
.cc:
	sta (ptr2),y
	dey
	bpl .cc
	rts

; row 7: both MIDI chips on and their channel blocks overlap
ScrOverlap:
	subroutine
	lda #0
	sta t2
	PRINT 7, 0, txtBlank
	lda devOn+DEV_GB
	and devOn+DEV_NES
	beq .x
	lda gbBase
	sec
	sbc nesBase
	bcs .pos
	eor #$FF
	adc #1
.pos:
	cmp #5
	bcs .x
	PRINT 7, 0, txtOverlap
.x:
	rts

; ---- row 9: key, notes mode, latch (NEXT: the next key starts a new chord)
ScrKey:
	subroutine
	lda #0
	sta t2
	ldy #9
	ldx #0
	jsr ScreenAddr
	lda keyRoot
	asl
	sta t0
	tay
	ldx #4
	lda noteNames,y
	jsr PutChar             ; (uses Y)
	inx
	ldy t0
	lda noteNames+1,y
	jsr PutChar
	lda keyScale            ; the scale's name (11 bytes each)
	asl
	asl
	asl
	clc
	adc keyScale
	adc keyScale
	adc keyScale            ; x 11
	adc #<scaleName
	sta ptr
	lda #>scaleName
	adc #0
	sta ptr+1
	ldx #7
	ldy #9
	jsr PrintAt
	lda kArm                ; K tapped: waiting for the note or shape
	beq .ka
	ldx #0
	ldy #9
	jsr ScreenAddr
	ldx #4
	lda #"?"
	jsr PutChar
	ldx #5
	lda #" "
	jsr PutChar
.ka:
	ldx playMode
	cpx #MODE_DRONE
	bne .m0
	ldx #6
	bne .m1
.m0:
	cpx #MODE_EXT
	bne .m1
	lda spice
	clc
	adc #2
	tax
.m1:
	lda modeTxtLo,x
	sta ptr
	lda modeTxtHi,x
	sta ptr+1
	ldx #18
	ldy #9
	jsr PrintAt
	ldy latch
	lda newPending
	beq .l
	tya
	beq .l
	ldy #4                  ; NEXT
.l:
	lda txtLatchLo,y
	sta ptr
	lda txtLatchHi,y
	sta ptr+1
	ldx #34
	ldy #9
	jmp PrintAt

; ---- row 10: arp mode, pattern, speed, SPARKLE octave
ScrArpLine:
	subroutine
	lda #0
	sta t2
	ldx arpMode
	lda arpModeLo,x
	sta ptr
	lda arpModeHi,x
	sta ptr+1
	ldx #4
	ldy #10
	jsr PrintAt
	ldx arpPat
	lda patTxtLo,x
	sta ptr
	lda patTxtHi,x
	sta ptr+1
	ldx #12
	ldy #10
	jsr PrintAt
	ldx arpLen
	cpx #ARP_FREE
	beq .free
	lda lenTxtLo,x
	sta ptr
	lda lenTxtHi,x
	sta ptr+1
	ldx #19
	ldy #10
	jsr PrintAt
	jmp .oct
.free:
	ldy #10
	ldx #0
	jsr ScreenAddr
	ldy freeIdx
	lda freeLo,y
	sta t0
	lda freeHi,y
	sta t1
	ldx #24                 ; clear the field first (1000MS .. 10MS)
	lda #32
.clr:
	jsr PutChar
	dex
	cpx #19
	bcs .clr
	ldx #19
	jsr PutDecZ
	lda #'M
	jsr PutChar
	inx
	lda #'S
	jsr PutChar
.oct:
	ldy arpOct
	lda octTxtLo,y
	sta ptr
	lda octTxtHi,y
	sta ptr+1
	ldx #26
	ldy #10
	jmp PrintAt

; ---- row 12: tempo, beat (PLAY / STOP), mute
ScrTempo:
	subroutine
	lda #0
	sta t2
	ldy #12
	ldx #0
	jsr ScreenAddr
	ldx #6
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
	ldx #6
	jsr PutDecZ
	ldx beatSel
	lda beatNameLo,x
	sta ptr
	lda beatNameHi,x
	sta ptr+1
	ldx #20
	ldy #12
	jsr PrintAt
	lda #<txtStop
	ldy #>txtStop
	ldx beatRun
	beq .br
	lda #<txtPlay
	ldy #>txtPlay
.br:
	sta ptr
	sty ptr+1
	ldx #29
	ldy #12
	jsr PrintAt
	lda #<txtNoMute
	ldy #>txtNoMute
	ldx sidMute
	beq .mo
	lda #<txtMute
	ldy #>txtMute
.mo:
	sta ptr
	sty ptr+1
	ldx #35
	ldy #12
	jmp PrintAt

; ---- row 13: SPACE's action, octave (the lowest key's note)
ScrSpace:
	subroutine
	lda #0
	sta t2
	ldx spaceAct
	lda spcTxtLo,x
	sta ptr
	lda spcTxtHi,x
	sta ptr+1
	ldx #6
	ldy #13
	jsr PrintAt
	ldy #13
	ldx #0
	jsr ScreenAddr
	ldx #23
	lda octBase
	jmp PutMidiNote

; ---- row 15: held notes
ScrHeld:
	subroutine
	lda #0
	sta t2
	PRINT 15, 0, txtHeld
	ldy #15
	ldx #0
	jsr ScreenAddr
	ldx #6
	ldy #0
.h:
	cpy heldCount
	beq .hd
	sty t3
	lda heldList,y
	jsr PutMidiNote
	inx
	ldy t3
	iny
	bne .h
.hd:
	rts

; ---- row 16: MIDI in octave (H / J), last note received
ScrMidiIn:
	subroutine
	lda #0
	sta t2
	ldy #16
	ldx #0
	jsr ScreenAddr
	lda #'+
	ldy midiOct
	bpl .po
	lda #'-
.po:
	ldx #13
	jsr PutChar
	lda midiOct
	bpl .pd
	eor #$FF
	clc
	adc #1
.pd:
	clc
	adc #'0
	inx
	jsr PutChar
	lda lastInNote
	cmp #NO_NOTE
	bne .last
	PRINT 16, 26, txtNoIn
	rts
.last:
	ldx #26
	lda #'C
	jsr PutChar
	inx
	lda #'H
	jsr PutChar
	inx
	lda lastInCh
	clc
	adc #1
	jsr PutNum
	lda #32
	jsr PutChar
	inx
	lda lastInNote
	jmp PutMidiNote

; 16-bit number in t1:t0 at column X of row ptr2, five digits
PutDec16:
	subroutine
	ldy #0
.digit:
	lda #0
	sta t2
.sub:
	lda t0
	sec
	sbc decLo,y
	pha
	lda t1
	sbc decHi,y
	bcc .done
	sta t1
	pla
	sta t0
	inc t2
	bne .sub
.done:
	pla
	lda t2
	clc
	adc #'0
	sty t3
	jsr PutChar
	ldy t3
	inx
	iny
	cpy #5
	bne .digit
	rts

; Like PutDec16, without leading zeros. Returns X past the number.
PutDecZ:
	subroutine
	lda #0
	sta decStarted
	ldy #0
.digit:
	lda #0
	sta t2
.sub:
	lda t0
	sec
	sbc decLo,y
	pha
	lda t1
	sbc decHi,y
	bcc .done
	sta t1
	pla
	sta t0
	inc t2
	bne .sub
.done:
	pla
	lda t2
	bne .put
	cpy #4
	beq .put                ; always the last digit
	lda decStarted
	beq .skip
	lda t2
.put:
	clc
	adc #'0
	sty t3
	jsr PutChar
	ldy t3
	inx
	lda #1
	sta decStarted
.skip:
	iny
	cpy #5
	bne .digit
	lda #0
	sta t2
	rts

decLo:	.byte <10000,<1000,<100,<10,<1
decHi:	.byte >10000,>1000,>100,>10,>1

; Note index A (or NO_NOTE) at column X of row ptr2: "C#3", "--"
PutNote:
	subroutine
	cmp #NO_NOTE
	bne .n
	lda #'-
	jsr PutChar
	inx
	jsr PutChar
	inx
	lda #32
	jsr PutChar
	inx
	jmp PutChar
.n:
; MIDI note A at column X: name + octave (C4 = 60)
PutMidiNote:
	ldy #0
.o:
	cmp #12
	bcc .name
	sbc #12
	iny
	bne .o
.name:
	sty t1                  ; octave + 1
	asl
	pha
	tay
	lda noteNames,y
	jsr PutChar             ; (uses Y)
	inx
	pla
	tay
	lda noteNames+1,y
	jsr PutChar
	inx
	lda t1
	sec
	sbc #1
	clc
	adc #'0
	jsr PutChar
	inx
	lda #32
	jmp PutChar
