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
TICK_LATCH  equ 255            ; CIA1 timer A: 256 cycles = 1/4 ms (NTSC), quicker
                               ; than a MIDI byte (327 cycles), so the ACIA is fed
                               ; and read (MIDI in) even while the main loop is
                               ; busy; every fourth IRQ is a tick
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
K_H         equ $94           ; MIDI in octave down
K_J         equ $95           ; MIDI in octave up
K_B         equ $96
K_F         equ $97
K_Z         equ $98
K_X         equ $99
K_K         equ $9A
K_L         equ $9B
K_V         equ $9C
K_COLON     equ $9D           ; : arp slower
K_SEMI      equ $9E           ; ; arp faster (the rightmost)
K_COMMA     equ $9F           ; , (<) SPACE mode back
K_PERIOD    equ $A0           ; . (>) SPACE mode on
K_C         equ $A1           ; C: POLY / MONO
GCC_CHANNELS equ 113          ; Fat Chip GB v0.08: 64 + n moves its voices to channels n+1..n+5 (any channel)
GB_BASE_DEFAULT equ 10        ; Game Boy on channels 11-15
NES_BASE_DEFAULT equ 0        ; MidiNES on channels 1-5 (its power-on default)
BASS_LO     equ 28            ; Fat Bass: the bass voices keep the lowest note in E1-E2,
BASS_HI     equ 40            ;  folding by octaves
FX_EVERY    equ 4             ; ms per SID effect step (vibrato, glide, filter, width)
DRUM_CH_IN  equ 15            ; MIDI in channel 16: the keytar's rhythm
NUM_BEATS   equ 6
MIDI_FIRST  equ 24            ; note indexes: 0-23 overlay, 24-31 MIDI in
MIDI_SLOTS  equ 8
NIDX        equ MIDI_FIRST+MIDI_SLOTS
MIDI_IN_CHANS equ 11          ; MIDI in plays channels 1-11 (12-16: SHS-10 accompaniment)
MIDI_OCT_MAX equ 4
SPC_MUTE    equ 0             ; SPACE modes: held = mute flips
SPC_BEND    equ 1             ;  held = everything bends down
SPC_MODES   equ 2
BEND_DOWN_MS equ 4            ; bendLvl 0-255: +1 per 4 ms down (about 1 s)
BEND_TICK   equ 20            ; ms between bend updates to the Game Boy / NES
Q_BACKLOG   equ 8             ; messages waiting: a device skips voice changes
LATCH_SMART equ 1
LATCH_HOLD  equ 2
LATCH_ADD   equ 3
SMART_WINDOW equ 500           ; ms: SMART latch adds notes pressed within this
MODE_POLY   equ 0
MODE_CHORD  equ 1
MODE_EXT    equ 2
SND_FAT     equ 0
SND_PADS    equ 1
SND_RAW     equ 2
ENV_IDLE    equ 0
ENV_A       equ 1
ENV_D       equ 2
ENV_S       equ 3
ENV_R       equ 4
ARP_UNISON  equ 1
ARP_SPARKLE equ 2
PAT_PLAYED  equ 4
ARP_FREE    equ 5              ; arpLen: 0-4 = 1/4 1/8 1/8T 1/16 1/32, 5 = free
FREE_STEPS  equ 20
FREE_DEFAULT equ 4             ; 30 ms
MIN_STEP    equ 10             ; ms: fastest arp step (the Game Boy / NES skip
                               ;  steps their queues can't keep up with)
GCC_TEMPO_MSB equ 107
GCC_TEMPO_LSB equ 108
K_NONE      equ $FF

; ------------------------------------------------------------ zero page
	seg.u zp
	org $10
ticks       ds 2               ; 1 ms counter (IRQ)
scanAt      ds 1               ; low byte of ticks for the next scan
scrAt       ds 1               ; ... for the next screen step
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
subTick     ds 1               ; IRQs until the next 1 ms tick (3-0)
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
noteHeld    ds NIDX            ; 1 = note sounding (key held, or latched)
physKey     ds NIDX            ; 1 = key physically down (overlay or MIDI in)
physCount   ds 1
notePressed ds NIDX             ; 1 = pressed since the last voice update
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
soundMode   ds 1               ; 0 FAT, 1 PADS, 2 RAW
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
sidFilt     ds 1
; MidiNES envelopes (nesenv.asm)
envPh       ds 2               ; per NES pulse: 0 idle, 1 attack, 2 decay, 3 sustain, 4 release
envLvL      ds 2               ; level 8.8 (0-15)
envLvH      ds 2
envSent     ds 2               ; level last sent as CC7
envRel      ds 2               ; release step
envY        ds 1
envLast     ds 1               ; ticks (low byte) of the last envelope step
triOn       ds 1               ; triangle release drop running
triK        ds 1
triNote     ds 1
triLast     ds 1
triStart    ds 2
hardCut     ds 1               ; 1 = no soft releases (panic)
mulA        ds 2
mulB        ds 2
mulR        ds 4
; v0.10
spaceMode   ds 1               ; SPC_MUTE / SPC_BEND (, and .)
bendLvl     ds 1               ; 0 = none, 255 = 2 semitones down
bendLast    ds 1               ; ticks (low byte) of the last bend step
bendSentAt  ds 1               ; ticks (low byte) of the last MIDI bend
bendSent    ds 1               ; bendLvl last sent to the Game Boy / NES
spaceDown   ds 1               ; SPACE held
bT0         ds 1               ; bend.asm temps
bT1         ds 1
bT2         ds 1
bT3         ds 1
sidBaseLo   ds 3               ; SID frequency before the bend
sidBaseHi   ds 3
applyRetry  ds 1               ; a voice change waits for a device queue
; v0.11 MIDI in
rxBuf       ds 64
rxHead      ds 1
rxTail      ds 1
rxStatus    ds 1
rxCnt       ds 1
rxD1        ds 1
rxD2        ds 1
midiNote    ds MIDI_SLOTS      ; note each MIDI slot plays
midiSrc     ds MIDI_SLOTS      ; note number that came in
midiOct     ds 1               ; H / J: -4..+4 octaves
lastInNote  ds 1               ; last note received ($FF = none yet)
lastInCh    ds 1
ctrlDown    ds 1
octBase     ds 1               ; MIDI note of the lowest overlay key
latch       ds 1               ; 0 off, 1 hold, 2 build
sidMute     ds 1
rsSingle    ds 1               ; RESTORE test counters
rsDouble    ds 1
scrStage    ds 1               ; ScreenStep: 0 idle, 1-11 drawing
; v0.12 sounds (sounds.asm)
monoMode    ds 1               ; 1 = MONO (one note, legato): the sound's default, C flips it
fatBass     ds 1               ; 1 = bass voices keep the lowest note in BASS_LO-BASS_HI
nesEnvOn    ds 1               ; 1 = NES pulses use the CC7 envelope (PADS and the new sounds)
legatoNow   ds 1               ; MidiTo: change notes without a re-attack
fxLast      ds 1               ; ticks (low byte) of the last SID effect step
fPhL        ds 1               ; filter LFO phase (16 bits)
fPhH        ds 1
pPhL        ds 1               ; PWM LFO phase
pPhH        ds 1
vPhL        ds 1               ; vibrato LFO phase
vPhH        ds 1
fEnv        ds 1               ; filter envelope (opens on each attack, falls back)
fxVoice     ds 1               ; SID voice whose width the next effect call updates
fxN         ds 1               ; 4 ms steps this effect call catches up
vibNow      ds 1               ; vibrato now (voices in step)
fxTurn      ds 1               ; 1 = the effects go first when the screen is also due
fxBusy      ds 1               ; 1 = this sound has SID effects or a duty sequence
vibT        ds 3               ; per SID voice: 4 ms steps since its attack (for the vibrato delay)
vibAmt      ds 3               ; per SID voice: signed vibrato, f x amt / 4096
sidTgtLo    ds 3               ; SID frequency the voice is gliding to
sidTgtHi    ds 3
dutyIdx     ds 1               ; duty sequence step
dutyMs      ds 1               ; ms into this step
tremPhL     ds 1               ; NES tremolo phase (10 ms clock)
tremPhH     ds 1
envAtkV     ds 1               ; NES envelope for this sound: attack step (0 = instant)
envDecV     ds 1               ;  decay step
envSusV     ds 1               ;  sustain level
envPeakV    ds 1               ;  peak level
envRelV     ds 1               ;  release factor (0 = cut)
tremA       ds 1               ; NES tremolo amount now (0-15)
mt16        ds 2               ; Mul8: 16-bit result
; v0.12 drums (drums.asm)
beatSel     ds 1               ; G: which beat (also the kit the keytar's drums use)
beatRun     ds 1               ; RETURN: playing
beatStep    ds 1
beatBaseL   ds 1               ; ms time of the current step (unswung)
beatBaseH   ds 1
beatFrac    ds 1               ; 1/16 ms
beatAtL     ds 1               ; when the next step plays (swing included)
beatAtH     ds 1
step16L     ds 1               ; step length in 1/16 ms
step16H     ds 1
dmcBank     ds 1               ; bank the MidiNES has selected ($FF = unknown)
dmcPrio     ds 1               ; priority of the last sample hit
dmcAt       ds 2               ; ticks of it
nzPrio      ds 1               ; same for the noise channel
nzAt        ds 2
nzNote      ds 1               ; noise note sounding ($FF none)
nzOffL      ds 1               ; when it stops
nzOffH      ds 1
drumLvl     ds 1               ; DrumHit: 0 ghost, 1 hit, 2 accent
drumKind    ds 1
drumTom     ds 1
dmcNote     ds 1               ; last sample note sent ($FF none)
nzVol       ds 1               ; noise level last sent (CC7 / 8)
nzLen       ds 1
bA          ds 1               ; BeatPlay: the step's two bytes
bB          ds 1
; v0.13 menu (menu.asm) and device sync (sync.asm)
menuOn      ds 1               ; 1 = the menu is on screen
menuRow     ds 1               ; the setting the cursor is on
latchStyle  ds 1               ; = turns latch on in this style (SMART / HOLD / ADD)
fbLock      ds 1               ; Fat Bass: 0 as the sound says, 1 always, 2 never
syncTempo   ds 1               ; 0 KEYTAR, 1 OWN, 2 SYNTHCART
syncStart   ds 1               ; 0 KEYTAR, 1 OWN
syncRhythm  ds 1               ; 0 PICK BEAT, 1 IGNORE
syncDrums   ds 1               ; 0 IGNORE, 1 PLAY
syncVoice   ds 1               ; 0 PICK SOUND, 1 IGNORE
syncWheel   ds 1               ; 0 BEND, 1 OFF
btnTask     ds 3               ; the keytar's vibrato / portamento / sustain buttons' tasks
btnHeld     ds 3
vibBtn      ds 1               ; held: vibrato
glideBtn    ds 1               ; held: glide
sustainOn   ds 1               ; held: sustain
bendBtn     ds 1               ; held: bend down (like SPACE in BENDS)
wheelMag    ds 1               ; the wheel: 0-255 (255 = 2 semitones)
wheelUp     ds 1               ;  1 = up
bendMag     ds 1               ; the bend everything gets: wheel and SPACE together
bendUp      ds 1
bendSentUp  ds 1
bendSidMag  ds 1               ; ... as the SID last had it
bendSidUp   ds 1
clkCount    ds 1               ; IRQ: clocks received
clkCountSeen ds 1
clkSeenL    ds 1               ; ms of the last clock seen
clkSeenH    ds 1
clkPhase    ds 1               ; IRQ: clock 0-23 in the beat
clkBeat     ds 1               ; IRQ: beat clocks received
clkBeatSeen ds 1
clkAtL      ds 1               ; IRQ: the last beat clock's ticks
clkAtH      ds 1
clkAtS      ds 1               ;  and subTick
clkLastQL   ds 1               ; the beat clock before, in 1/4 ms
clkLastQH   ds 1
clkSkip     ds 1               ; 1 = the next beat clock only restarts the measurement
clkHave     ds 1               ; 0 nothing, 1 a beat clock's time, 2 clk16 measured too
clk16L      ds 1               ; the keytar's beat, averaged, 1/16 ms
clk16H      ds 1
beat16L     ds 1               ; the beat in 1/16 ms (beat demos step from it)
beat16H     ds 1
beatClkL    ds 1               ; ms of the last keytar beat clock
beatClkH    ds 1
beatClkNew  ds 1
beatWait    ds 1               ; following: the next step waits for a beat clock
beatSub     ds 1               ; step within the beat
clkStartBeat ds 1              ; IRQ: clkBeat when a Start came
beatWaitBeat ds 1              ; after a Start, step 1 waits for this beat clock
beatClkNum  ds 1               ; clkBeat of the last beat clock
vibDepth    ds 1               ; FxVars: the vibrato and glide FxTick uses
vibRL       ds 1
vibRH       ds 1
vibDel      ds 1
vibSpr      ds 1
glideK      ds 1
