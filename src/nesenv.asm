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

; v0.12: the envelope comes from the sound (envAtkV, envDecV, envSusV,
; envPeakV, envRelV; PADS keeps 64 / 26 / 11 / 15 / 5), every sound but FAT
; and RAW uses it (it also sets the pulses' loudness), and the sound may add
; a tremolo: the level sent is level - level x amount / 16, the amount
; following a triangle (or square) LFO on the 10 ms clock, both pulses in step.
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
	jmp .go
.nope:
	clc
	rts
.go:
	lda muteNow
	ora hardCut
	bne .nope
	lda devOn+DEV_NES
	beq .nope
	lda vDev,x
	cmp #DEV_NES
	bne .nope
	lda vOut,x
	cmp #NO_NOTE
	beq .nope
	lda nesEnvOn
	beq .fo                 ; (no envelope: BEND OUT's fall-off, if any)
	ldy vEnvSlot,x
	bmi .tri
	; pulse: release from the current level; step = level x factor / 4 + 1
	; (8.8 per 10 ms), so any level fades out in 10.24 s / factor (PADS: 5,
	; about 2 s). Factor 0: no release, cut.
	lda envRelV
	beq .fo
	stx t2
	sty t3
	lda envLvH,y
	ldy envRelV
	jsr Mul8
	lsr mt16+1
	ror mt16
	lsr mt16+1
	ror mt16
	ldy t3
	ldx t2
	lda mt16+1
	bne .max
	lda mt16
	cmp #255
	bcs .max
	adc #1
	bne .rel
.max:
	lda #255
.rel:
	sta envRel,y
	lda #ENV_R
	sta envPh,y
	jsr RdBend              ; BEND OUT: it sags as it fades
	sec
	rts
.tri:
	if TRI_DROP_PADS == 0
	jmp .fo                 ; PADS: the bass just stops (Reeve, 2026-11-01)
	endif
	lda vIdx,x
	cmp #2
	bne .no
	lda vSent,x             ; the note actually sounding
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
; BEND OUT with no fade to bend in: a fall-off (the note holds for TIME as
; it falls, then stops)
.fo:
	lda nesRdrop
	beq .no
	lda sndRdropT
	beq .no
	sta nesFoT,x
	inc foAny
	jsr RdBend
	sec
	rts
.no:
	clc
	rts

; NES voice X let go: BEND OUT's drop (the glide eases it in: nesRd + the
; glide offset start at 0 and end at -amount). Keeps X.
RdBend:
	subroutine
	lda nesRdrop
	beq .x
	sta nesGlH,x
	lda #0
	sta nesGlL,x
	sec
	sbc nesRdrop
	sta nesRd,x
	lda sndRdropK
	sta nesK,x
	lda #1
	sta nfxGlide
.x:
	rts

; MidiTo hooks (voice t0, channel t1).
; Before its note-off: nothing. After its note-off:
NesAfterOff:
	subroutine
	ldx t0
	lda vDev,x
	cmp #DEV_NES
	bne .x
	lda #0                  ; (BEND OUT done: no drop, no fall-off)
	sta nesRd,x
	sta nesFoT,x
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
	sta nesBent,x           ; (nesfx.asm: centred now)
	sta nesFxSL,x
	sta nesFxSH,x
	sta nesTotL,x
	sta nesTotH,x
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
	lda nesEnvOn
	beq .x
	ldx t0
	lda vDev,x
	cmp #DEV_NES
	bne .x
	ldy vEnvSlot,x
	bmi .x
	lda #0
	sta envLvL,y
	sta envLvH,y
	lda #ENV_A
	ldx envAtkV
	bne .ph
	lda envPeakV            ; no attack: straight to the peak
	sta envLvH,y
	lda #ENV_D
.ph:
	sta envPh,y
	sty envY
	jsr TremLevel
	ldy envY
	sta envSent,y
	asl
	asl
	asl
	sta mD2                 ; CC7 = level x 8
	lda t1
	ora #$B0
	sta mS
	lda #7
	sta mD1
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
	lda ticks               ; (the tremolo still runs, for the SID)
	sec
	sbc envLast
	cmp #10
	bcc .r
	lda ticks
	sta envLast
	jmp TremTick
.r:
	rts
.on:
	lda ticks
	sec
	sbc envLast
	cmp #10
	bcc .tri
	cmp #40
	bcs .resync             ; far behind: start the clock again from now
	lda envLast             ; on a steady 10 ms clock (a slow loop pass
	clc                     ;  doesn't stretch the envelope)
	adc #10
	bne .clk
.resync:
	lda ticks
.clk:
	sta envLast
	jsr TremTick
	ldy #0
	jsr EnvStep
	ldy #1
	jsr EnvStep
	lda foAny
	beq .tri
	jsr FoStep
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

; BEND OUT's fall-offs, one 10 ms step: a voice's time up, its note-off
FoStep:
	subroutine
	lda #0
	sta foAny
	ldx #2
.v:
	lda nesFoT,x
	beq .n
	dec nesFoT,x
	bne .on
	stx t0                  ; time's up: the note-off (MidiTo -> NesAfterOff)
	lda #NO_NOTE
	jsr MidiTo
	ldx t0
	jmp .n
.on:
	inc foAny
.n:
	inx
	inx
	inx
	cpx #NUM_VOICES
	bcc .v
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
	adc envAtkV
	sta envLvL,y
	lda envLvH,y
	adc #0
	sta envLvH,y
	cmp envPeakV
	bcc .send
	lda envPeakV
	sta envLvH,y
	lda #0
	sta envLvL,y
	lda #ENV_D
	sta envPh,y
	bne .send
.d:
	cmp #ENV_D
	bne .r
	lda envDecV
	beq .sus                ; no decay
	lda envLvL,y
	sec
	sbc envDecV
	sta envLvL,y
	lda envLvH,y
	sbc #0
	sta envLvH,y
	bcc .sus
	cmp envSusV
	bcs .send
.sus:
	lda envSusV
	sta envLvH,y
	lda #0
	sta envLvL,y
	lda #ENV_S
	sta envPh,y
	bne .send
.r:
	cmp #ENV_R
	bne .send               ; sustain: only the tremolo moves
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
	jsr TremLevel
	ldy envY
	cmp envSent,y
	beq .x
	sta envSent,y
	jmp .cc7t
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
.cc7v:
	asl
	asl
	asl
	sta mD2
	jmp NesPut
.cc7t:
	; CC7 = the level after the tremolo
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
	lda envSent,y
	jmp .cc7v
.x:
	rts

; A = level of slot envY after the tremolo: level - level x tremA / 16
TremLevel:
	subroutine
	ldy envY
	lda envLvH,y
	ldx tremNes             ; (a patch's tremolo on the SID only: not here)
	beq .x
	ldx tremA
	beq .x
	sta exS                 ; (not t0-t3: MidiTo holds the channel in t1)
	ldy tremA
	jsr Mul8
	lda mt16                ; / 16
	lsr
	lsr
	lsr
	lsr
	sta exK
	lda exS
	sec
	sbc exK
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

; tremolo LFO, every 10 ms: tremA = 0-15. The sound's own (NES pulses with
; an envelope), the menu's TREMOLO ON (the ADVANCED SOUND values) or TREMOLO
; held (SPACE / a button): those two also move the SID's volume and the NES
; pulses of sounds without an envelope (held on a sound with none: the
; ADVANCED SOUND values). TREMOLO OFF: none. The Game Boy has no tremolo yet.
TremTick:
	subroutine
	jsr RelClock            ; (v0.34: the SID's release clocks)
	ldx soundMode
	ldy tremLock
	beq .snd
	cpy #1
	beq .user
	lda #0                  ; OFF
	sta exS
	beq .btn
.snd:
	lda nesTrem
	sta exS                 ; depth
	lda nesTremRL
	sta exI                 ; rate
	lda nesTremRH
	sta exK
	lda nesTremSync         ; (SYNC: the rate from the tempo)
	beq .fr
	lda tremSyncL
	sta exI
	lda tremSyncH
	sta exK
.fr:
	lda nesTremShp
	sta exD                 ; SHAPE
	lda nesTremMode
	sta tremMode            ; LFO, PUMP, GATEs
	lda tremChips           ; (the patch's: which chips)
	sta tremMask
	and #1
	sta tremNes
	jmp .btn
.user:
	lda #0
	sta tremMode
	jsr TremUser
	lda #1
	sta tremNes
.btn:
	lda tremBtn
	beq .d
	lda #1                  ; (held: every chip)
	sta tremNes
	lda exS
	bne .d
	jsr TremUser
.d:
	lda exS
	bne .on
	sta tremA
	jmp .out
.on:
	lda tremPhL
	clc
	adc exI
	sta tremPhL
	lda tremPhH
	adc exK
	sta tremPhH
	bcc .nw                 ; (a new cycle: RANDOM's next level)
	jsr Random
	sta tremRnd
	lda tremPhH
.nw:
	ldx tremMode            ; PUMP / GATE
	beq .lfo
	dex
	bne .gate
	sec                     ; PUMP (v0.35): like a compressor ducking to a kick:
	sbc #26                 ;  all the way down for the first tenth of the
	bcs .p1                 ;  cycle, then a swell back up on a curve (quick at
	lda #127                ;  first, easing in), at full volume from half way
	bne .ps
.p1:
	cmp #128
	bcc .p2
	lda #0
	beq .ps
.p2:
	eor #$7F                ; (127 - x)^2 / 128
	tay
	jsr Mul8
	asl mt16
	lda mt16+1
	rol
.ps:
	jmp .sc
.gate:
	lda tremGates-1,x       ; GATE: eight steps, on (no drop) or off (all of it)
	sta t0
	lda tremPhH
	lsr
	lsr
	lsr
	lsr
	lsr
	tay
	lda t0
	and tremBits,y
	beq .off
	lda #0
	beq .st
.off:
	lda exS
	jmp .st
.lfo:
	lda exD                 ; SHAPE (v0.34: every one): TRI SINE SAW UP SAW DOWN SQUARE RANDOM
	beq .tri
	cmp #4
	beq .sq
	bcs .rnd
	cmp #2
	bcc .sin
	beq .sup
	lda tremPhH             ; SAW DOWN: the volume falls through the cycle
	lsr
	jmp .sc
.sup:
	lda tremPhH             ; SAW UP: it rises
	eor #$FF
	lsr
	jmp .sc
.rnd:
	lda tremRnd             ; RANDOM: a new level each cycle
	jmp .sc
.sq:
	lda tremPhH
	cmp #128                ; square: full depth half the time
	lda #0
	bcs .st
	lda exS
	bne .st
.sin:
	lda tremPhH
	jsr Tri
	jsr Smooth
	jmp .sc
.tri:
	lda tremPhH
	jsr Tri                 ; 0-127
.sc:
	ldy exS
	jsr Mul8
	asl mt16
	lda mt16+1
	rol                     ; / 128
.st:
	sta tremA
.out:
	lda brAtt               ; DH-100 BREATH VOLUME: on top of the tremolo
	beq .o2
	clc
	adc tremA
	cmp #16
	bcc .o1
	lda #15
.o1:
	sta tremA
	jmp TremDirect
.o2:
	lda tremBtn
	bne .td
	lda tremLock
	cmp #1
	beq .td
	lda tremMask            ; the patch's tremolo on the SID (v0.33)
	and #2
	beq .ns
	lda exS
	beq .ns
	jmp TremSid
.ns:
	lda tremWas
	beq .r
	jmp TremEnd
.td:
	jmp TremDirect
.r:
	rts

; A = 0-127 -> the same, eased at both ends (3t^2 - 2t^3: near enough a sine)
Smooth:
	subroutine
	sta sinX
	tay
	jsr Mul8
	asl mt16
	lda mt16+1
	rol                     ; x^2 / 128
	sta sinT
	lda #190
	sec
	sbc sinX
	ldy sinT
	jsr Mul8                ; x 2 x (1.5 - x / 127)...
	asl mt16
	rol mt16+1
	asl mt16
	lda mt16+1
	rol                     ; / 64
	rts

tremGates:  .byte %10101101, %11011010, %10010010   ; X.X.XX.X, XX.XX.X., X..X..X.
tremBits:   .byte $80,$40,$20,$10,$08,$04,$02,$01

; TREMOLO SYNC: the phase step per 10 ms for its division at this tempo
; (65536 x 10 ms / the cycle's ms)
TremSyncCalc:
	subroutine
	ldx nesTremSync
	beq .x
	lda tsyncL-1,x
	sta d24
	lda tsyncM-1,x
	sta d24+1
	lda tsyncH-1,x
	sta d24+2
	jsr Div24               ; / beatMs
	lda d24
	sta tremSyncL
	lda d24+1
	sta tremSyncH
.x:
	rts

; 655360 / the division in beats: 1 BAR, 1/2, 1/4, 1/8 dotted, 1/8, 1/8T, 1/16, 1/16T, 1/32
tsyncL:     .byte <163840,<327680,<655360,<873813,<1310720,<1966080,<2621440,<3932160,<5242880
tsyncM:     .byte >163840,>327680,>655360,>873813,>1310720,>1966080,>2621440,>3932160,>5242880
tsyncH:     .byte 163840>>16,327680>>16,655360>>16,873813>>16,1310720>>16,1966080>>16,2621440>>16,3932160>>16,5242880>>16

; d24 (24 bits) / beatMs -> d24
Div24:
	subroutine
	lda #0
	sta d24r
	sta d24r+1
	ldx #24
.l:
	asl d24
	rol d24+1
	rol d24+2
	rol d24r
	rol d24r+1
	lda d24r
	sec
	sbc beatMs
	tay
	lda d24r+1
	sbc beatMs+1
	bcc .n
	sta d24r+1
	sty d24r
	inc d24
.n:
	dex
	bne .l
	rts

; the ADVANCED SOUND tremolo
TremUser:
	ldy uTremDep
	lda uTremDepT,y
	sta exS
	ldy uTremRate
	lda uTremRL,y
	sta exI
	lda uTremRH,y
	sta exK
	lda uTremShape
	sta exD
	rts

; TREMOLO held: the SID's volume and envelope-less NES pulses follow tremA
TremDirect:
	subroutine
	jsr TremSid
.nes:
	lda nesEnvOn
	bne .x
	lda tremA
	cmp tremSent
	beq .x
	sta tremSent
	lda #15
	sec
	sbc tremA
	asl
	asl
	asl
	jmp TremCC7
.x:
	rts

; the SID's master volume follows tremA (not while it's off, muted or a
; VINYL STOP fades it)
TremSid:
	subroutine
	lda #1
	sta tremWas
	lda devOn+DEV_SID
	beq .x
	lda muteNow
	bne .x
	lda vinylLvl
	cmp #192
	bcs .x
	ldx #2                  ; v0.34: nothing sounding on the SID (no gate, no
.a:                             ;  release ringing): full volume, still - no
	lda sidRelT,x           ;  tremolo ticking in the silence
	bne .on
	lda sidGate,x
	and #1
	bne .on
	dex
	bpl .a
	lda #15
	bne .t
.on:
	lda #15
	sec
	sbc tremA
.t:
	sta sidVolTgt           ; (VolSlew takes it there)
.x:
	rts

; every 10 ms: the SID voices' release clocks (50 ms steps)
RelClock:
	subroutine
	dec relDiv
	bpl .x
	lda #4
	sta relDiv
	ldx #2
.v:
	lda sidRelT,x
	beq .n
	dec sidRelT,x
.n:
	dex
	bpl .v
.x:
	rts

; SID voice Y let go: how long its release rings (the longer of the chord's
; and the lead's, in 50 ms steps). Keeps X, Y.
RelStart:
	subroutine
	lda sndSR
	and #$0F
	sta exD
	lda clMode
	beq .c
	lda leadPatch+sndSR-livePatch
	and #$0F
	cmp exD
	bcc .c
	sta exD
.c:
	stx exI
	ldx exD
	lda relSteps,x
	sta sidRelT,y
	ldx exI
RelRts:
	rts

relSteps:   .byte 2,2,2,3,4,5,6,6,7,16,31,49,61,181,255,255   ; the SID's release times / 50 ms, + 1

; TREMOLO let go: volumes back
TremEnd:
	lda #0
	sta tremWas
	sta tremSent
	jsr SidVolume
	lda nesEnvOn
	bne RelRts
	lda #127
TremCC7:                        ; A = CC7 value on both NES pulses
	subroutine
	ldx devOn+DEV_NES
	beq .x
	sta mD2
	lda #7
	sta mD1
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

; Sound switched (V): leaving PADS ends any NES envelope at once and puts the
; pulses back at full volume.
NesSoundApply:
	subroutine
	lda nesEnvOn
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
	ldx #2                  ; BEND OUT's fall-offs: cut
.f:
	lda nesFoT,x
	beq .fn
	stx t0
	lda #NO_NOTE
	jsr MidiTo
	ldx t0
.fn:
	inx
	inx
	inx
	cpx #NUM_VOICES
	bcc .f
	lda #0
	sta foAny
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
