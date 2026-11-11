; Fat Chip 64 - MIDI in (Kerberos MIDI IN), v0.11
;
; The IRQ (and the main loop's TxService) move each received byte into rxBuf.
; The main loop parses them (running status; realtime and system bytes are
; skipped) and plays incoming notes exactly like overlay keys: through the
; notes mode, latch, arp and K + note.
;
; Channels 1-11 are played (any of them, so the keytar's key channel can be
; anything up to 11). 12-16 are ignored: the Yamaha SHS-10 sends its
; accompaniment there (chords 12-14, bass 15, drums 16).
;
; H / J move incoming notes down / up an octave (-4..+4). A held note keeps
; its pitch until its note-off, so changing it mid-note can't hang anything.
;
; Note indexes: 0-23 are the overlay keys (note = index + octBase); 24-31 are
; MIDI slots, each holding one incoming note (midiNote = the note it plays,
; midiSrc = the note number that came in, for the note-off). Nothing from
; MIDI in is passed on to the Game Boy or NES.

; IRQ / main loop (interrupts off): take a received byte if there is one.
; Uses A, X.
; v0.13: clocks ($F8) aren't stored: counted here, every 24th (a beat) stamped
; with the time; a Start ($FA) makes the next clock a beat.
RxByte:
	subroutine
	lda ACIA_STAT
	lsr                     ; RDRF -> carry
	bcc .x
RxGot:
	lda ACIA_RX
	cmp #$F8
	beq .clk
	cmp #$FA
	bne .buf
	ldx #23                 ; Start: the next clock is beat 1
	stx clkPhase
	stx clkSkip             ; (and its period isn't a beat: set here, before
	                        ;  the main loop could measure it)
	ldx clkBeat
	stx clkStartBeat
.buf:
	ldx rxHead
	sta rxBuf,x
	inx
	txa
	and #63
	cmp rxTail
	beq .x                  ; full: dropped
	sta rxHead
.x:
	rts
.clk:
	inc clkCount
	ldx clkPhase
	inx
	cpx #24
	bcc .ph
	lda ticks
	sta clkAtL
	lda ticks+1
	sta clkAtH
	lda subTick
	sta clkAtS
	inc clkBeat
	ldx #0
.ph:
	stx clkPhase
	rts

; Main loop, every pass: parse what came in.
MidiInService:
	subroutine
.next:
	ldx rxTail
	cpx rxHead
	bne .byte
	rts
.byte:
	lda rxBuf,x
	tay
	inx
	txa
	and #63
	sta rxTail
	tya
	bpl .data
	cmp #$F8
	bcs .rt                 ; realtime (clocks are counted by RxByte)
	cmp #$F0
	bcc .status
	lda #0                  ; system: no running status until the next one
.status:
	sta rxStatus
	lda #0
	sta rxCnt
	beq .next
.data:
	ldx rxStatus
	beq .next               ; no status yet
	ldx rxCnt
	bne .second
	sta rxD1
	inc rxCnt
	lda rxStatus
	and #$E0
	cmp #$C0                ; program change / channel pressure: one byte
	bne .next
	lda #0
	sta rxCnt
	jsr MidiInMsg
	jmp .next
.rt:
	cmp #$FA
	bne .rt2
	jsr KeytarStart
	jmp .next
.rt2:
	cmp #$FC
	bne .rt3
	jsr KeytarStop
.rt3:
	jmp .next
.second:
	sta rxD2
	lda #0
	sta rxCnt
	jsr MidiInMsg
	jmp .next

; A full message: rxStatus, rxD1, rxD2
MidiInMsg:
	subroutine
	lda rxStatus
	and #15
	cmp #DRUM_CH_IN         ; channel 16: the keytar's rhythm
	bne .notes
	lda rxStatus
	and #$F0
	cmp #$C0
	bne .dr
	jmp KeytarStyle         ; its style buttons
.dr:
	cmp #$90
	bne .x
	lda rxD2
	beq .x
	lda syncDrums           ; its drum notes: on the MidiNES if the menu says PLAY
	beq .x
	jmp KeytarDrum
.notes:
	cmp #MIDI_IN_CHANS
	bcs .x                  ; channels 12-15: the keytar's accompaniment
	sta t3
	lda rxStatus
	and #$F0
	cmp #$B0
	bne .pc
	jmp KeytarCC            ; its vibrato / portamento / sustain buttons
.pc:
	cmp #$C0
	bne .pb
	jmp KeytarVoice         ; its voice buttons
.pb:
	cmp #$E0
	bne .nt
	jmp KeytarWheel
.nt:
	cmp #$80
	beq .off
	cmp #$90
	bne .x
	lda rxD2
	beq .off                ; note-on velocity 0 = note-off
	jmp MidiNoteOn
.off:
	jmp MidiNoteOff
.x:
	rts

; Note-on rxD1 on channel t3
MidiNoteOn:
	subroutine
	lda rxD1
	sta lastInNote
	lda t3
	sta lastInCh
	lda #1
	sta screenDirty
	; already down (a repeated note-on)? ignore
	ldx #MIDI_SLOTS-1
.dup:
	lda physKey+MIDI_FIRST,x
	beq .dn
	lda midiSrc,x
	cmp rxD1
	bne .dn
	rts
.dn:
	dex
	bpl .dup
	; the note it plays: + midiOct octaves, 0-127 or it's ignored
	lda midiOct
	asl
	asl                     ; x 4
	sta t0
	asl                     ; x 8
	clc
	adc t0                  ; x 12 (signed, -48..+48)
	sta t0
	bmi .neg
	clc
	adc rxD1
	bmi .no                 ; over 127
	bpl .got
.neg:
	clc
	adc rxD1
	bcc .no                 ; under 0
.got:
	sta t1                  ; note
	jsr PlayPrune           ; (a freed slot may still be in playOrder)
	; a latched slot already playing this note (so ADD latch can take it
	; out), else a free slot, else the first one not held down
	ldx #MIDI_SLOTS-1
.same:
	lda noteHeld+MIDI_FIRST,x
	beq .sn
	lda midiNote,x
	cmp t1
	beq .use
.sn:
	dex
	bpl .same
	ldx #MIDI_SLOTS-1
.free:
	lda noteHeld+MIDI_FIRST,x
	ora physKey+MIDI_FIRST,x
	beq .use
	dex
	bpl .free
	ldx #MIDI_SLOTS-1
.up:
	lda physKey+MIDI_FIRST,x
	beq .steal
	dex
	bpl .up
.no:
	rts                     ; all eight held down: ignored
.steal:
	lda #0
	sta noteHeld+MIDI_FIRST,x
.use:
	lda t1
	sta midiNote,x
	lda rxD1
	sta midiSrc,x
	txa
	clc
	adc #MIDI_FIRST
	jmp NoteDown

; Note-off rxD1
MidiNoteOff:
	subroutine
	ldx #MIDI_SLOTS-1
.f:
	lda physKey+MIDI_FIRST,x
	beq .n
	lda midiSrc,x
	cmp rxD1
	beq .up
.n:
	dex
	bpl .f
	rts
.up:
	txa
	clc
	adc #MIDI_FIRST
	jmp NoteUp

; Panic: every MIDI slot let go (a lost note-off can't keep one down)
MidiInRelease:
	subroutine
	ldx #MIDI_SLOTS-1
.l:
	lda physKey+MIDI_FIRST,x
	beq .n
	lda #0
	sta physKey+MIDI_FIRST,x
	lda physCount
	beq .n
	dec physCount
.n:
	dex
	bpl .l
	rts

; H / J: incoming notes an octave down / up
MidiOctDown:
	subroutine
	lda midiOct
	cmp #256-MIDI_OCT_MAX
	beq .x
	dec midiOct
.x:
	jmp Dirty

MidiOctUp:
	subroutine
	lda midiOct
	cmp #MIDI_OCT_MAX
	beq .x
	inc midiOct
.x:
	jmp Dirty

; Note index X -> its MIDI note in A (keeps X and Y)
IdxNote:
	subroutine
	cpx #MIDI_FIRST
	bcs .midi
	txa
	clc
	adc octBase
	jmp .up
.midi:
	lda midiNote-MIDI_FIRST,x
.up:
	clc                     ; OCTAVE UP held: + 12 (not past 127)
	adc octUpAdd
	bpl .x
	sec
	sbc #12
.x:
	rts
