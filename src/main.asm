; Fat Chip 64 - main program
; A live rig controller: plays the SID and drives a Game Boy (Fat Chip GB)
; and an NES (MidiNES) over the Kerberos MIDI out, as one fat instrument.
; Build: dasm src/main.asm -f1 -obin/fatchip64.prg -sbin/fatchip64.sym -lbin/fatchip64.lst

	processor 6502
	include "defs.asm"

	seg code
	org $0801
	; BASIC stub: 10 SYS 2064
	.byte $0B,$08,$0A,$00,$9E,"2064",$00,$00,$00
	org $0810

Start:
	subroutine
	sei
	cld
	ldx #$FF
	txs
	lda #$35                ; RAM at $A000/$E000, I/O on (no BASIC/KERNAL)
	sta $01
	jsr InitHardware
	jsr InitState
	jsr ScreenInit
	jsr SidInit
	jsr SoundSid
	jsr MidiInit
	cli
StartDevices:                   ; (the tests can move the channels here)
	jsr GbStartup
	jsr NesStartup
	jsr ScreenDrawAll

;------------------------------------------------------------- main loop
Loop:
	subroutine
	jsr TxService
	; keyboard scan every SCAN_EVERY ms
	lda #0
	sta scanned
	lda scanAt              ; due unless 1..SCAN_EVERY ms to go
	sec
	sbc ticks
	beq .scan
	cmp #SCAN_EVERY+1
	bcc .noScan
.scan:
	lda ticks
	clc
	adc #SCAN_EVERY
	sta scanAt
	inc scanned
	sec
	sbc #SCAN_EVERY-2       ; (A = ticks + SCAN_EVERY): the screen step at ticks + 2
	bne .sa
	lda #1                  ; (0 means none)
.sa:
	sta scrAt
	jsr SidRetrig
	jsr KeyScan
	jsr RestoreCheck
.noScan:
	jsr MidiInService       ; notes from the Kerberos MIDI IN (before the
	                        ;  arp, which starts on a key change)
	jsr ArpTick             ; every pass, so arp steps land on time
	jsr NesEnvTick          ; MidiNES envelopes (PADS)
	jsr BendTick            ; SPACE bend
	jsr ClockTick           ; the keytar's clock: tempo
	jsr BeatTick            ; beat demos
	jsr DrumTick            ; noise hits end
	lda reallocFlag
	beq .noAlloc
	lda #0
	sta reallocFlag
	sta applyRetry
	jsr Allocate
	jsr ApplyVoices
	lda #1
	sta screenDirty
	bne .alloced
.noAlloc:
	lda applyRetry          ; a voice change was waiting for a device queue
	beq .alloced
	lda #0
	sta applyRetry
	jsr ApplyVoices
.alloced:
	; one screen step per keyboard scan, 2 ms after it, on a pass of its
	; own (a scan and a screen step in one pass would stretch it)
	; (v0.12: the SID effects take a non-scan pass the screen doesn't need)
	; when both are due they take turns (a redraw after a key press would
	; otherwise freeze vibrato and glides for 70 ms)
	lda scanned
	bne .x
	lda scrAt
	beq .fx                 ; done for this scan
	sec
	sbc ticks
	beq .sdue
	cmp #3
	bcc .fx                 ; 1-2 ms to go
.sdue:
	lda fxTurn
	and fxBusy              ; (only sounds with SID effects need the turns)
	beq .scr
	lda ticks
	sec
	sbc fxLast
	cmp #FX_EVERY
	bcc .scr                ; effects not due: the screen
	lda #0
	sta fxTurn
	beq .fx
.scr:
	lda #0
	sta scrAt
	lda #1
	sta fxTurn
	jsr ScreenStep
	jmp Loop
.fx:
	jsr FxTick              ; SID vibrato, glide, filter, width; duty steps
.x:
	jmp Loop

;------------------------------------------------------------- init
InitHardware:
	subroutine
	lda #$7F
	sta CIA1_ICR            ; no CIA1 interrupts yet
	sta CIA2_ICR            ; no CIA2 NMIs: only RESTORE raises an NMI
	lda CIA1_ICR
	lda CIA2_ICR
	lda #0
	sta VIC_IRQEN
	lda #$FF
	sta VIC_IRQ
	sta CIA1_DDRA           ; port A = keyboard columns out
	lda #0
	sta CIA1_DDRB           ; port B = rows in
	lda #$FF
	sta CIA1_PRA
	; vectors (KERNAL is banked out)
	lda #<Irq
	sta $FFFE
	lda #>Irq
	sta $FFFF
	lda #<Nmi
	sta $FFFA
	lda #>Nmi
	sta $FFFB
	; 1 ms timer
	lda #<TICK_LATCH
	sta CIA1_TALO
	lda #>TICK_LATCH
	sta CIA1_TAHI
	lda #$11                ; start, force load, continuous
	sta CIA1_CRA
	lda #$81                ; enable timer A interrupt
	sta CIA1_ICR
	rts

InitState:
	subroutine
	; clear zero page variables and the RAM block
	lda #0
	ldx #$10
.zp:
	sta $00,x
	inx
	cpx #$80
	bne .zp
	tax
.ram:
	sta $C000,x
	sta $C100,x
	sta $C200,x
	sta $C300,x
	sta $C400,x
	sta $C500,x
	sta $C600,x
	inx
	bne .ram
	ldx #NUM_VOICES-1
	lda #NO_NOTE
.v:
	sta vNote,x
	sta vWant,x
	sta vOut,x
	dex
	bpl .v
	sta lastInNote          ; (NO_NOTE: nothing received yet)
	lda #1
	sta devOn+DEV_SID
	sta devOn+DEV_GB
	sta devOn+DEV_NES
	lda #GB_BASE_DEFAULT    ; Game Boy on 11-15 (Fat Chip 64 moves it there: CC 113)
	sta gbBase
	lda #NES_BASE_DEFAULT   ; MidiNES on 1-5, its power-on default
	sta nesBase
	lda #$FF
	sta dmcBank
	sta nzNote
	sta dmcNote
	lda #$80                ; drums: the last hits were long ago
	sta dmcAt+1
	sta nzAt+1
	lda #1                  ; the keytar buttons: vibrato, glide, sustain
	sta btnTask+1
	lda #2
	sta btnTask+2
	jsr SoundVars           ; FAT's settings
	lda #OCT_DEFAULT
	sta octBase
	lda #1
	sta arpOct              ; SPARKLE arp an octave up
	lda #120
	sta bpm
	lda #<500
	sta beatMs
	lda #>500
	sta beatMs+1
	lda #<8000              ; (x 16)
	sta beat16L
	lda #>8000
	sta beat16H
	lda #ARP_FREE           ; FREE, 30 ms
	sta arpLen
	lda #FREE_DEFAULT
	sta freeIdx
	lda #$FF
	sta arpIdx
	jsr StepCalc
	; keyUsed: per column, the rows whose keys do something
	ldy #63
.ku:
	lda keymap,y
	cmp #K_NONE
	beq .kn
	tya
	lsr
	lsr
	lsr
	tax
	tya
	and #7
	sta t0
	sty t1
	ldy t0
	lda rowBit,y
	ora keyUsed,x
	sta keyUsed,x
	ldy t1
.kn:
	dey
	bpl .ku
	lda #$FF
	sta lastStatus
	lda #$80                ; "long ago": the first RESTORE press is a single tap
	sta lastRestore+1
	rts

;------------------------------------------------------------- interrupts
; Every 1/4 ms: take a MIDI-in byte, feed the ACIA one byte (fast path).
; Every fourth time (1 ms):
; count a tick and move paced messages onto the wire.
Irq:
	subroutine
	pha
	txa
	pha
	lda CIA1_ICR            ; acknowledge
	lda ACIA_STAT           ; MIDI in: a received byte? (quick check inline)
	lsr
	bcc .noRx
	jsr RxGot
.noRx:
	ldx wireTail
	cpx wireHead
	beq .noByte
	lda ACIA_STAT
	and #ACIA_TDRE
	beq .noByte
	lda wireBuf,x
	sta ACIA_TX
	inc wireTail
.noByte:
	dec subTick
	bpl .out
	lda #3
	sta subTick
	tya
	pha
	inc ticks
	bne .t
	inc ticks+1
.t:
	jsr Schedule
	jsr TxByte              ; start a just-scheduled message now if the ACIA is free
	jsr RxByte              ; (again: this pass was long, a byte may be in)
	pla
	tay
.out:
	pla
	tax
	pla
	rti

; RESTORE: the only NMI source. Count presses; the main loop acts on them.
Nmi:
	subroutine
	pha
	lda CIA2_ICR            ; acknowledge anything CIA 2 holds, so the NMI
	                        ; line is free for the next RESTORE edge
	inc nmiCount
	lda ticks
	sta nmiTick
	lda ticks+1
	sta nmiTick+1
	pla
	rti

	include "midi.asm"
	include "keys.asm"
	include "voices.asm"
	include "arp.asm"
	include "pads.asm"
	include "nesenv.asm"
	include "bend.asm"
	include "midiin.asm"
	include "sounds.asm"
	include "drums.asm"
	include "sync.asm"
	include "menu.asm"
	include "screen.asm"
	include "data.asm"
	include "tables.asm"
	include "nestables.asm"
	include "soundtab.asm"
	include "beats.asm"
