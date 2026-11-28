; Fat Chip 64 - THE LOOPER, sampler stage 2 (v0.69): six loop tracks of pad hits
;
; One clock, 24 ticks a beat, four beats a bar; each track its own length in
; bars. While a beat runs the clock steps with it (6 ticks a step, waiting
; for the beat's next step, so they never drift); a beat started while loops
; play waits for their next bar.
;
; In the sampler: F1 / F3 pick a track (1-6). F5, its button, as the RC-505's:
; EMPTY -> armed (recording from the first hit) -> F5: its length, the take
; rounded to whole bars (late: the hits past the end go to its start; early:
; it runs to the bar's end), and it plays -> F5 overdub -> F5 play. A stopped
; track: F5 plays it from the next bar. F5 twice quickly: stop. F7: stop
; (SHIFT + F7: all); F7 on a stopped track clears it. <- undoes the last
; overdub (again: back). C= + 1-6: mute. QUANTIZE (menu SAMPLER): OFF, 1/16,
; 1/8, as hits are recorded. On the play screen RUN/STOP + Q W E R T Y is
; track 1-6's button.
;
; A hit is 3 bytes under the I/O (LPEV: a region a track): its tick (low,
; then high in bits 0-2 with $80: this overdub's, $40: undone, $20: skip once
; - recorded on or after where the loop is), then pad | kit << 4 | accent << 5.
; A track's hits stay in order of their ticks.

LP_EMPTY    equ 0
LP_ARMED    equ 1
LP_REC      equ 2
LP_PLAY     equ 3
LP_DUB      equ 4
LP_STOP     equ 5
LP_CUED     equ 6
LP_TRACKS   equ 6
LP_HITS     equ 76              ; a track's hits (3 bytes each)
LP_BAR      equ 96              ; ticks a bar
LP_TAP      equ 250             ; ms: F5 twice within it stops

; ---- the clock (main loop). It rests while no track is armed, recording,
; playing or cued (and no beat waits for it): nothing to keep time for
LoopTick:
	subroutine
	lda lpDirty
	beq .k
	jsr LoopAny
.k:
	lda lpAny
	bne .go
	lda lpDirty             ; (resting: a change still shows)
	beq .r
	lda #0
	sta lpDirty
	lda #1
	sta screenDirty
.r:
	rts
.go:
	jsr GetTicks
	lda beatRun
	beq .due
	lda lpRel               ; (a beat: this step's ticks used, wait for its next)
	bne .due
	rts
.due:
	lda nowL
	sec
	sbc lpAtL
	lda nowH
	sbc lpAtH
	bmi .x
	beq .ok                 ; (more than 255 ms behind: from now)
	lda nowL
	sta lpAtL
	lda nowH
	sta lpAtH
.ok:
	lda beat16L             ; a tick: a beat / 24, in 1/16 ms (worked out
	cmp lpB16L              ;  again only when the tempo changes)
	bne .dv
	lda beat16H
	cmp lpB16H
	beq .tk
.dv:
	lda beat16L
	sta lpB16L
	sta dvdL
	lda beat16H
	sta lpB16H
	sta dvdH
	lda #24
	jsr DivA
	lda dvdL
	sta lpTkL
	lda dvdH
	sta lpTkH
.tk:
	lda lpTkL
	clc
	adc lpFrac
	sta t0
	lda lpTkH
	adc #0
	sta t1
	lda t0
	and #15
	sta lpFrac
	ldx #4
.d:
	lsr t1
	ror t0
	dex
	bne .d
	lda lpAtL
	clc
	adc t0
	sta lpAtL
	lda lpAtH
	adc t1
	sta lpAtH
	lda lpRel
	beq .s
	dec lpRel
.s:
	jmp LoopStep
.x:
	rts

; lpAny: 1 if a track is armed, records, plays or is cued (or a beat waits);
; waking, the clock starts from now
LoopAny:
	subroutine
	lda lpAny
	sta t0
	lda lpBeatCue
	sta lpAny
	ldx #LP_TRACKS-1
.t:
	lda trkSt,x
	beq .n
	cmp #LP_STOP
	beq .n
	inc lpAny
.n:
	dex
	bpl .t
	lda t0
	bne .x
	lda lpAny
	beq .x
	jsr GetTicks
	lda nowL
	sta lpAtL
	lda nowH
	sta lpAtH
	lda #0
	sta lpFrac
.x:
	rts

; dvd / A -> dvd, rem
DivA:
	sta dvsL
	lda #0
	sta dvsH
	jmp Div16

; BeatPlay, a step: the clock catches up, then has its 6 ticks
LoopBeat:
	subroutine
	lda lpAny               ; (resting: only the bar's phase, from the beat)
	bne .c
	sta lpRel
	beq .s
.c:
	lda lpRel
	beq .s
	dec lpRel
	jsr LoopStep
	jmp .c
.s:
	jsr LoopBusy            ; no loop going: the bar is the beat's
	bne .b
	lda beatStep
	and #15
	sta t0
	asl
	adc t0
	asl                     ; x 6
	sta lpPh
.b:
	lda lpAny
	beq .x
	lda #6
	sta lpRel
	lda nowL
	sta lpAtL
	lda nowH
	sta lpAtH
.x:
	rts

; RUN/STOP tapped, the beat stopped: it starts now, or at the loops' next bar
LoopBeatGo:
	subroutine
	jsr LoopBusy
	beq .now
	lda #1
	sta lpBeatCue
	sta lpDirty
	rts
.now:
	jmp BeatBegin

; Z clear if a track records, plays or overdubs
LoopBusy:
	subroutine
	ldx #LP_TRACKS-1
.t:
	lda trkSt,x
	cmp #LP_REC
	bcc .n
	cmp #LP_STOP
	bcc .y
.n:
	dex
	bpl .t
	lda #0
	rts
.y:
	lda #1
	rts

; one tick: bars start, every track plays what's at its tick
LoopStep:
	subroutine
	lda lpPh
	bne .p
	ldx #LP_TRACKS-1        ; a bar: cued tracks start, a cued beat starts
.cu:
	lda trkSt,x
	cmp #LP_CUED
	bne .cn
	lda #LP_PLAY
	sta trkSt,x
	jsr TrkRewind
.cn:
	dex
	bpl .cu
	lda lpBeatCue
	beq .bc
	lda #0
	sta lpBeatCue
	jsr BeatBegin
.bc:
	jsr LoopBusy
	beq .p
	inc lpDirty             ; (the bars count on screen)
.p:
	ldx #LP_TRACKS-1
.t:
	stx lpT
	lda trkSt,x
	cmp #LP_REC
	beq .inc                ; (the first take: its tick counts up)
	cmp #LP_PLAY
	beq .play
	cmp #LP_DUB
	bne .nx
.play:
	jsr TrkPlayNow
	ldx lpT
.inc:
	inc trkPosL,x
	bne .w
	inc trkPosH,x
.w:
	lda trkSt,x
	cmp #LP_REC
	bne .end
	lda trkPosH,x           ; (16 bars: the take ends itself)
	cmp #>(16*LP_BAR)
	bcc .nx
	jsr TrkFinish
	jmp .nx
.end:
	lda trkPosL,x           ; the end: round again
	cmp trkLenL,x
	lda trkPosH,x
	sbc trkLenH,x
	bcc .nx
	jsr TrkRewind
.nx:
	ldx lpT
	dex
	bpl .t
	inc lpPh
	lda lpPh
	cmp #LP_BAR
	bcc .x
	lda #0
	sta lpPh
.x:
	lda lpDirty
	beq .r
	lda #0
	sta lpDirty
	lda #1
	sta screenDirty
.r:
	rts

; track X from its start
TrkRewind:
	lda #0
	sta trkPosL,x
	sta trkPosH,x
	sta trkCur,x
	rts

; track lpT: its hits at its tick, played (not muted, not undone, not skipped)
TrkPlayNow:
	subroutine
	lda #0
	sta lpQn
.h:
	ldx lpT
	lda trkCur,x
	cmp trkCnt,x
	bcs .go
	jsr EvRead
	ldx lpT
	jsr EvCmpPos            ; C: the hit's tick >= the track's, Z: equal
	bcc .past
	bne .go
	inc trkCur,x
	lda evH
	and #$60
	beq .q
	and #$20                ; skip once: from next time round
	beq .h
	lda evH
	and #$DF
	jsr EvSetH
	jmp .h
.past:
	inc trkCur,x            ; (behind the loop: never mind)
	bne .h
.q:
	lda lpMute
	and bitT,x
	bne .h
	ldy lpQn
	cpy #8
	bcs .go
	lda evP
	sta lpQ,y
	inc lpQn
	bne .h
.go:
	ldy #0
.pl:
	cpy lpQn
	bcs .x
	sty lpI
	lda lpQ,y
	jsr PadPlayEv
	ldy lpI
	iny
	bne .pl
.x:
	rts

; evL / evH (the tick) against track X's tick: C set if >=, Z if equal
EvCmpPos:
	subroutine
	lda evH
	and #7
	cmp trkPosH,x
	bne .x
	lda evL
	cmp trkPosL,x
.x:
	rts

; ---- hits under the I/O (a moment at a time: MIDI in can't wait)
; A = hit of track lpT -> its 3 bytes in evL / evH / evP, ptr / Y at it
EvRead:
	subroutine
	jsr EvAddr
	jsr EvPeek
	sta evL
	iny
	jsr EvPeek
	sta evH
	iny
	jsr EvPeek
	sta evP
	dey
	dey
	rts
; A = a new evH for the hit at ptr / Y
EvSetH:
	iny
	jsr EvPoke
	dey
	rts
; A -> (ptr),y under the I/O (keeps A, Y)
EvPoke:
	php
	sei
	ldx #$34
	stx $01
	sta (ptr),y
	ldx #$35
	stx $01
	plp
	rts
; (ptr),y under the I/O -> A (keeps Y)
EvPeek:
	php
	sei
	ldx #$34
	stx $01
	lda (ptr),y
	ldx #$35
	stx $01
	plp
	rts
; A = hit of track lpT -> ptr = the track's region, Y = 3 x A
EvAddr:
	sta t0
	asl
	adc t0
	tay
	ldx lpT
	lda lpBaseLo,x
	sta ptr
	lda lpBaseHi,x
	sta ptr+1
	rts
lpBaseLo:   .byte <(LPEV+0*3*LP_HITS),<(LPEV+1*3*LP_HITS),<(LPEV+2*3*LP_HITS),<(LPEV+3*3*LP_HITS),<(LPEV+4*3*LP_HITS),<(LPEV+5*3*LP_HITS)
lpBaseHi:   .byte >(LPEV+0*3*LP_HITS),>(LPEV+1*3*LP_HITS),>(LPEV+2*3*LP_HITS),>(LPEV+3*3*LP_HITS),>(LPEV+4*3*LP_HITS),>(LPEV+5*3*LP_HITS)

; ---- recording: A = the hit, pad | kit << 4 | accent << 5 (PadPress)
LoopRec:
	subroutine
	sta nwP
	ldx lpSel
	stx lpT
	lda trkSt,x
	cmp #LP_ARMED
	bne .r
	; the first hit starts the take: with loops or a beat going, at the bar
	; it's nearest (just before the next bar line: that one, the hit on it);
	; nothing going: the bar starts here
	lda #LP_REC
	sta trkSt,x
	inc lpDirty
	lda #0
	sta trkCnt,x
	sta trkCur,x
	sta trkPosH,x
	jsr LoopBusyOther
	bne .near
	lda beatRun
	bne .near
	sta lpPh                ; (A = 0)
.near:
	lda lpPh
	sta trkPosL,x
	cmp #LP_BAR/2
	bcc .r
	sbc #LP_BAR             ; (C set: before the bar line, a negative tick)
	sta trkPosL,x
	dec trkPosH,x
.r:
	lda trkSt,x
	cmp #LP_REC
	beq .rec
	cmp #LP_DUB
	beq .rec
.x:
	rts
.rec:
	lda trkCnt,x
	cmp #LP_HITS
	bcs .x
	lda trkPosL,x
	sta nwL
	lda trkPosH,x
	sta nwH
	bpl .q
	lda #0                  ; (before the take's first bar line: on it)
	sta nwL
	sta nwH
.q:
	lda #0
	sta lpSk
	ldy lpQnt               ; QUANTIZE
	beq .ins
	lda lpQTick-1,y
	jsr Quantize
.ins:
	lda nwH
	and #7
	sta nwH
	lda trkSt,x
	cmp #LP_DUB
	bne .put
	lda nwL                 ; an overdub: this pass's, and skipped this time
	cmp trkPosL,x           ;  round if it's on or after where the loop is
	lda nwH
	sbc trkPosH,x
	lda #$80
	bcc .p2
	ora #$20
.p2:
	ora lpSk
	ora nwH
	sta nwH
.put:
	jmp EvInsert
lpQTick:    .byte 6,12

; Z clear if a track other than lpT plays (keeps X = lpT)
LoopBusyOther:
	subroutine
	ldx #LP_TRACKS-1
.t:
	cpx lpT
	beq .n
	lda trkSt,x
	cmp #LP_PLAY
	bcc .n
	cmp #LP_STOP
	bcc .y
.n:
	dex
	bpl .t
	ldx lpT
	lda #0
	rts
.y:
	ldx lpT
	lda #1
	rts

; nwL / nwH (a tick) to the nearest multiple of A; past an overdub's end: 0
Quantize:
	subroutine
	sta lpQd
	lda nwL
	sta dvdL
	lda nwH
	sta dvdH
	lda lpQd
	jsr DivA
	lda remL
	beq .x
	asl
	cmp lpQd
	bcc .back
	lda lpQd                ; up: + (q - r)
	sec
	sbc remL
	clc
	adc nwL
	sta nwL
	bcc .e
	inc nwH
.e:
	ldx lpT
	lda trkSt,x
	cmp #LP_DUB
	bne .x
	lda nwL
	cmp trkLenL,x
	lda nwH
	sbc trkLenH,x
	bcc .x
	lda #0
	sta nwL
	sta nwH
	lda #$20                ; (and not again just now)
	sta lpSk
	rts
.back:
	lda nwL
	sec
	sbc remL
	sta nwL
	bcs .x
	dec nwH
.x:
	ldx lpT
	rts

; the hit nwL / nwH / nwP into track lpT, after those on its tick or before
EvInsert:
	subroutine
	lda #0
	sta lpI
.f:
	ldx lpT
	lda lpI
	cmp trkCnt,x
	bcs .at
	jsr EvRead
	lda nwH
	and #7
	sta t1
	lda evH
	and #7
	cmp t1
	bne .c
	lda evL
	cmp nwL
	beq .n
.c:
	bcs .at
.n:
	inc lpI
	bne .f
.at:
	ldx lpT                 ; up 3: lpI to the end
	lda trkCnt,x
	jsr EvAddr
	lda lpI
	sta t0
	asl
	adc t0
	sta t2
.mv:
	cpy t2
	beq .put
	dey
	jsr EvPeek
	iny
	iny
	iny
	jsr EvPoke
	dey
	dey
	dey
	jmp .mv
.put:
	lda nwL
	jsr EvPoke
	iny
	lda nwH
	jsr EvPoke
	iny
	lda nwP
	jsr EvPoke
	ldx lpT
	inc trkCnt,x
	lda lpI                 ; before the next to play: the cursor past it
	cmp trkCur,x
	bcs .x
	inc trkCur,x
.x:
	rts

; hit lpI of track lpT out (down 3: the rest)
EvDelete:
	subroutine
	lda lpI
	jsr EvAddr
	ldx lpT
	lda trkCnt,x
	sta t0
	asl
	adc t0
	sta t2
.mv:
	iny
	iny
	iny
	cpy t2
	bcs .d
	jsr EvPeek
	dey
	dey
	dey
	jsr EvPoke
	iny
	bne .mv
.d:
	ldx lpT
	dec trkCnt,x
	lda lpI
	cmp trkCur,x
	bcs .x
	dec trkCur,x
.x:
	rts

; ---- the first take ends: its length, the hits past it to its start
TrkFinish:
	subroutine
	stx lpT
	lda trkPosL,x           ; bars = (tick + 48) / 96, 1-16
	clc
	adc #LP_BAR/2
	sta dvdL
	lda trkPosH,x
	adc #0
	bpl .p
	lda #0                  ; (stopped before its first bar line)
	sta dvdL
.p:
	sta dvdH
	lda #LP_BAR
	jsr DivA
	ldx dvdL
	bne .z
	inx
.z:
	cpx #17
	bcc .b
	ldx #16
.b:
	lda #0                  ; length = bars x 96
	sta t1
	stx t0
	txa
	ldx #5
.m:
	asl t0
	rol t1
	dex
	bne .m                  ; t0/t1 = bars x 32
	lda t0
	sta t2
	lda t1
	sta t3
	asl t0
	rol t1                  ; x 64
	ldx lpT
	lda t0
	clc
	adc t2
	sta trkLenL,x
	lda t1
	adc t3
	sta trkLenH,x
	lda trkPosH,x           ; (negative: the start)
	bpl .ov
	jsr TrkRewind
.ov:
	lda trkPosL,x           ; past the end (late): round again
	cmp trkLenL,x
	lda trkPosH,x
	sbc trkLenH,x
	bcc .w
	lda trkPosL,x
	sbc trkLenL,x
	sta trkPosL,x
	lda trkPosH,x
	sbc trkLenH,x
	sta trkPosH,x
.w:
	; the hits past the end, from the last: to their place from the start
	ldx lpT
	lda trkCnt,x
	beq .done
	sec
	sbc #1
	sta lpI
	jsr EvRead
	ldx lpT
	lda evH
	and #7
	sta nwH
	lda evL
	cmp trkLenL,x
	lda nwH
	sbc trkLenH,x
	bcc .done
	sta nwH
	lda evL
	sbc trkLenL,x           ; (C set)
	sta nwL
	lda evP
	sta nwP
	jsr EvDelete
	jsr EvInsert
	jmp .w
.done:
	ldx lpT                 ; the next to play: the first at or after its tick
	lda #0
	sta trkCur,x
.c:
	lda trkCur,x
	cmp trkCnt,x
	bcs .x
	jsr EvRead
	ldx lpT
	jsr EvCmpPos
	bcs .x
	inc trkCur,x
	bne .c
.x:
	lda #LP_PLAY
	sta trkSt,x
	rts

; ---- an overdub begins: the last one kept (its undone hits gone), unmarked
TrkCommit:
	subroutine
	stx lpT
	lda trkCnt,x
	sta lpI
.h:
	dec lpI
	bmi .x
	lda lpI
	jsr EvRead
	lda evH
	bpl .h
	and #$40
	beq .k
	jsr EvDelete
	jmp .h
.k:
	lda evH
	and #$7F
	jsr EvSetH
	jmp .h
.x:
	ldx lpT
	lda #0
	sta trkUndo,x
	rts

; <-: the last overdub undone, or back
TrkUndo:
	subroutine
	ldx lpSel
	stx lpT
	lda trkUndo,x
	beq .x
	eor #3                  ; (1 kept, 2 undone)
	sta trkUndo,x
	lda trkCnt,x
	sta lpI
.h:
	dec lpI
	bmi .d
	lda lpI
	jsr EvRead
	lda evH
	bpl .h
	eor #$40
	jsr EvSetH
	jmp .h
.d:
	inc lpDirty
.x:
	rts

; ---- the buttons: X = track
LoopButton:
	subroutine
	stx lpSel
	stx lpT
	inc lpDirty
	jsr GetTicks
	cpx lpTapK              ; twice within LP_TAP ms: stop
	bne .one
	lda nowL
	sec
	sbc lpTapL
	tay
	lda nowH
	sbc lpTapH
	bne .one
	cpy #LP_TAP
	bcs .one
	lda #$FF
	sta lpTapK
	jmp LoopStopX
.one:
	stx lpTapK
	lda nowL
	sta lpTapL
	lda nowH
	sta lpTapH
	lda trkSt,x
	beq .arm                ; EMPTY: armed
	cmp #LP_ARMED
	beq .empty
	cmp #LP_REC
	bne .pl
	jmp TrkFinish
.pl:
	cmp #LP_PLAY
	bne .db
	jsr TrkCommit           ; PLAY: overdub
	lda #LP_DUB
	bne .set
.db:
	cmp #LP_DUB
	bne .st
	lda #1                  ; DUB: play, the pass undoable
	sta trkUndo,x
	lda #LP_PLAY
	bne .set
.st:
	cmp #LP_STOP
	bne .cu
	lda #LP_CUED            ; STOP: from the next bar
	bne .set
.cu:
	lda #LP_STOP            ; CUED: never mind
	bne .set
.arm:
	jsr LoopFinishRec       ; (one take at a time)
	ldx lpT
	lda #LP_ARMED
	bne .set
.empty:
	lda #LP_EMPTY
.set:
	sta trkSt,x
	rts

; any take recording ends (its length set)
LoopFinishRec:
	subroutine
	ldx #LP_TRACKS-1
.t:
	lda trkSt,x
	cmp #LP_REC
	bne .n
	stx lpT2
	jsr TrkFinish
	ldx lpT2
.n:
	dex
	bpl .t
	rts

; F7: track X stops (a stopped one: cleared); SHIFT + F7: all stop
LoopStopKey:
	subroutine
	inc lpDirty
	lda shiftDown
	beq .one
	ldx #LP_TRACKS-1
.a:
	stx lpT2
	lda trkSt,x
	cmp #LP_STOP
	beq .n
	jsr LoopStopX
.n:
	ldx lpT2
	dex
	bpl .a
	rts
.one:
	ldx lpSel
	lda trkSt,x
	cmp #LP_STOP
	bne LoopStopX
	lda #0                  ; cleared
	sta trkCnt,x
	sta trkUndo,x
	sta trkSt,x
	rts
LoopStopX:
	subroutine
	stx lpT
	lda trkSt,x
	beq .x
	cmp #LP_ARMED
	beq .e
	cmp #LP_REC
	bne .s
	jsr TrkFinish
	ldx lpT
.s:
	lda #LP_STOP
	sta trkSt,x
	inc lpDirty
.x:
	rts
.e:
	lda #LP_EMPTY
	sta trkSt,x
	rts

; ---- the tracks on the sampler's screen (rows 16-21)
LP_ROW      equ 16
LoopRows:
	subroutine
	ldx #LP_TRACKS-1
.t:
	stx lpT
	txa
	clc
	adc #LP_ROW
	tay
	ldx #0
	jsr ScreenAddr
	ldy #39
	lda #32
.c:
	sta (ptr2),y
	dey
	bpl .c
	ldx #0
	lda lpT
	cmp lpSel
	bne .n
	lda #'>
	jsr PutChar
.n:
	inx
	lda lpT
	clc
	adc #'1
	jsr PutChar
	ldx lpT                 ; its state
	lda trkSt,x
	asl
	sta t0
	asl
	adc t0                  ; x 6
	adc #<lpWords
	ldy #>lpWords
	bcc .w
	iny
.w:
	ldx #3
	jsr PutStr
	ldx lpT
	lda trkSt,x
	cmp #LP_PLAY
	bcc .nx
	lda trkLenL,x           ; its bars, and the one it's in
	sta dvdL
	lda trkLenH,x
	sta dvdH
	lda #LP_BAR
	jsr DivA
	lda dvdL
	ldx #10
	jsr PutNum
	inx
	lda #<txtBars
	ldy #>txtBars
	jsr PutStr
	ldx lpT
	lda trkPosL,x
	sta dvdL
	lda trkPosH,x
	sta dvdH
	lda #LP_BAR
	jsr DivA
	ldx #19
	lda #<txtBar
	ldy #>txtBar
	jsr PutStr
	lda dvdL
	clc
	adc #1
	jsr PutNum
.nx:
	ldx lpT
	lda lpMute
	and bitT,x
	beq .um
	ldx #27
	lda #<txtLpMute
	ldy #>txtLpMute
	jsr PutStr
.um:
	ldx lpT
	lda trkUndo,x
	cmp #2
	bne .nu
	ldx #32
	lda #<txtUndone
	ldy #>txtUndone
	jsr PutStr
.nu:
	ldx lpT
	dex
	bmi .x
	jmp .t
.x:
	rts
; a state's word (LP_EMPTY ... LP_CUED), 6 bytes each
lpWords:    .byte "-----",0,"ARMED",0,"REC  ",0,"PLAY ",0,"DUB  ",0,"STOP ",0,"CUED ",0
txtBars:    .byte "BARS",0
txtBar:     .byte "BAR ",0
txtLpMute:  .byte "MUTE",0
txtUndone:  .byte "UNDONE",0
