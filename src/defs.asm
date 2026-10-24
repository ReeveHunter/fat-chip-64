; Fat Chip 64 - hardware addresses, constants, variables

; ------------------------------------------------------------ hardware
VIC_CTRL1   equ $D011
VIC_IRQEN   equ $D01A
VIC_IRQ     equ $D019
BORDER      equ $D020
BGCOL       equ $D021

SID         equ $D400
SID_VOL     equ $D418

CIA1_PRA    equ $DC00          ; keyboard columns (out)
CIA1_PRB    equ $DC01          ; keyboard rows (in)
CIA1_DDRA   equ $DC02
CIA1_DDRB   equ $DC03
CIA1_TALO   equ $DC04
CIA1_TAHI   equ $DC05
CIA1_ICR    equ $DC0D
CIA1_CRA    equ $DC0E
CIA2_ICR    equ $DD0D

; Kerberos MIDI, DATEL emulation (MC6850 ACIA at $DE04-$DE07).
; Flash Fat Chip 64 with MIDI emulation = DATEL / Siel / JMS.
ACIA_CTRL   equ $DE04
ACIA_TX     equ $DE05
ACIA_STAT   equ $DE06
ACIA_RX     equ $DE07
ACIA_RESET  equ $03            ; master reset
ACIA_MODE   equ $16            ; /64 (31250 baud), 8N1, no interrupts
ACIA_TDRE   equ $02            ; status: transmit register empty

SCREEN      equ $0400
COLRAM      equ $D800

; ------------------------------------------------------------ timing
TICK_LATCH  equ 340            ; CIA1 timer A: 341 cycles = 1/3 ms (NTSC), about one
                               ; MIDI byte time, so the ACIA is fed even while
                               ; the main loop is busy; every third IRQ is a tick
SCAN_EVERY  equ 4              ; keyboard scan every 4 ms
GB_GAP      equ 3              ; ms between messages to the Game Boy (measured safe: 2)
LINK_MAX    equ 45             ; bytes we let pile up in the Teensyboy (its buffer: 64)
NES_GAP     equ 1              ; ms between messages to the MidiNES (wire-limited)
DOUBLE_TAP  equ 350            ; ms: second RESTORE press within this = double tap
RESTORE_DEBOUNCE equ 40        ; ms

; ------------------------------------------------------------ devices
DEV_SID     equ 0
DEV_GB      equ 1
DEV_NES     equ 2
NUM_VOICES  equ 9
NO_NOTE     equ $FF
OCT_DEFAULT equ 48             ; lowest overlay key (Q) = MIDI 48 (C3) at start (F3)
VELOCITY    equ 100

; Fat Chip GB global CCs (fat-chip-gb/docs/fatchip-protocol.md)
GCC_PROFILE equ 102
GCC_TUNE    equ 103
GCC_WARBLE  equ 104
GCC_WSPEED  equ 105
GCC_DOWNBEAT equ 109
GCC_LATCH   equ 110
GCC_PANIC   equ 111
GCC_DISPLAY equ 112
PROFILE_F   equ 70

; key codes from the matrix map (keymap): 0-23 = overlay notes
K_F1        equ $81
K_F3        equ $82
K_F5        equ $83
K_F7        equ $84
K_CRSR_DOWN equ $85
K_CRSR_RIGHT equ $86
K_INSTDEL   equ $87
K_LSHIFT    equ $88
K_RSHIFT    equ $89
K_SPACE     equ $8A
K_RETURN    equ $8B
K_CTRL      equ $8C
K_M         equ $8D
K_EQUALS    equ $8E
K_N         equ $8F
K_G         equ $90
K_A         equ $91
K_S         equ $92
K_D         equ $93
K_H         equ $94
K_J         equ $95
K_B         equ $96
K_F         equ $97
K_Z         equ $98
K_X         equ $99
K_K         equ $9A
K_L         equ $9B
K_V         equ $9C
LATCH_SMART equ 1
LATCH_HOLD  equ 2
LATCH_ADD   equ 3
SMART_WINDOW equ 500           ; ms: SMART latch adds notes pressed within this
MODE_POLY   equ 0
MODE_CHORD  equ 1
MODE_EXT    equ 2
ARP_UNISON  equ 1
ARP_SPARKLE equ 2
PAT_PLAYED  equ 4
ARP_FREE    equ 5              ; arpLen: 0-4 = 1/4 1/8 1/8T 1/16 1/32, 5 = free
FREE_STEPS  equ 16
MIN_STEP    equ 30             ; ms: fastest arp step (Game Boy link budget)
GCC_TEMPO_MSB equ 107
GCC_TEMPO_LSB equ 108
K_NONE      equ $FF

; ------------------------------------------------------------ zero page
	seg.u zp
	org $10
ticks       ds 2               ; 1 ms counter (IRQ)
scanAt      ds 1               ; low byte of ticks for the next scan
lastStatus  ds 1               ; running status on the wire
wireHead    ds 1               ; wire ring: head = write, tail = read
wireTail    ds 1
gbqHead     ds 1               ; Game Boy message queue (64 entries)
gbqTail     ds 1
gbNext      ds 1               ; ticks (low byte) when the next GB message may go
nesqHead    ds 1
nesqTail    ds 1
nesNext     ds 1
nmiCount    ds 1               ; RESTORE presses seen by the NMI handler
nmiTick     ds 2
nmiSeen     ds 1
mS          ds 1               ; message being queued: status, data 1, data 2
mD1         ds 1
mD2         ds 1
t0          ds 1
t1          ds 1
t2          ds 1
t3          ds 1
ptr         ds 2
ptr2        ds 2
irqT        ds 1               ; IRQ-only temporary
subTick     ds 1               ; IRQs since the last 1 ms tick (0-2)
linkLoad    ds 1               ; estimated bytes waiting in the Teensyboy (IRQ only)

; ------------------------------------------------------------ RAM ($C000-$CFFF)
	seg.u ram
	org $C000
wireBuf     ds 256
gbqS        ds 64
gbqD1       ds 64
gbqD2       ds 64
nesqS       ds 64
nesqD1      ds 64
nesqD2      ds 64
keyNow      ds 8
keyUsed     ds 8               ; keys with a job (the rest are ignored)
keyAcc      ds 8               ; keys accepted (phantom filter)
noteHeld    ds 24              ; 1 = note sounding (key held, or latched)
physKey     ds 24              ; 1 = overlay key physically down
physCount   ds 1
notePressed ds 24              ; 1 = pressed since the last voice update
heldList    ds 8               ; held notes, ascending (MIDI notes)
heldCount   ds 1
covered     ds 8
vWant       ds NUM_VOICES      ; MIDI note each voice should play, or NO_NOTE
vNote       ds NUM_VOICES      ; note each voice plays now
vRetrig     ds NUM_VOICES      ; SID: gate back on at the next scan
devOn       ds 3               ; SID, GB, NES enabled
gbBase      ds 1               ; MIDI channel 0-15 of the Game Boy's pulse 1
nesBase     ds 1               ; MIDI channel 0-15 of the MidiNES pulse 1
shiftDown   ds 1
reallocFlag ds 1
screenDirty ds 1
videoMode   ds 1               ; Game Boy screen: 0 on, 1 off (CC 112)
lastRestore ds 2
restoreFlash ds 1
sidGate     ds 3               ; current control register value per SID voice
statSent    ds 2               ; messages sent (for the status line)
ksBits      ds 1               ; key scan state (KeyDown/KeyUp may call
ksCol       ds 1               ;  routines that use t0-t3)
ksRow       ds 1
ksMask      ds 1
ksPass      ds 1
ghostFilter ds 1               ; 1 = phantom keys filtered
scanned     ds 1
decStarted  ds 1
nowL        ds 1
nowH        ds 1
; tempo
bpm         ds 1
beatMs      ds 2
tapLast     ds 2
tapCount    ds 1               ; 1 = there was a previous tap
tapN        ds 1               ; gaps in the ring (0-4)
tapPos      ds 1
tapRingLo   ds 4
tapRingHi   ds 4
dvdL        ds 1               ; Div16
dvdH        ds 1
dvsL        ds 1
dvsH        ds 1
remL        ds 1
remH        ds 1
; arp
arpMode     ds 1               ; 0 off, 1 unison, 2 sparkle
arpPat      ds 1               ; 0 up, 1 down, 2 up-down, 3 random, 4 as played
arpLen      ds 1
freeIdx     ds 1
stepMs      ds 2
arpNext     ds 2
arpRunning  ds 1
arpIdx      ds 1               ; $FF = start of the pattern
arpDir      ds 1
arpNote     ds 1
arpStep     ds 1
arpHit      ds 1               ; a step just happened: re-attack its voices
rnd         ds 1
playOrder   ds 8               ; key indexes in the order they were pressed
playCount   ds 1
pairA       ds 1               ; SPARKLE's two arp voices
pairB       ds 1
vSkip       ds NUM_VOICES
vArpHit     ds NUM_VOICES
allocList   ds 8
allocCount  ds 1
; v0.06
kDown       ds 1               ; K held: notes set the key
newPending  ds 1               ; N: the next note starts a new chord
lastPress   ds 2
moment      ds 1               ; SPACE held
muteNow     ds 1               ; mute (M) xor momentary (SPACE)
keyRoot     ds 1               ; 0-11, C = 0
keyMinor    ds 1
playMode    ds 1               ; 0 poly, 1 smart chord, 2 extensions
spice       ds 1               ; extensions: 0 = 7th, 1 = 9th, 2 = 11th, 3 = 13th
padSound    ds 1               ; 0 fat, 1 pads
arpOct      ds 1               ; SPARKLE arp: octaves up (0-2)
vOut        ds NUM_VOICES      ; MIDI voices: note actually sounding on the device
sidCtl      ds 1               ; SID waveform bits (saw $20, pulse $40)
padT        ds 2               ; pad LFO phase
chordTmp    ds 8
effMode     ds 1               ; settings the chord builder uses (a latched
effSpice    ds 1               ;  chord keeps the old ones until the next note)
effRoot     ds 1
effMinor    ds 1
exCount     ds 1               ; Expand / InsertNote
exTones     ds 1
exI         ds 1
exR         ds 1
exV         ds 1
exD         ds 1
exK         ds 1
exS         ds 1
mtTarget    ds 1
sidFilt     ds 1               ; SID_VOL filter mode bits (pads: low-pass)
ctrlDown    ds 1
octBase     ds 1               ; MIDI note of the lowest overlay key
latch       ds 1               ; 0 off, 1 hold, 2 build
sidMute     ds 1
rsSingle    ds 1               ; RESTORE test counters
rsDouble    ds 1
scrStage    ds 1               ; ScreenStep: 0 idle, 1-11 drawing
