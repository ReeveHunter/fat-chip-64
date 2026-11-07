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
RxByte:
	subroutine
	lda ACIA_STAT
	lsr                     ; RDRF -> carry
	bcc .x
	lda ACIA_RX
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
	bcs .next               ; realtime (clock, active sensing...): skip
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
	beq .next
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
	cmp #DRUM_CH_IN         ; channel 16: the keytar's rhythm -> MidiNES drums
	bne .notes
	lda rxStatus
	and #$F0
	cmp #$90
	bne .x
	lda rxD2
	beq .x
	jmp KeytarDrum
.notes:
	cmp #MIDI_IN_CHANS
	bcs .x                  ; channels 12-16: the keytar's accompaniment
	sta t3
	lda rxStatus
	and #$F0
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
	rts
.midi:
	lda midiNote-MIDI_FIRST,x
	rts
