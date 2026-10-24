; Fat Chip 64 - voice pool and smart stacking (poly synth mode)
;
; Nine voices across three chips, interleaved so a stack mixes chips:
;   v0 SID 1   v1 GB pulse 1   v2 NES pulse 1
;   v3 SID 2   v4 GB pulse 2   v5 NES pulse 2
;   v6 SID 3   v7 GB wave*     v8 NES triangle*      (* bass voices)
; Allocation, whenever the held notes change:
;   1. bass voices play the lowest note, an octave down
;   2. every other note gets one voice, lowest notes first
;   3. leftover voices stack on the lowest two notes, alternating
; So one note = a nine-voice unison across three chips, and in chords the
; bottom of the chord is fattest. Disabled devices get no notes.

; ------------------------------------------------------------ SID
SidInit:
	subroutine
	ldx #24
	lda #0
.clr:
	sta SID,x
	dex
	bpl .clr
	jsr SidVolume
	ldx #2
.v:
	ldy sidOfs,x
	lda #$19                ; attack 1, decay 9
	sta SID+5,y
	lda #$C9                ; sustain 12, release 9
	sta SID+6,y
	lda #$08                ; pulse width 50% (for pulse patches later)
	sta SID+3,y
	lda #$20                ; sawtooth, gate off
	sta sidGate,x
	sta SID+4,y
	dex
	bpl .v
	rts

; Volume 15, or 0 (silent, no hum) when the SID is off or muted (M).
; Volume 15, or 0 when the SID is off or muted. Keeps the filter mode bits.
SidVolume:
	subroutine
	lda devOn+DEV_SID
	beq .z
	lda muteNow
	bne .off
	lda #$0F
	bne .z
.off:
	lda #0
.z:
	ora sidFilt
	sta SID_VOL
	rts

; M or SPACE changed: muteNow = mute xor momentary. The SID goes to volume 0;
; the Game Boy and NES get note-offs (so nothing hangs on, and their tails
; ring out naturally), and their notes come back when it unmutes.
MuteChanged:
	subroutine
	lda sidMute
	eor moment
	sta muteNow
	beq .b
	lda #2                  ; red border while muted
.b:
	sta BORDER
	jsr SidVolume
	ldx #0
.v:
	stx t0
	lda vDev,x
	beq .n                  ; SID: volume does it
	lda vNote,x
	ldy muteNow
	beq .t
	lda #NO_NOTE
.t:
	cmp vOut,x
	beq .n
	jsr MidiTo
.n:
	ldx t0
	inx
	cpx #NUM_VOICES
	bne .v
	lda #1
	sta screenDirty
	rts

; Gate SID voices back on one scan after a retrigger.
SidRetrig:
	subroutine
	ldx #0
.v:
	lda vRetrig,x
	beq .next
	lda #0
	sta vRetrig,x
	lda vDev,x
	bne .next
	ldy vIdx,x              ; SID voice 0-2
	lda sidGate,y
	ora #1
	sta sidGate,y
	pha
	lda sidOfs,y
	tay
	pla
	sta SID+4,y
.next:
	inx
	cpx #NUM_VOICES
	bne .v
	rts

; ------------------------------------------------------------ allocation
; held notes (MIDI notes, ascending, at most 8) -> heldList / heldCount
BuildHeld:
	subroutine
	ldx #0
	ldy #0
.h:
	lda noteHeld,x
	beq .hn
	cpy #8
	bcs .hn
	txa
	clc
	adc octBase
	sta heldList,y
	iny
.hn:
	inx
	cpx #24
	bne .h
	sty heldCount
	lda playMode
	bne Expand
	rts

; SMART CHORD / EXTENSIONS: each held note becomes a chord built in the key.
; A note in the scale gets its diatonic chord (stacked scale thirds: triad,
; or 7 / 9 / 11 / 13 with extensions). A note outside the scale gets a
; major triad (+ b7, 9, 11, 13). Results merge, ascending, at most 8.
Expand:
	subroutine
	ldx heldCount
	stx exCount
.cp:
	dex
	bmi .cpd
	lda heldList,x
	sta chordTmp,x
	jmp .cp
.cpd:
	lda #0
	sta heldCount
	ldx #3                  ; tones: triad
	lda playMode
	cmp #MODE_EXT
	bne .tn
	lda spice
	clc
	adc #4                  ; 7th = 4 tones ... 13th = 7
	tax
.tn:
	stx exTones
	lda #0
	sta exI
.raw:
	lda exI
	cmp exCount
	beq .x
	tax
	lda chordTmp,x
	sta exR
	; degree of the note in the key, or $FF
	sec
	sbc keyRoot
	clc
	adc #120                ; keep it positive
.mod:
	cmp #12
	bcc .rel
	sbc #12
	bcs .mod
.rel:
	sta exV                 ; semitones above the key root
	jsr ScalePtr
	ldy #6
.d:
	lda (ptr),y
	cmp exV
	beq .found
	dey
	bpl .d
	ldy #$FF                ; not in the scale
.found:
	sty exD
	lda #0
	sta exK
.tone:
	lda exK
	cmp exTones
	beq .nextRaw
	ldy exD
	bmi .chrom
	; diatonic: scale[d + 2k] - scale[d]
	lda exK
	asl
	clc
	adc exD
	tay
	lda (ptr),y
	ldy exD
	sec
	sbc (ptr),y
	jmp .add
.chrom:
	ldy exK
	lda chromTones,y
.add:
	clc
	adc exR
	jsr InsertNote
	inc exK
	bne .tone
.nextRaw:
	inc exI
	bne .raw
.x:
	rts

; ptr = the key's scale table (21 steps, three octaves)
ScalePtr:
	lda keyMinor
	beq .maj
	lda #<scaleMinor
	sta ptr
	lda #>scaleMinor
	sta ptr+1
	rts
.maj:
	lda #<scaleMajor
	sta ptr
	lda #>scaleMajor
	sta ptr+1
	rts

; Insert note A into heldList (ascending, no repeats, at most 8: the
; highest falls off).
InsertNote:
	subroutine
	cmp #108
	bcs .x                  ; too high to be useful
	sta exV
	ldx #0
.f:
	cpx heldCount
	beq .ins
	lda heldList,x
	cmp exV
	beq .x                  ; already there
	bcs .ins                ; first one above
	inx
	bne .f
.ins:
	cpx #8
	bcs .x                  ; full and this is the highest
	; shift up from the end (dropping the 8th if full)
	stx exS
	ldy heldCount
	cpy #8
	bcc .s
	ldy #7
.s:
	cpy exS
	beq .put
	lda heldList-1,y
	sta heldList,y
	dey
	jmp .s
.put:
	lda exV
	sta heldList,x
	lda heldCount
	cmp #8
	bcs .x
	inc heldCount
.x:
	rts

Allocate:
	subroutine
	jsr BuildHeld
	; what the stacker spreads: the chord, or in UNISON arp just the arp note
	ldy heldCount
	sty allocCount
.cp:
	dey
	bmi .cpd
	lda heldList,y
	sta allocList,y
	jmp .cp
.cpd:
	lda arpMode
	cmp #ARP_UNISON
	bne .w0
	lda heldCount
	beq .w0
	lda arpNote
	sta allocList
	lda #1
	sta allocCount
.w0:
	jsr ArpPairSet          ; SPARKLE: keep the arp pair out of the pad
	; nothing wanted yet
	ldx #NUM_VOICES-1
	lda #NO_NOTE
.w:
	sta vWant,x
	dex
	bpl .w
	lda allocCount
	bne .go
	jmp ArpPairNotes
.go:
	ldx #7
	lda #0
.c:
	sta covered,x
	dex
	bpl .c
	; 1. bass voices -> lowest note
	ldx #0
.p1:
	jsr VoiceEnabled
	beq .p1n
	lda vBass,x
	beq .p1n
	lda allocList
	sta vWant,x
	lda #1
	sta covered
.p1n:
	inx
	cpx #NUM_VOICES
	bne .p1
	; 2. one voice per uncovered note, lowest first
	ldx #0
.p2:
	jsr VoiceEnabled
	beq .p2n
	lda vBass,x
	bne .p2n
	ldy #0
.find:
	cpy allocCount
	beq .p2n                ; all covered
	lda covered,y
	beq .take
	iny
	bne .find
.take:
	lda #1
	sta covered,y
	lda allocList,y
	sta vWant,x
.p2n:
	inx
	cpx #NUM_VOICES
	bne .p2
	; 3. leftovers stack on the lowest two notes
	lda allocCount
	cmp #2
	bcc .one
	lda #2
.one:
	sta t1                  ; how many notes to stack on (1 or 2)
	lda #0
	sta t2                  ; next stack target
	ldx #0
.p3:
	jsr VoiceEnabled
	beq .p3n
	lda vWant,x
	cmp #NO_NOTE
	bne .p3n
	ldy t2
	lda allocList,y
	sta vWant,x
	iny
	cpy t1
	bcc .keep
	ldy #0
.keep:
	sty t2
.p3n:
	inx
	cpx #NUM_VOICES
	bne .p3
	jmp ArpPairNotes

; SPARKLE's two arp voices: Game Boy pulses, else NES pulses, else SID 1+2.
; vSkip keeps them out of the pad.
ArpPairSet:
	subroutine
	ldx #NUM_VOICES-1
	lda #0
.c:
	sta vSkip,x
	dex
	bpl .c
	lda arpMode
	cmp #ARP_SPARKLE
	bne .x
	ldx #1                  ; GB pulse 1 / 2 = v1 / v4
	lda devOn+DEV_GB
	bne .set
	ldx #2                  ; NES pulse 1 / 2 = v2 / v5
	lda devOn+DEV_NES
	bne .set
	ldx #0                  ; SID 1 / 2 = v0 / v3
.set:
	stx pairA
	lda #1
	sta vSkip,x
	inx
	inx
	inx
	stx pairB
	sta vSkip,x
.x:
	rts

; SPARKLE: this step's voice plays the arp note, the other keeps ringing.
; Each arp step re-attacks the voices that play it (arpHit).
ArpPairNotes:
	subroutine
	ldx #NUM_VOICES-1
	lda #0
.c:
	sta vArpHit,x
	dex
	bpl .c
	lda arpMode
	beq .x
	lda heldCount
	beq .x
	lda arpMode
	cmp #ARP_UNISON
	bne .sparkle
	lda arpHit
	beq .x
	ldx #NUM_VOICES-1       ; unison: every voice re-attacks each step
	lda #1
.u:
	sta vArpHit,x
	dex
	bpl .u
	rts
.sparkle:
	ldx pairA
	ldy pairB
	lda arpStep
	and #1
	beq .ab
	ldx pairB
	ldy pairA
.ab:
	; X = this step's voice, Y = the other; arpOct octaves up
	lda arpOct
	asl
	asl
	sta t1                  ; x4
	asl
	adc t1                  ; x12
	clc
	adc arpNote
	sta vWant,x
	lda arpHit
	sta vArpHit,x
	lda vNote,y
	sta vWant,y             ; keeps ringing
.x:
	rts

; Z clear if voice X's device is on. Keeps X.
VoiceEnabled:
	subroutine
	lda vSkip,x
	bne .no
	ldy vDev,x
	lda devOn,y
	rts
.no:
	lda #0
	rts

; ------------------------------------------------------------ apply
; Send what changed. A voice whose note was just pressed is re-attacked even
; if it already plays that note.
ApplyVoices:
	subroutine
	ldx #0
.v:
	stx t0
	lda #0
	sta t3                  ; retrigger?
	lda vArpHit,x           ; an arp step re-attacks its voices
	sta t3
	bne .cmp
	lda vWant,x
	cmp #NO_NOTE
	beq .cmp
	sec                     ; pressed just now? (key index = note - octave)
	sbc octBase
	cmp #24
	bcs .cmp
	tay
	lda notePressed,y
	sta t3
.cmp:
	lda vWant,x
	cmp vNote,x
	bne .change
	lda t3
	beq .next
.change:
	jsr VoiceSet
	ldx t0
	lda vWant,x
	sta vNote,x
.next:
	ldx t0
	inx
	cpx #NUM_VOICES
	bne .v
	; presses and the arp step handled
	lda #0
	sta arpHit
	ldx #23
.p:
	sta notePressed,x
	dex
	bpl .p
	rts

; Voice X: from vNote,x to vWant,x; t3 = retrigger
VoiceSet:
	subroutine
	lda vDev,x
	beq .sid
	; ---- MIDI voice (Game Boy or MidiNES): nothing sounds while muted
	lda vWant,x
	ldy muteNow
	beq .go
	lda #NO_NOTE
.go:
	jmp MidiTo
	; ---- SID voice
.sid:
	ldy vIdx,x
	lda sidOfs,y
	sta t2                  ; register offset
	lda vWant,x
	cmp #NO_NOTE
	bne .sidOn
	; gate off
	lda sidGate,y
	and #$FE
	sta sidGate,y
	ldx t2
	sta SID+4,x
	rts
.sidOn:
	tax
	lda sidFreqLo,x
	sta ptr
	lda sidFreqHi,x
	sta ptr+1
	; detune: SID 2 a little sharp, SID 3 a little flat (+-1/256, ~7 cents)
	cpy #1
	bne .notUp
	lda ptr
	clc
	adc ptr+1
	sta ptr
	bcc .freq
	inc ptr+1
	bne .freq
.notUp:
	cpy #2
	bne .freq
	lda ptr
	sec
	sbc ptr+1
	sta ptr
	bcs .freq
	dec ptr+1
.freq:
	ldx t2
	lda ptr
	sta SID+0,x
	lda ptr+1
	sta SID+1,x
	; gate
	ldx t0
	lda vNote,x
	cmp #NO_NOTE
	beq .gateOn             ; was silent: attack
	lda t3
	beq .legato             ; same voice, new note, not a new press: glide
	; re-attack: gate off now, on at the next scan
	lda sidGate,y
	and #$FE
	sta sidGate,y
	ldx t2
	sta SID+4,x
	ldx t0
	lda #1
	sta vRetrig,x
	rts
.gateOn:
	lda sidGate,y
	ora #1
	sta sidGate,y
	ldx t2
	sta SID+4,x
.legato:
	rts

; MIDI voice t0: from what it sounds now (vOut) to note A (or NO_NOTE):
; note-off for the old note, note-on for the new. Always sends both, so
; the same note again is a re-attack.
MidiTo:
	subroutine
	sta mtTarget
	ldx t0
	lda vDev,x
	cmp #DEV_GB
	bne .nesCh
	lda gbBase
	jmp .ch
.nesCh:
	lda nesBase
.ch:
	clc
	adc vIdx,x
	and #15
	sta t1                  ; channel
	lda vOut,x
	cmp #NO_NOTE
	beq .on
	jsr MidiNoteValue
	sta mD1
	lda t1
	ora #$80
	sta mS
	lda #0
	sta mD2
	jsr DevPut
.on:
	ldx t0
	lda mtTarget
	sta vOut,x
	cmp #NO_NOTE
	beq .done
	jsr MidiNoteValue
	sta mD1
	lda t1
	ora #$90
	sta mS
	lda #VELOCITY
	sta mD2
	jsr DevPut
.done:
	rts

; A = MIDI note for voice t0 -> note to send (bass voices an octave down)
MidiNoteValue:
	subroutine
	ldx t0
	ldy vBass,x
	beq .x
	sec
	sbc #12
.x:
	rts

; queue mS/mD1/mD2 for voice t0's device
DevPut:
	subroutine
	ldx t0
	lda vDev,x
	cmp #DEV_GB
	bne .nes
	jmp GbPut
.nes:
	jmp NesPut

; ------------------------------------------------------------ device control
; X = device
ToggleDevice:
	subroutine
	lda devOn,x
	eor #1
	sta devOn,x
	bne .on
	; switched off: its voices get note-offs when the voices move; also
	; silence it outright
	cpx #DEV_GB
	bne .o1
	lda #GCC_PANIC
	ldx #0
	jsr GbGlobal
	jsr GbAllOff
	jmp .off
.o1:
	cpx #DEV_NES
	bne .off
	jsr NesAllOff
	jmp .off
.on:
	cpx #DEV_GB
	bne .n1
	jsr GbStartup
	jmp .off                ; (GbStartup doesn't keep X)
.n1:
	cpx #DEV_NES
	bne .off
	jsr NesStartup
.off:
	jsr SidVolume
	lda #1
	sta reallocFlag         ; voices move to or away from it
	sta screenDirty
	rts

; Release one device's voices, change its base channel, start it again.
NextGbChannel:
	subroutine
	lda devOn+DEV_GB
	pha
	lda #0
	sta devOn+DEV_GB
	jsr Allocate
	jsr ApplyVoices         ; note-offs on the old channels
	ldx gbBase
	inx
	cpx #12                 ; 1-5 ... 12-16
	bcc .ok
	ldx #0
.ok:
	stx gbBase
	pla
	sta devOn+DEV_GB
	jsr GbStartup
	lda #1
	sta reallocFlag
	sta screenDirty
	rts

NextNesChannel:
	subroutine
	lda devOn+DEV_NES
	pha
	lda #0
	sta devOn+DEV_NES
	jsr Allocate
	jsr ApplyVoices
	ldx nesBase
	inx
	cpx #12
	bcc .ok
	ldx #0
.ok:
	stx nesBase
	pla
	sta devOn+DEV_NES
	jsr NesStartup
	lda #1
	sta reallocFlag
	sta screenDirty
	rts

; SHIFT+F7: everything off, held and latched notes forgotten, latch off,
; devices set up again.
Panic:
	subroutine
	ldx #23
	lda #0
	sta latch
	sta arpRunning
	sta playCount
.k:
	sta noteHeld,x
	sta notePressed,x
	dex
	bpl .k
	jsr Allocate            ; nothing held -> every voice off
	jsr ApplyVoices
	; SID: all gates off
	ldx #2
.s:
	ldy sidOfs,x
	lda sidGate,x
	and #$FE
	sta sidGate,x
	sta SID+4,y
	dex
	bpl .s
	lda devOn+DEV_NES
	beq .gb
	jsr NesAllOff
.gb:
	lda devOn+DEV_GB
	beq .nes
	jsr GbAllOff            ; per channel, in case a global CC goes astray
	jsr GbStartup           ; includes the Game Boy's panic CC
.nes:
	jsr NesStartup
	lda #1
	sta screenDirty
	rts
