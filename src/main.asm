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
	jsr MidiInit
	cli
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
	jsr SidRetrig
	jsr KeyScan
	jsr RestoreCheck
.noScan:
	jsr ArpTick             ; every pass, so arp steps land on time
	lda reallocFlag
	beq .noAlloc
	jsr Allocate
	jsr ApplyVoices
	lda #0
	sta reallocFlag
	lda #1
	sta screenDirty
.noAlloc:
	lda scanned
	beq .x
	jsr ScreenStep
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
	inx
	bne .ram
	ldx #NUM_VOICES-1
	lda #NO_NOTE
.v:
	sta vNote,x
	sta vWant,x
	dex
	bpl .v
	lda #1
	sta devOn+DEV_SID
	sta devOn+DEV_GB
	sta devOn+DEV_NES
	lda #0                  ; Game Boy on channels 1-5 (Fat Chip GB default)
	sta gbBase
	lda #5                  ; MidiNES on channels 6-10 (set with the NES D-pad)
	sta nesBase
	lda #OCT_DEFAULT
	sta octBase
	lda #120
	sta bpm
	lda #<500
	sta beatMs
	lda #>500
	sta beatMs+1
	lda #3                  ; 1/16
	sta arpLen
	lda #8                  ; 160 ms
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
; Every 1/3 ms: feed the ACIA one byte (fast path). Every third time (1 ms):
; count a tick and move paced messages onto the wire.
Irq:
	subroutine
	pha
	txa
	pha
	lda CIA1_ICR            ; acknowledge
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
	lda #2
	sta subTick
	tya
	pha
	inc ticks
	bne .t
	inc ticks+1
.t:
	jsr Schedule
	jsr TxByte              ; start a just-scheduled message now if the ACIA is free
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
	include "screen.asm"
	include "data.asm"
	include "tables.asm"
