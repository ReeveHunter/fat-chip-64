; Fat Chip 64 - main program
; A live rig controller: plays the SID and drives a Game Boy (Fat Chip GB)
; and an NES (MidiNES) over the Kerberos MIDI out, as one fat instrument.
; Build: ./build.sh (dasm makes bin/fatchip64-image.prg; tools/crunch.py packs it
; into bin/fatchip64.prg)

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
	jsr BeatLoad            ; (beat 0's kit, name and steps, from under the I/O)
	jsr MakeCycle           ; (v0.61: 4/4's)
	lda #3
	sta tripK
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
	jsr LoopTick            ; (v0.69: the looper's clock)
	bit padLitP             ; (v0.68: a lit pad goes out)
	bmi .nl
	jsr SmpTick
.nl:
	jsr StutterTick         ; STUTTER held
	jsr RepeatTick          ; REPEAT's echoes
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
	lda scrStage            ; nothing to draw: the pass is the effects'
	ora screenDirty
	ora vizOn
	bne .draw
	sta scrAt
	beq .fx
.draw:
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
	sta $C400,x             ; (v0.61: the variables from RAM_BASE = $C400 to $CFFF)
	sta $C500,x
	sta $C600,x
	sta $C700,x
	sta $C800,x
	sta $C900,x
	sta $CA00,x
	sta $CB00,x
	sta $CC00,x
	sta $CD00,x
	sta $CE00,x
	sta $CF00,x
	inx
	bne .ram
	ldx #0                  ; (v0.66: no effect settings kept yet; v0.68: the
	txa                     ;  sampler's and looper's variables, its pads empty)
.fm:
	sta fxMemOk,x
	inx
	cpx #SMP_END-fxMemOk
	bne .fm
	ldx #63
	lda #$FF
.pk:
	sta padKit,x
	dex
	bpl .pk
	sta padLitP
	lda #15
	sta smpRate
	lda #36                 ; PAD BASE NOTE C2 (36: the usual first pad)
	sta padBase
	lda #127                ; (the MidiNES's sample rate: full, as it starts)
	sta dmcRate
	lda #$FF
	sta lpTapK
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
	lda #VELOCITY
	sta mtVel
	lda #A_VIB              ; the keytar buttons: vibrato, glide, sustain
	sta btnTask
	lda #A_GLIDE
	sta btnTask+1
	lda #A_SUS
	sta btnTask+2
	lda #8                  ; Synthcart TRIM 0
	sta scTrim
	lda #1                  ; Synthcart: TUNE TO SQUARE, MATCH KEY ON (once in use)
	sta scSound
	sta scKey
	sta okpOn               ; ONE KEY PLAY on: PENTATONIC PAIRS, PING PONG, SOME turns, CUTS
	lda #2
	sta okpMotion
	sta okpTurn
	lda #1                  ; SMART CHORD: TRIAD
	sta spice
	lda #50                 ; FINE TUNE 0
	sta fineTune
	lda #64                 ; (the Game Boy's master tune: 0 cents)
	sta gbTune
	lda #3                  ; WANDER TIME 3 s
	sta wanderT
	lda #$FF
	sta okpPos
	sta clChordIdx          ; CHORD + LEAD: nothing yet; the lead's patch LEADS 1
	sta clLeadIdx
	lda #12                 ; SPLIT KEY: the middle of the overlay; SPLIT NOTE: C4
	sta splitKey
	lda #60
	sta splitNote
	lda #3                  ; LEAD OCTAVE +1
	sta leadOct
	lda #1                  ; SHIFT + F5: SPLIT KEY at first
	sta clLast
	lda #2
	sta leadBank
	lda bankSlot+10
	jsr LeadLoad
	lda #127                ; full breath until the DH-100 says otherwise
	sta breath
	lda #1                  ; BREATH FEEL NORMAL
	sta dhFeel
	lda #A_GLIDE            ; the DH-100's portamento button: GLIDE
	sta dhPort
	lda #A_BENDDN           ; SPACE bends down
	sta spaceAct
	lda #ARP_UNISON         ; ARP (held) uses UNISON until A picks another
	sta arpLast
	lda #1                  ; bend range 2 semitones
	sta bendRange
	sta beatFresh           ; (the first beat start sets its tempo)
	ldx #NUM_VOICES-1       ; (no NES note to glide from yet)
	lda #NO_NOTE
.nl:
	sta nesLast,x
	dex
	bpl .nl
	lda #8                  ; (NesFxTick goes round NES voices 2, 5, 8)
	sta nfxV
	lda #1
	; ADVANCED SOUND: what the menu's ON switches use until changed
	sta uVibDep             ; 1/4 semitone
	sta uGlide              ; MEDIUM
	sta uDet                ; FAT
	sta uWarb               ; MEDIUM
	sta uRpTime             ; 1/8 dotted
	lda #2
	sta uTremDep            ; DEEP
	sta uTremRate           ; 6 HZ
	sta uRpCount            ; 3 repeats
	lda #3
	sta uRpLevel            ; 70 %
	lda #4
	sta uVibRate            ; 6 HZ
	ldx soundMode
	jsr PatchLoad           ; FAT
	jsr SoundVars           ;  and its settings
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
	cmp #K_1                ; (K_NONE, and v0.68's 1 and 4: only the sampler's
	bcs .kn                 ;  GRID pads use them, SmpKeysUsed)
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
	lda sidVolNow           ; (the SID's volume: a step towards its target)
	cmp sidVolTgt
	beq .vs
	jsr VolSlew
.vs:
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

; With the MIDI chip's interrupts (midiIrq, v0.16): the chip interrupts when
; a byte has come in or the next can go out; the CIA timer ticks each ms.
IrqMidi:
	subroutine
	pha
	txa
	pha
	lda ACIA_STAT
	bpl .tim                ; (not the MIDI chip)
	lsr                     ; a byte in?
	bcc .tx
	jsr RxGot
.tx:
	lda ACIA_STAT
	and #ACIA_TDRE
	beq .tim
	ldx wireTail
	cpx wireHead
	beq .quiet
	lda wireBuf,x
	sta ACIA_TX
	inc wireTail
	jmp .tim
.quiet:
	lda #ACIA_MODE_RX       ; nothing to send: no more "ready" interrupts
	sta ACIA_CTRL
.tim:
	lda CIA1_ICR            ; the 1 ms tick?
	lsr
	bcc .out
	tya
	pha
	inc ticks
	bne .t
	inc ticks+1
.t:
	lda sidVolNow           ; (the SID's volume: a step towards its target)
	cmp sidVolTgt
	beq .vs
	jsr VolSlew
.vs:
	jsr Schedule
	jsr RxByte              ; (a long tick: a byte may be waiting, and
	jsr TxByte              ;  the MIDI chip holds only one)
	jsr RxByte
	pla
	tay
.out:
	pla
	tax
	pla
	rti

; RESTORE: the only NMI source. Count presses; the main loop acts on them.
; (A MIDI chip wired to NMI instead could fire one during MidiIrqTest: that
; isn't a press.)
Nmi:
	subroutine
	pha
	lda ACIA_STAT
	bpl .r
	lda #ACIA_MODE
	sta ACIA_CTRL
	pla
	rti
.r:
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
	include "repeat.asm"
	include "drums.asm"
	include "sync.asm"
	include "menu.asm"
	include "patchedit.asm"
	include "devices.asm"
	include "wander.asm"
	include "lead.asm"
	include "attack.asm"
	include "screen.asm"
	include "sampler.asm"
	include "looper.asm"
	include "viz.asm"
	include "nesfx.asm"
	include "data.asm"
	include "tables.asm"
	include "nestables.asm"
	include "soundtab.asm"
	include "menutab.asm"
	include "bendtab.asm"
codeEnd:
  if codeEnd > RAM_BASE
    ; (an unresolved name, not err: the first pass guesses the code long)
    .byte PROGRAM_RUNS_PAST_RAM_BASE_INTO_THE_VARIABLES
  endif

; ---- tables that live under the KERNAL: assembled here, after the code;
; tools/crunch.py packs them apart and they unpack straight to $E000 (v0.41)
hiPhys:
	rorg $E000
hiStart:
	include "menuhi.asm"
	include "beats.asm"     ; (v0.65: the beat tables, to make room for 25 patches)
hiEnd:
; v0.66: under the KERNAL, past its tables (cleared at start): each patch
; setting's step when its effect was last switched off, and per effect
; whether that's been kept (patchedit.asm FxOff / FxOn)
fxMem       equ hiEnd
fxMemOk     equ hiEnd+64
; v0.68: the sampler's (sampler.asm), cleared at start too
SMP         equ fxMemOk+16
smpOn       equ SMP+0           ; 1: the sampler's screen and keys
smpInit     equ SMP+1           ; kit 1 made from the beat's kit
smpArm      equ SMP+2           ; RETURN: the next pad gets the browser's sample
smpKit      equ SMP+3           ; 0 / 1: kit 1 / 2
smpSel      equ SMP+4           ; the browser's sample (bit 7: bank B)
smpRate     equ SMP+5           ; its rate, 0-15
smpFilt     equ SMP+6           ; TYPE: 0 ALL, 1-8 K S H P L T F V
padKeys     equ SMP+7           ; PAD KEYS: 0 GRID, 1 OVERLAY
padCh       equ SMP+8           ; PAD MIDI CHANNEL: 0 OFF, 1-16
padBase     equ SMP+9           ; PAD BASE NOTE
dmcRate     equ SMP+10          ; the MidiNES's sample rate (CC 3) last sent
padLitP     equ SMP+11          ; the lit pad ($FF none), since padLitT
padLitT     equ SMP+12
padVel      equ SMP+13
padNow      equ SMP+14
padCC       equ SMP+15
padLane     equ SMP+16
smpCode     equ SMP+17
smpTmp      equ SMP+18
smpI        equ SMP+19
smpN        equ SMP+20
smpX        equ SMP+21
smpY        equ SMP+22
smpR        equ SMP+23
smpS        equ SMP+24
smpX2       equ SMP+25
smpN2       equ SMP+26
smpTaken    equ SMP+27          ; 8: the keys whose press the sampler took
puOff       equ SMP+35          ; (v0.69: PatchUnpack's)
puSrc       equ SMP+36
padKit      equ SMP+40          ; 2 kits x 16 pads x (sample or $FF, rate)
; v0.69: the looper's (looper.asm)
LPV         equ SMP+104
lpSel       equ LPV+0           ; the track the keys work
lpQnt       equ LPV+1           ; QUANTIZE: 0 OFF, 1 1/16, 2 1/8
lpPh        equ LPV+2           ; the clock in its bar, 0-95
lpAtL       equ LPV+3           ; its next tick (ms)
lpAtH       equ LPV+4
lpFrac      equ LPV+5
lpRel       equ LPV+6           ; ticks left this beat step (a beat going)
lpBeatCue   equ LPV+7           ; a beat to start at the next bar
lpDirty     equ LPV+8
lpT         equ LPV+9
lpT2        equ LPV+10
lpI         equ LPV+11
lpQn        equ LPV+12
lpQd        equ LPV+13
lpSk        equ LPV+14
lpMute      equ LPV+15          ; a bit a track
lpTapK      equ LPV+16          ; the last button pressed, when (F5 twice: stop)
lpTapL      equ LPV+17
lpTapH      equ LPV+18
evL         equ LPV+19
evH         equ LPV+20
evP         equ LPV+21
nwL         equ LPV+22
nwH         equ LPV+23
nwP         equ LPV+24
lpQ         equ LPV+25          ; 8: hits due this tick
trkSt       equ LPV+33          ; 6 each: state (LP_*)
trkLenL     equ LPV+39          ;  length in ticks
trkLenH     equ LPV+45
trkPosL     equ LPV+51          ;  where it is
trkPosH     equ LPV+57
trkCnt      equ LPV+63          ;  hits
trkCur      equ LPV+69          ;  the next to play
trkUndo     equ LPV+75          ;  0, 1 an overdub kept, 2 undone
lpB16L      equ LPV+81          ; the tempo the tick was worked out for, and it
lpB16H      equ LPV+82
lpTkL       equ LPV+83
lpTkH       equ LPV+84
lpAny       equ LPV+85          ; the clock's awake (LoopAny)
SMP_END     equ LPV+86
  if SMP_END - fxMemOk > 255
    echo "the variables under the KERNAL: more than InitState clears"
    err
  endif
  if SMP_END > $FFF0
    echo "fxMem runs into the vectors"
    err
  endif
	rend
  if hiEnd > $FFFA
    echo "the $E000 tables run into the CPU's vectors"
    err
  endif

; ---- v0.60: data in the RAM under the I/O ($D000-$DFFF): packed apart too,
; unpacked there with the I/O switched out; read with BeatLoad's copy
ioPhys:
	rorg $D000
ioStart:
	include "beatsio.asm"
	include "smptab.asm"    ; (v0.68: the sampler's sample types)
ioEnd:
LPEV        equ ioEnd           ; v0.69: the loops' hits, a region a track
  if LPEV + 6*3*76 > $DD00
    echo "the loops' hits pass $DD00"
    err
  endif
	rend
  if ioEnd > $DE00
    ; (Nmi reads the ACIA at $DE06: if one came while BeatLoad has the I/O
    ;  switched out, it would read and write the RAM there: keep data below)
    echo "the $D000 data runs past $DE00"
    err
  endif
