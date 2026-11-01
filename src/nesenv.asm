; Fat Chip 64 - MidiNES envelopes (PADS sound)
;
; The NES Lab (2026-11-01) showed CC7 changes the volume of a sounding note,
; so in PADS the NES pulses get a software envelope: CC7 to 0, note-on, then
; CC7 stepped through the NES's 16 levels on a 10 ms clock:
;   attack 0.6 s to 15, decay 0.4 s to 11, sustain 11, release 2 s to 0
; (Reeve's Lab settings). The note-off waits until the release reaches 0.
; (Off in PADS since v0.09: kept for a future mono bass synth sound.)
; The triangle has no volume, so its release is a pitch drop (Reeve's
; plugin trick): -24 semitones over 250 ms, slow at first, a bend every
; 4 ms (8 ms while the Game Boy is on), then the note-off and the bend back to centre. The drop stops at
; the triangle's lowest note (MIDI 21: its 11-bit timer can't go lower and
; would wrap to a high pitch).
; FAT sound: no envelopes (CC7 full). Mute, panic and device off cut at once.

ENV_ATK     equ 64              ; 8.8 level per 10 ms: 15 levels in 0.6 s
ENV_DEC     equ 26              ; 4 levels (15 -> 11) in 0.4 s
ENV_SUS     equ 11
TRI_GAP     equ 4               ; ms between drop bends (Reeve: 4 ms is smoothest)
TRI_GAP_GB  equ 8               ; while the Game Boy is on: its adapter forwards the
                                ; NES channels too, and can't take a bend every 4 ms
TRI_FLOOR   equ 21              ; lowest triangle note
TRI_DROP_PADS equ 0             ; the drop is for a future mono bass sound, not PADS

; voice -> envelope slot (NES pulse 1 = v2, pulse 2 = v5)
vEnvSlot:   .byte $FF,$FF,0, $FF,$FF,1, $FF,$FF,$FF
slotVoice:  .byte 2,5

; VoiceSet, a NES voice going silent: C set if a soft release took over (the
; note keeps sounding for now). X = voice (= t0).
NesSoftRelease:
	subroutine
	lda padSound
	beq .no
	lda muteNow
	ora hardCut
	bne .no
	lda devOn+DEV_NES
	beq .no
	lda vDev,x
	cmp #DEV_NES
	bne .no
	lda vOut,x
	cmp #NO_NOTE
	beq .no
	ldy vEnvSlot,x
	bmi .tri
	; pulse: release from the current level; step = 1.25 x level + 1 (8.8),
	; so any level fades out in about 2 s
	lda envLvH,y
	lsr
	lsr
	sta envRel,y
	lda envLvH,y
	clc
	adc envRel,y
	adc #1
	sta envRel,y
	lda #ENV_R
	sta envPh,y
	sec
	rts
.tri:
	if TRI_DROP_PADS == 0
	jmp .no                 ; PADS: the bass just stops (Reeve, 2026-11-01)
	endif
	lda vIdx,x
	cmp #2
	bne .no
	lda vOut,x
	jsr MidiNoteValue       ; the note actually sounding
	cmp #TRI_FLOOR+1
	bcc .no                 ; already at the bottom: just cut
	sta triNote
	lda #0
	sta triK
	jsr GetTicks
	lda nowL
	sta triLast
	sta triStart
	lda nowH
	sta triStart+1
	lda #1
	sta triOn
	sec
	rts
.no:
	clc
	rts

; MidiTo hooks (voice t0, channel t1).
; Before its note-off: nothing. After its note-off:
NesAfterOff:
	subroutine
	ldx t0
	lda vDev,x
	cmp #DEV_NES
	bne .x
	ldy vEnvSlot,x
	bmi .tri
	lda #ENV_IDLE
	sta envPh,y
	rts
.tri:
	lda vIdx,x
	cmp #2
	bne .x
	lda triOn
	beq .x
	lda #0
	sta triOn
	lda t1                  ; bend back to centre for the next note
	ora #$E0
	sta mS
	lda #0
	sta mD1
	lda #$40
	sta mD2
	jmp NesPut
.x:
	rts

; Before its note-on: in PADS a NES pulse starts from volume 0 and attacks.
NesBeforeOn:
	subroutine
	lda padSound
	beq .x
	ldx t0
	lda vDev,x
	cmp #DEV_NES
	bne .x
	ldy vEnvSlot,x
	bmi .x
	lda #ENV_A
	sta envPh,y
	lda #0
	sta envLvL,y
	sta envLvH,y
	sta envSent,y
	lda t1
	ora #$B0
	sta mS
	lda #7
	sta mD1
	lda #0
	sta mD2
	jmp NesPut
.x:
	rts

; Main loop, every pass.
NesEnvTick:
	subroutine
	lda devOn+DEV_NES
	bne .on
	lda #ENV_IDLE           ; NES off: forget everything (it got CC 123)
	sta envPh
	sta envPh+1
	sta triOn
	rts
.on:
	lda ticks
	sec
	sbc envLast
	cmp #10
	bcc .tri
	lda ticks
	sta envLast
	ldy #0
	jsr EnvStep
	ldy #1
	jsr EnvStep
.tri:
	lda triOn
	beq .x
	ldx #TRI_GAP
	lda devOn+DEV_GB
	beq .g
	ldx #TRI_GAP_GB
.g:
	stx t2
	lda ticks
	sec
	sbc triLast
	cmp t2
	bcc .x
	; the drop's time is fixed at 250 ms: k follows the clock, so a slower
	; bend rate skips steps instead of stretching the drop
	jmp TriStep
.x:
	rts

; envelope slot Y, one 10 ms step
EnvStep:
	subroutine
	sty envY
	lda envPh,y
	bne .go
	rts
.go:
	cmp #ENV_A
	bne .d
	lda envLvL,y
	clc
	adc #ENV_ATK
	sta envLvL,y
	lda envLvH,y
	adc #0
	sta envLvH,y
	cmp #15
	bcc .send
	lda #15
	sta envLvH,y
	lda #0
	sta envLvL,y
	lda #ENV_D
	sta envPh,y
	bne .send
.d:
	cmp #ENV_D
	bne .r
	lda envLvL,y
	sec
	sbc #ENV_DEC
	sta envLvL,y
	lda envLvH,y
	sbc #0
	sta envLvH,y
	cmp #ENV_SUS
	bcs .send
	lda #ENV_SUS
	sta envLvH,y
	lda #0
	sta envLvL,y
	lda #ENV_S
	sta envPh,y
	bne .send
.r:
	cmp #ENV_R
	bne .x                  ; sustain: nothing to do
	lda envLvL,y
	sec
	sbc envRel,y
	sta envLvL,y
	lda envLvH,y
	sbc #0
	sta envLvH,y
	bcc .end                ; below 0
	bne .send
.end:
	; faded out: CC7 0, then the held-back note-off (MidiTo sends it and
	; sets the slot idle)
	lda #0
	sta envLvH,y
	sta envLvL,y
	jsr .cc7
	ldy envY
	lda slotVoice,y
	sta t0
	lda #NO_NOTE
	jmp MidiTo
.send:
	lda envLvH,y
	cmp envSent,y
	beq .x
	sta envSent,y
.cc7:
	; CC7 = level x 8 on this pulse's channel
	ldy envY
	lda slotVoice,y
	tax
	lda vIdx,x
	clc
	adc nesBase
	and #15
	ora #$B0
	sta mS
	lda #7
	sta mD1
	lda envLvH,y
	asl
	asl
	asl
	sta mD2
	jmp NesPut
.x:
	rts

; triangle drop: one step
TriStep:
	subroutine
	; step = ms since the drop began / 5 (50 steps = 250 ms). 16-bit time,
	; so a late check can't wrap round and restart the drop.
	jsr GetTicks
	lda nowL
	sta triLast
	sec
	sbc triStart
	sta t2
	lda nowH
	sbc triStart+1
	beq .short
.over:
	; time's up: make sure the last step (the full drop) was sent, then end
	lda triK
	cmp #TRI_STEPS
	bcc .last
	jmp .done
.last:
	ldx #TRI_STEPS
	jmp .q
.short:
	lda t2
	cmp #TRI_STEPS*5
	bcs .over
	ldx #0
.div:
	cmp #5
	bcc .q
	sbc #5
	inx
	bne .div
.q:
	cpx triK
	bne .new
	rts                     ; same step as last time
.new:
	stx triK
	lda triK
	cmp #TRI_STEPS+1
	bcc .more
	jmp .done
.more:
	; past the floor? drop (in 1/8 semitones) > (note - 21) x 8
	lda triNote
	sec
	sbc #TRI_FLOOR
	cmp #32
	bcs .ok                 ; 32+ semitones of room: never reached
	asl
	asl
	asl
	ldx triK
	cmp triDropS8,x
	bcs .ok
	jmp .done
.ok:
	; bend = 8192 - (p(note) x h(k)) / 1024, in steps of 4
	ldx triNote
	lda triPbLo,x
	sta mulA
	lda triPbHi,x
	sta mulA+1
	ldx triK
	lda triDropHLo,x
	sta mulB
	lda triDropHHi,x
	sta mulB+1
	jsr Mul16               ; mulR (32 bits)
	; >> 10: take bytes 1-2, shift right twice
	lda mulR+2
	sta t2
	lda mulR+1
	lsr t2
	ror
	lsr t2
	ror
	and #$FC
	sta t3                  ; t2:t3 = drop (hi:lo)
	lda mulR+3
	bne .floor              ; way past the range
	lda #0
	sec
	sbc t3
	sta t3
	lda #$20                ; 8192 = $2000
	sbc t2
	bcc .floor              ; past -8192: hold at the bottom of the range
	sta t2
	jmp .send
.floor:
	lda #0
	sta t2
	sta t3
.send:
	; 14-bit bend t2:t3 -> LSB 7 bits, MSB 7 bits
	ldx #8                  ; NES triangle = v8
	lda vIdx,x
	clc
	adc nesBase
	and #15
	ora #$E0
	sta mS
	lda t3
	and #$7F
	sta mD1
	lda t3
	asl
	lda t2
	rol
	sta mD2
	jmp NesPut
.done:
	; drop finished (or at the floor): the note-off, then the bend back
	; to centre (MidiTo -> NesAfterOff)
	lda #8
	sta t0
	lda #NO_NOTE
	jmp MidiTo

; mulR (32 bits) = mulA x mulB (16 x 16, unsigned)
Mul16:
	subroutine
	lda #0
	sta mulR+2
	sta mulR+3
	ldx #16
.l:
	lsr mulB+1
	ror mulB
	bcc .n
	lda mulR+2
	clc
	adc mulA
	sta mulR+2
	lda mulR+3
	adc mulA+1
	sta mulR+3
.n:
	ror mulR+3
	ror mulR+2
	ror mulR+1
	ror mulR
	dex
	bne .l
	rts

; Sound switched (V): leaving PADS ends any NES envelope at once and puts the
; pulses back at full volume.
NesSoundApply:
	subroutine
	lda padSound
	bne .x
	jsr NesCutAll
	jmp NesFullVolume
.x:
	rts

; Cut every NES voice that is fading (release) or dropping: note-off now.
NesCutAll:
	subroutine
	lda #0
	sta t3
.s:
	ldy t3
	lda envPh,y
	cmp #ENV_R
	bne .idle
	lda slotVoice,y         ; releasing: cut it now
	sta t0
	lda #NO_NOTE
	jsr MidiTo
.idle:
	ldy t3
	lda #ENV_IDLE
	sta envPh,y
	inc t3
	lda t3
	cmp #2
	bne .s
	lda triOn
	beq .r
	lda #8
	sta t0
	lda #NO_NOTE
	jmp MidiTo
.r:
	rts

; NES pulses back to full volume (CC7 127)
NesFullVolume:
	subroutine
	lda devOn+DEV_NES
	beq .x
	lda #7
	sta mD1
	lda #127
	sta mD2
	lda nesBase
	ora #$B0
	sta mS
	jsr NesPut
	lda nesBase
	clc
	adc #1
	and #15
	ora #$B0
	sta mS
	jmp NesPut
.x:
	rts

; Panic: cut anything still fading or dropping (note-off now), then forget
NesEnvReset:
	jsr NesCutAll
	lda #ENV_IDLE
	sta envPh
	sta envPh+1
	sta triOn
	rts
