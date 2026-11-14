; Fat Chip 64 - editing the live patch (v0.24): the menu's PATCH pages and
; the dice. The settings and their steps come from tools/gen_menu.py
; (menutab.asm): each step of a setting writes a few live patch bytes
; (field, mask, value), and one "key" byte (or two) tells which step a patch
; is on. The Game Boy's one LFO belongs to VIBRATO when it's on, else PWM
; (LfoFix); the envelope's Game Boy and NES parts follow its SID nibbles
; (EnvDerive).

LFO_FIRST   equ FLD_gbLDest
LFO_LAST    equ FLD_gbLDelay

; X = param -> A = the step the live patch is nearest to
ParamNearest:
	subroutine
	stx pnP
	ldy prKey,x
	lda livePatch,y
	and prKeyM,x
	sta pnVL
	lda #0
	sta pnVH
	ldy prKeyH,x
	cpy #$FF
	beq .h
	lda livePatch,y
	sta pnVH
.h:
	lda prKLo,x
	sta .kl+1
	sta .kh+1
	lda prKHi,x
	sta .kl+2
	sta .kh+2
	inc .kh+1               ; (the high byte: one on)
	bne .k1
	inc .kh+2
.k1:
	lda prN,x
	sta pnN
	lda #$FF
	sta pnBL
	sta pnBH
	lda #0
	sta pnI
	sta pnBI
.l:
	lda pnI
	asl
	tay
	sec
	lda pnVL
.kl:
	sbc $FFFF,y
	sta pnDL
	lda pnVH
.kh:
	sbc $FFFF,y
	sta pnDH
	bcs .pos
	lda pnDL                ; |difference|
	eor #$FF
	clc
	adc #1
	sta pnDL
	lda pnDH
	eor #$FF
	adc #0
	sta pnDH
.pos:
	lda pnDH
	cmp pnBH
	bcc .better
	bne .nb
	lda pnDL
	cmp pnBL
	bcs .nb
.better:
	lda pnDL
	sta pnBL
	lda pnDH
	sta pnBH
	lda pnI
	sta pnBI
.nb:
	inc pnI
	lda pnI
	cmp pnN
	bne .l
	ldx pnP
	lda pnBI
	rts

; X = param, A = step: its bytes into the live patch. peMode: 0 all, 1 only
; the GB LFO's, 2 all but the GB LFO's.
ParamWrite:
	subroutine
	sta peS
	stx peQ
	lda prWLo,x
	sta .f+1
	lda prWHi,x
	sta .f+2
	lda prNW,x
	sta peN
	asl
	clc
	adc peN
	sta peRow               ; bytes a step
	ldy peS
	beq .w
.m:
	lda .f+1
	clc
	adc peRow
	sta .f+1
	bcc .mc
	inc .f+2
.mc:
	dey
	bne .m
.w:
	lda .f+1                ; (mask and value: the next two)
	sta .mk+1
	sta .vl+1
	lda .f+2
	sta .mk+2
	sta .vl+2
	inc .mk+1
	bne .w1
	inc .mk+2
.w1:
	lda .vl+1
	clc
	adc #2
	sta .vl+1
	bcc .w2
	inc .vl+2
.w2:
	ldy #0
.e:
	cpy peRow
	beq .x
.f:
	ldx $FFFF,y             ; the field
	lda peMode
	beq .wr
	cpx #LFO_FIRST
	bcc .notl
	cpx #LFO_LAST+1
	bcs .notl
	cmp #2                  ; an LFO byte
	beq .skip
	bne .wr
.notl:
	cmp #1
	beq .skip
.wr:
.mk:
	lda $FFFF,y
	eor #$FF
	and livePatch,x
.vl:
	ora $FFFF,y
	sta livePatch,x
.skip:
	iny
	iny
	iny
	bne .e
.x:
	ldx peQ
	rts

; X = effect -> A = 1 if it's on (Z clear), 0 if off
FxIsOn:
	subroutine
	lda efAlways,x
	bne .on
	lda efOffLo,x
	sta .f+1
	sta .v+1
	lda efOffHi,x
	sta .f+2
	sta .v+2
	inc .v+1
	bne .v1
	inc .v+2
.v1:
	lda efOffN,x
	asl
	sta peN
	ldy #0
.l:
	cpy peN
	beq .off
.f:
	lda $FFFF,y
	stx peE
	tax
	lda livePatch,x
	ldx peE
.v:
	cmp $FFFF,y
	bne .on
	iny
	iny
	bne .l
.off:
	lda #0
	rts
.on:
	lda #1
	rts

; X = effect: write its (field, value) list at (efOn or efOff), count A
FxPairs:
	subroutine
	asl
	sta peN
	ldy #0
.l:
	cpy peN
	beq .x
FxPairsF:
	lda $FFFF,y
	tax
	iny
FxPairsV:
	lda $FFFF,y
	sta livePatch,x
	iny
	bne .l
.x:
	rts

; X = effect: on, every setting at its default
FxOn:
	subroutine
	stx peE
	lda efOnLo,x
	sta FxPairsF+1
	sta FxPairsV+1
	lda efOnHi,x
	sta FxPairsF+2
	sta FxPairsV+2
	lda efOnN,x
	jsr FxPairs
	ldx peE
	lda efP0,x
	sta peP
	lda efNP,x
	sta peCnt
.p:
	lda peCnt
	beq .d
	ldx peE
	jsr FxMode
	ldx peP
	lda prDef,x
	jsr ParamWrite
	inc peP
	dec peCnt
	bne .p
.d:
	ldx peE
	jmp FxLfo

; X = effect: off
FxOff:
	subroutine
	stx peE
	lda efOffLo,x
	sta FxPairsF+1
	sta FxPairsV+1
	lda efOffHi,x
	sta FxPairsF+2
	sta FxPairsV+2
	lda efOffN,x
	jsr FxPairs
	ldx peE
	jmp FxLfo

; X = effect: peMode for writing its settings (PWM leaves the LFO to LfoFix)
FxMode:
	subroutine
	lda #0
	cpx #FX_PWM
	bne .m
	ldx #FX_VIB             ; (v0.34: only while VIBRATO has the LFO; otherwise
	jsr FxIsOn              ;  PWM's SHAPE is the LFO's and must be written)
	ldx #FX_PWM
	cmp #0
	beq .m
	lda #2
.m:
	sta peMode
	rts

; X = effect: VIBRATO or PWM changed: the LFO's owner again
FxLfo:
	cpx #FX_VIB
	beq LfoFix
	cpx #FX_PWM
	beq LfoFix
	rts

; the Game Boy LFO: VIBRATO's if it's on, else PWM's, else off
LfoFix:
	subroutine
	ldx #FX_VIB
	jsr FxIsOn
	bne .own
	ldx #FX_PWM
	jsr FxIsOn
	bne .own
	lda #0
	ldx #LFO_LAST-LFO_FIRST
.z:
	sta livePatch+LFO_FIRST,x
	dex
	bpl .z
	rts
.own:
	stx peE
	lda efOnLo,x            ; its on row (the LFO's destination)
	sta FxPairsF+1
	sta FxPairsV+1
	lda efOnHi,x
	sta FxPairsF+2
	sta FxPairsV+2
	lda efOnN,x
	jsr FxPairs
	ldx peE
	lda efP0,x
	sta peP
	lda efNP,x
	sta peCnt
.p:
	ldx peP
	jsr ParamNearest
	ldx #1
	stx peMode              ; (only the LFO's bytes)
	ldx peP
	jsr ParamWrite
	inc peP
	dec peCnt
	bne .p
	rts

; the envelope's Game Boy and NES parts from the SID's attack, decay,
; sustain and release nibbles (tables for levels 15)
EnvDerive:
	subroutine
	lda livePatch+FLD_sndAD
	lsr
	lsr
	lsr
	lsr
	sta pnI                 ; attack
	lda livePatch+FLD_sndAD
	and #15
	sta pnN                 ; decay
	lda livePatch+FLD_sndSR
	lsr
	lsr
	lsr
	lsr
	sta pnBI                ; sustain
	lda livePatch+FLD_sndSR
	and #15
	sta pnP                 ; release
	ldx pnI
	lda edGbAtk,x
	sta livePatch+FLD_gbAtk
	ldx pnN
	lda edGbDec,x
	ldy pnBI
	cpy #8
	bcc .gd
	lda #0                  ; (sustain 8+: the Game Boy holds)
.gd:
	sta livePatch+FLD_gbDec
	ldx pnP
	lda edGbRel,x
	sta livePatch+FLD_gbRel
	lda pnI                 ; the NES: flat (no envelope) when instant, full, instant
	ora pnP
	bne .ne
	lda pnBI
	cmp #15
	bne .ne
	lda #0
	sta livePatch+FLD_nesEnv
	sta livePatch+FLD_nesAtk
	sta livePatch+FLD_nesDec
	sta livePatch+FLD_nesRel
	lda #15
	sta livePatch+FLD_nesSus
	rts
.ne:
	lda #1
	sta livePatch+FLD_nesEnv
	ldx pnI
	lda edNesAtk,x
	sta livePatch+FLD_nesAtk
	ldx pnP
	lda edNesRel,x
	sta livePatch+FLD_nesRel
	ldx pnBI
	lda edNesSus,x
	sta livePatch+FLD_nesSus
	txa                     ; decay: [sustain x 16 + decay]
	asl
	asl
	asl
	asl
	ora pnN
	tax
	lda edNesDec,x
	sta livePatch+FLD_nesDec
	rts

; X = param, A = step: set it (its effect goes on first if it's off), heard at once
ParamSet:
	subroutine
	sta peSet
	stx peSP
	lda prFx,x
	tax
	stx peSE
	jsr FxIsOn
	bne .on
	ldx peSE
	jsr FxOn
.on:
	ldx peSE
	jsr FxMode
	ldx peSP
	lda peSet
	jsr ParamWrite
	ldx peSP
	lda prFlags,x
	and #1
	beq .ne
	jsr EnvDerive
.ne:
	ldx peSE
	jsr FxLfo
	jsr MarkEdited
	ldx peSP
	lda prFlags,x
	and #2
	beq .r
	jmp PatchApply          ; (MONO, FAT BASS: the notes start again)
.r:
	jmp PatchRefresh

; X = effect: on <-> off, heard at once
FxToggle:
	subroutine
	stx peSE
	jsr FxIsOn
	beq .on
	ldx peSE
	jsr FxOff
	jmp .d
.on:
	ldx peSE
	jsr FxOn
.d:
	jsr MarkEdited
	jmp PatchRefresh

; A = a random step of param X in its dice range. Keeps X.
ParamRoll:
	subroutine
	stx peQ
	lda prRHi,x
	sec
	sbc prRLo,x
	clc
	adc #1
	sta peN                 ; how many
	jsr Random
.mod:
	cmp peN
	bcc .ok
	sbc peN
	bcs .mod
.ok:
	ldx peQ
	clc
	adc prRLo,x
	rts

; SHIFT + / in the menu, on a patch setting X: roll just it
ParamDice:
	subroutine
	stx peSP
	jsr SaveUndo
	ldx peSP
	jsr ParamRoll
	ldx peSP
	jmp ParamSet

; SHIFT + /: roll the patch. Each effect the dice use (efDice) goes on with
; its chance, its settings anywhere in their dice ranges; or off. The tone,
; envelope, levels and octaves stay. The name gets a *. C= + / undoes it.
DiceRoll:
	subroutine
	jsr SaveUndo
	ldx #0
.e:
	stx dcE
	lda efDice,x
	beq .next
	jsr Random
	ldx dcE
	cmp efProb,x
	bcs .off
	jsr FxOn
	ldx dcE
	lda efP0,x
	sta dcP
	lda efNP,x
	sta dcN
.p:
	ldx dcE
	jsr FxMode
	ldx dcP
	jsr ParamRoll
	jsr ParamWrite
	inc dcP
	dec dcN
	bne .p
	jmp .next
.off:
	jsr FxOff
.next:
	ldx dcE
	inx
	cpx #NUM_FX
	bne .e
	jsr LfoFix
	jsr MarkEdited
	jmp PatchApply

; the live patch, for C= + /
SaveUndo:
	subroutine
	ldy #127
.u:
	lda livePatch,y
	sta diceUndo,y
	dey
	bpl .u
	lda #1
	sta undoOk
	rts

; the patch was changed here: a * at the end of its name
MarkEdited:
	lda #"*"
	sta patchName+NAME_LEN-1
	rts

; the live patch changed, notes keep sounding: the settings follow
PatchRefresh:
	jsr SoundVars
	jsr SoundApply
	jmp Dirty
