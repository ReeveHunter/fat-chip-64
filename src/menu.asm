; Fat Chip 64 - the menu (v0.24): RETURN in, SHIFT+RETURN back out
;
; Pages and lines come from tools/gen_menu.py (menutab.asm). A line is:
;   page   RETURN opens a page
;   enum   a setting: CRSR RIGHT / SHIFT+CRSR RIGHT step its value
;   effect a patch effect: CRSR RIGHT on / off, RETURN its settings
;   param  a patch setting: CRSR RIGHT / SHIFT+CRSR RIGHT step it
; A line can depend on a variable (mShow): it's left out while that's 0 (the
; device pages, until DEVICES says the device is in use).
; CRSR DOWN / SHIFT+CRSR DOWN choose a line. SHIFT + /: on a patch setting,
; roll just that setting; anywhere else, roll the patch. Every other key does
; its usual job (notes, banks, C= keys...), and the values shown follow.

MENU_VALCOL equ 23

MenuOpen:
	jsr GlitchCalm          ; (GLITCH may have the picture shaking)
	lda #1
	sta menuOn
	lda #0
	sta menuRow
; page A on screen (the cursor stays on its line if it's on this page)
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
	ldx menuRow             ; (a hidden line: the first one shown)
	jsr ItemShown
	bne .vis
	ldx menuPage
	lda pgFirst,x
	sta menuRow
.vis:
	jsr MenuDraw
	rts

; the whole page
MenuDraw:
	subroutine
	jsr ClearScreen
	lda #$80
	sta t2
	PRINT 0, 0, mBar
	ldx menuPage
	lda pgTitleLo,x
	sta ptr
	lda pgTitleHi,x
	sta ptr+1
	ldx #1
	ldy #0
	jsr PrintAt
	lda #0
	sta t2
	ldx menuPage
	lda pgHdrHi,x
	beq .nh
	sta ptr+1
	lda pgHdrLo,x
	sta ptr
	ldx #1
	ldy #1
	jsr PrintAt
.nh:
	PRINT 21, 0, mHelp1
	PRINT 22, 0, mHelp2
	PRINT 23, 0, mHelp3
	PRINT 24, 0, mHelp4
	ldx menuPage
	lda pgFirst,x
	tax
.i:
	stx exK
	jsr ItemShown
	beq .n
	ldx exK
	jsr ItemRow
	sta mvRow
	lda #<mDots             ; the dots, then the label over them
	sta ptr
	lda #>mDots
	sta ptr+1
	ldx #2
	ldy mvRow
	jsr PrintAt
	ldy mvRow
	ldx exK
	lda mLblLo,x
	sta ptr
	lda mLblHi,x
	sta ptr+1
	ldx #2
	jsr PrintAt
.n:
	ldx exK
	inx
	jsr .last
	bne .i
	jmp MenuVals
.last:                          ; Z set: X is past the page's lines
	ldy menuPage
	txa
	sec
	sbc pgFirst,y
	cmp pgCount,y
	rts

; line X shown? (Z clear = yes). Keeps X.
ItemShown:
	subroutine
	lda mShowHi,x
	beq .yes
	sta .v+2
	lda mShowLo,x
	sta .v+1
.v:
	lda $FFFF
	rts
.yes:
	lda #1
	rts

; A = line X's screen row: its own, moved up past hidden lines before it
ItemRow:
	subroutine
	stx exI
	lda mRowY,x
	sta exS
	ldy menuPage
	lda pgFirst,y
	tax
.c:
	cpx exI
	beq .x
	jsr ItemShown
	bne .n
	dec exS
.n:
	inx
	bne .c
.x:
	ldx exI
	lda exS
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

; every value on the page and the cursor (and the patch name, on its pages)
MenuVals:
	subroutine
	ldx menuPage
	lda pgHdrHi,x
	cmp #>patchName
	bne .nn
	lda pgHdrLo,x
	cmp #<patchName
	bne .nn
	lda #<patchName
	sta ptr
	lda #>patchName
	sta ptr+1
	ldx #1
	ldy #1
	jsr PrintAt
.nn:
	ldx menuPage
	lda pgFirst,x
	tax
.i:
	stx exK
	jsr ItemShown
	beq .n
	jsr MenuVal
.n:
	ldx exK
	inx
	ldy menuPage
	txa
	sec
	sbc pgFirst,y
	cmp pgCount,y
	bne .i
	rts

; line X: cursor and value
MenuVal:
	subroutine
	stx exK
	jsr ItemRow
	sta mvRow
	tay
	lda #32
	ldx exK
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
	ldy mvRow               ; the value's place cleared
	ldx #MENU_VALCOL
	jsr ScreenAddr
	lda #32
	ldy #39-MENU_VALCOL
.cl:
	sta (ptr2),y
	dey
	bpl .cl
	ldx exK
	lda mKind,x
	beq .page
	cmp #1
	beq .enum
	cmp #2
	beq .fx
	; a patch setting: its step's label
	lda mArgLo,x
	tax
	jsr ParamNearest
	ldx exK
	ldy mArgLo,x
	jsr StepLabel           ; -> ptr
	jmp .pr
.fx:
	lda mArgLo,x
	tax
	lda efAlways,x
	bne .page
	jsr FxIsOn
	beq .off
	lda #<mOnTxt
	ldy #>mOnTxt
	bne .py
.off:
	lda #<mOffTxt
	ldy #>mOffTxt
	bne .py
.page:
	lda #<mOpen             ; a page to open
	ldy #>mOpen
.py:
	sta ptr
	sty ptr+1
	jmp .pr
.enum:
	lda mArgLo,x
	sta ptr
	lda mArgHi,x
	sta ptr+1
	ldy #0
	lda (ptr),y             ; the value
	asl
	tay
	lda mValLo,x
	sta ptr
	lda mValHi,x
	sta ptr+1
	lda (ptr),y
	pha
	iny
	lda (ptr),y
	sta ptr+1
	pla
	sta ptr
.pr:
	ldy mvRow
	ldx #MENU_VALCOL
	lda #$80                ; (reversed)
	sta t2
	jsr PrintAt
	lda #0
	sta t2
	rts
mOpen:      .byte "RETURN: OPEN",0
mOnTxt:     .byte "ON",0
mOffTxt:    .byte "OFF",0
mBar:       .byte "                     SHIFT+RETURN: BACK ",0
mDots:      .byte ".................... ",0

; A = step of param Y -> ptr = its label (prLW bytes each)
StepLabel:
	subroutine
	tax
	lda prLLo,y
	sta ptr
	lda prLHi,y
	sta ptr+1
	txa
	beq .x
.m:
	lda ptr
	clc
	adc prLW,y
	sta ptr
	bcc .n
	inc ptr+1
.n:
	dex
	bne .m
.x:
	rts

; A = key code (commands only: notes never come here)
MenuKey:
	subroutine
	sta keyCodeNow
	cmp #K_CRSR_DOWN
	bne .r
	jmp .move
.r:
	cmp #K_CRSR_RIGHT
	bne .ret
	ldx menuRow
	lda mKind,x
	beq .open
	cmp #2
	beq .fxt
	cmp #3
	bne .en
	jmp .par
.en:
	lda shiftDown
	beq .nx
	jmp .prev
.nx:
	jmp .next
.ret:
	cmp #K_RETURN
	bne .sl
	lda shiftDown
	bne .back
	ldx menuRow
	lda mKind,x
	beq .open
	cmp #2
	beq .fxo
	rts                     ; (RETURN changes nothing)
.sl:
	cmp #K_SLASH            ; SHIFT + / on a patch setting: roll just it
	bne .oj
	lda shiftDown
	beq .oj
	ldx menuRow
	lda mKind,x
	cmp #3
	beq .pd
.oj:
	jmp .other
.pd:
	lda mArgLo,x
	tax
	jsr ParamDice
	jmp MenuVals
.back:
	ldx menuPage
	beq .close
	lda pgBackItem,x        ; back to the page above, on this page's line
	sta menuRow
	lda pgBack,x
	jmp MenuPage
.close:
	jmp MenuClose
.open:
	lda mArgLo,x
	tax
	lda pgFirst,x
	sta menuRow
	txa
	jmp MenuPage
.fxo:
	lda mArgLo,x            ; an effect: its page
	tax
.fxp:
	lda efPage,x
	tax
	lda pgFirst,x
	sta menuRow
	txa
	jmp MenuPage
.fxt:
	lda mArgLo,x            ; an effect: on / off
	tax
	lda efAlways,x
	bne .fxp                ; (always on: RIGHT opens it)
	jsr FxToggle
	jmp MenuVals
.par:
	lda mArgLo,x
	tax
	stx t3
	jsr ParamNearest
	ldx t3
	ldy shiftDown
	bne .pdn
	clc
	adc #1
	cmp prN,x
	bcc .pset
	lda #0
	beq .pset
.pdn:
	sec
	sbc #1
	bcs .pset
	lda prN,x
	sbc #0                  ; (carry clear: n - 1)
.pset:
	jsr ParamSet
	jmp MenuVals
.other:
	lda keyCodeNow
	cmp #K_F7               ; (no visualizer from in here)
	beq .x
	jsr KeyCmdPlay          ; the key's usual job
	lda menuOn
	beq .x                  ; (it closed the menu)
	jmp MenuVals            ; (it may have changed a value shown here)
.next:
	jsr .ptr
	lda (ptr),y
	clc
	adc #1
	cmp mCount,x
	bcc .set
	lda #0
	beq .set
.prev:
	jsr .ptr
	lda (ptr),y
	sec
	sbc #1
	bcs .set
	lda mCount,x
	sbc #0                  ; (carry clear: count - 1)
.set:
	sta (ptr),y
	lda mHookHi,x
	beq .drawn
	sta ptr+1
	lda mHookLo,x
	sta ptr
	jsr .call
.drawn:
	jmp MenuVals
.call:
	jmp (ptr)
.ptr:
	ldx menuRow
	lda mArgLo,x
	sta ptr
	lda mArgHi,x
	sta ptr+1
	ldy #0
.x:
	rts
.move:                          ; CRSR DOWN (SHIFT: up), past hidden lines
	ldx menuRow
	stx t3                  ; (the old line)
.m:
	ldy menuPage
	txa
	sec
	sbc pgFirst,y
	ldx shiftDown
	bne .up
	clc
	adc #1
	cmp pgCount,y
	bcc .mv
	lda #0
	beq .mv
.up:
	sec
	sbc #1
	bpl .mv
	lda pgCount,y
	sec
	sbc #1
.mv:
	clc
	adc pgFirst,y
	tax
	jsr ItemShown
	beq .m
	stx menuRow
	ldx t3
	jsr MenuVal             ; old line: cursor off
	ldx menuRow
	jmp MenuVal

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

; a chip on / off in the menu: the value already stepped; ToggleDevice does it properly
DevHook:
	subroutine
	ldx menuRow
	lda mArgLo,x
	sec
	sbc #<devOn
	tax                     ; 0 SID, 1 GB, 2 NES
	lda devOn,x
	eor #1
	sta devOn,x
	jmp ToggleDevice

mHelp1:     .byte "CRSR DOWN, SHIFT+CRSR DOWN: CHOOSE",0
mHelp2:     .byte "CRSR RIGHT, SHIFT+CRSR RIGHT: CHANGE",0
mHelp3:     .byte "RETURN: OPEN   SHIFT+/: ROLL THE DICE",0
mHelp4:     .byte "SHIFT+RETURN: BACK",0
