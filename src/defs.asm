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
ACIA_MODE_RX equ $96           ; ... and an interrupt when a byte comes in
ACIA_MODE_TX equ $B6           ; ... and when the next byte can go out too
ACIA_TDRE   equ $02            ; status: transmit register empty

SCREEN      equ $0400
COLRAM      equ $D800

; ------------------------------------------------------------ timing
TICK_LATCH_MS equ 1023         ; with the MIDI chip's interrupts (midiIrq): 1 ms
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
OCT_DEFAULT equ 48             ; lowest overlay key (Q) = MIDI 48 (C3) at start
VINYL_CUT   equ 248            ; VINYL STOP: stopped from here
OCT_BOTTOM  equ 12             ; F1 / F3: the lowest key goes C0 ..
OCT_TOP     equ 84             ;  .. C6
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
K_CBM       equ $A2           ; v0.22: C= (a modifier: how you play)
K_STOP      equ $A3           ; v0.22: RUN/STOP (tap: beat; held: beat keys)
K_SLASH     equ $A4           ; v0.22: / mute, SHIFT+/ dice
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
; actions (v0.13, v0.14): what SPACE and the keytar's three buttons do. The
; first A_HELD act while held, the rest on a press.
A_MUTE      equ 0
A_BENDDN    equ 1
A_BENDUP    equ 2
A_VIB       equ 3
A_TREM      equ 4
A_ARP       equ 5
A_STUT      equ 6
A_VINYL     equ 7
A_GLIDE     equ 8
A_SUS       equ 9
A_OCTUP     equ 10
A_REPEAT    equ 11
A_SWEEP     equ 12
A_FILL      equ 13
A_WOBBLE    equ 14
A_WIDE      equ 15
A_HELD      equ 16
A_TAP       equ 16
A_BEAT      equ 17
A_SOUND     equ 18
A_NOTHING   equ 19
NUM_ACTS    equ 20
BEND_DOWN_MS equ 4            ; bendLvl 0-255: +1 per 4 ms down (about 1 s)
BEND_TICK   equ 20            ; ms between bend updates to the Game Boy / NES
Q_BACKLOG   equ 8             ; messages waiting: a device skips voice changes
LATCH_SMART equ 1
LATCH_HOLD  equ 2
LATCH_ADD   equ 3
SMART_WINDOW equ 500           ; ms: SMART latch adds notes pressed within this
MODE_POLY   equ 0
MODE_CHORD  equ 1
MODE_DRONE  equ 2             ; v0.27: open fifths that wander (v0.29: EXT folded into SMART CHORD)
MODE_HARM   equ 4             ; v0.24: DH-100 HARMONY (root + a third)
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
midiIrq     ds 1               ; 1 = the MIDI chip's interrupts reach the C64 (v0.16)
gSrc        ds 2               ; GLITCH datamosh source

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
newPending  ds 1               ; latch NEXT (=): the next note starts a new chord
lastPress   ds 2
moment      ds 1               ; SPACE held
muteNow     ds 1               ; mute (M) xor momentary (SPACE)
keyRoot     ds 1               ; 0-11, C = 0
keyScale    ds 1               ; v0.22: 0 major .. 9 diminished (scaleLen)
playMode    ds 1               ; 0 poly, 1 smart chord, 2 extensions
spice       ds 1               ; SMART CHORD's size: 0 5TH, 1 TRIAD, 2 7TH, 3 9TH, 4 11TH
soundMode   ds 1               ; 0 FAT, 1 PADS, 2 RAW
arpOct      ds 1               ; SPARKLE arp: octaves up (0-2)
vOut        ds NUM_VOICES      ; MIDI voices: note actually sounding on the device
sidCtl      ds 1               ; SID waveform bits (saw $20, pulse $40)
padT        ds 2               ; pad LFO phase
chordTmp    ds 8
effMode     ds 1               ; settings the chord builder uses (a latched
effSpice    ds 1               ;  chord keeps the old ones until the next note)
effRoot     ds 1
effScale    ds 1
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
spaceAct    ds 1               ; SPACE's action (, and . or the menu)
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
spaceHeld   ds 1               ; the action SPACE is holding (it ends with that one)
btnAct      ds 3               ; the actions the keytar's buttons are holding
actCnt      ds A_HELD          ; how many keys / buttons hold each held action
bendDir     ds 1               ; BEND DOWN / UP: 1 = up
vinylLvl    ds 1               ; VINYL STOP 0-255
bendHi      ds 1               ; the bend's second octave, 0-192 (bend.asm)
bendSidHi   ds 1
bendSentHi  ds 1
bmL         ds 1               ; the whole bend, 0-384
bmH         ds 1
nbHi        ds 1
vinylCut    ds 1               ; ... stopped: silent
octUpAdd    ds 1               ; OCTAVE UP held: 12
; v0.15 MidiNES effects (nesfx.asm)
nesLast     ds NUM_VOICES      ; the last note each NES voice played
nesGlL      ds NUM_VOICES      ; glide offset, 1/256 semitones (signed)
nesGlH      ds NUM_VOICES
nesVT       ds NUM_VOICES      ; 4 ms steps since the note started (vibrato delay)
nesFxSL     ds NUM_VOICES      ; effects last sent, 1/16 semitones
nesFxSH     ds NUM_VOICES
nesBent     ds NUM_VOICES      ; the channel's bend isn't centred
nesTotL     ds NUM_VOICES      ; the whole bend the channel has (signed 1/16 semitones)
nesTotH     ds NUM_VOICES
nesBNote    ds NUM_VOICES      ; ... worked out for this note
nesUnL      ds NUM_VOICES      ; a pulse's bend per 1/16 semitone x 16 (0: none)
nesUnH      ds NUM_VOICES
nfxTL       ds 1
nfxTH       ds 1
nfxLast     ds 1
nfxV        ds 1               ; the NES voice NesFxTick did last
nfxHave     ds 1
nfxTurn     ds 1               ; 1 = the NES effects go next
nfxGlide    ds 1               ; a NES glide is moving
nfxRun      ds 1               ; NesFxTick steps still to run after an effects change
nfxN        ds 1
nfxK        ds 1
nfxC        ds 1
nfxX        ds 1
nfxL        ds 1
nfxH        ds 1
nvPhL       ds 1
nvPhH       ds 1
nbNote      ds 1
nbMag       ds 1
nbUp        ds 1
nbL         ds 1
nbH         ds 1
bendRange   ds 1               ; menu: BEND RANGE - 1 (0-23)
btL         ds 1               ; BendTotal: signed 1/16 semitones
btIn        ds 4               ; ... what it was last worked out from
btH         ds 1
tremBtn     ds 1               ; TREMOLO held
tremWas     ds 1               ; ... it was last tick (to put things back)
tremSent    ds 1               ; NES CC7 level sent for it (sounds without an envelope)
arpTemp     ds 1               ; ARP held turned the arp on (it goes off on release)
arpLast     ds 1               ; the last arp mode chosen with A (ARP uses it)
stutCut     ds 1               ; STUTTER: cut now
stutAtL     ds 1               ; ... next 16th
stutAtH     ds 1
stutStep    ds 1
; v0.13 REPEAT (repeat.asm)
repeatOn    ds 1               ; the sound's / menu's REPEAT
rpLock      ds 1               ; menu: 0 AS SOUND, 1 ON, 2 OFF
rpTime      ds 1               ; REPEAT TIME (0-4 synced, 5-13 free ms)
rpCount     ds 1               ; REPEATS - 1
rpLevel     ds 1               ; REPEAT LEVEL (0 FULL .. 5 50 %)
rpBusy      ds 1               ; something pending (RepeatTick works)
rpKey       ds 1
rpHi        ds 1
rpK         ds 1
rpVelNow    ds 1
rpY         ds 1
rpVoiceX    ds 1
mtVel       ds 1               ; MidiTo's note-on velocity (VELOCITY, echoes quieter)
vEcho       ds NUM_VOICES      ; an echo voice now
rpOffOn     ds NUM_VOICES      ; its echo stops at rpOff
rpOffL      ds NUM_VOICES
rpOffH      ds NUM_VOICES
rpOn        ds 16              ; echo slots: pending?
rpAtL       ds 16              ;  when
rpAtH       ds 16
rpNote      ds 16
rpVel       ds 16
rpNum       ds 16              ;  which echo of its note (1, 2, ...)
muteVis     ds 1               ; the mute you see (M, MUTE): border, screen
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
; v0.14 sound switches (menu: AS SOUND / ON / OFF) and the ADVANCED SOUND
; values ON uses (kept for the session)
monoLock    ds 1               ; 0 AS SOUND, 1 MONO, 2 POLY
vibLock     ds 1               ; 0 AS SOUND, 1 ON, 2 OFF
glideLock   ds 1
tremLock    ds 1
detLock     ds 1
warbLock    ds 1
uVibDep     ds 1               ; ADVANCED SOUND choices (indexes into the tables in menu.asm)
uVibRate    ds 1
uVibDel     ds 1
uGlide      ds 1
uTremDep    ds 1
uTremRate   ds 1
uTremShape  ds 1
uDet        ds 1
uWarb       ds 1
uRpTime     ds 1
uRpCount    ds 1
uRpLevel    ds 1
detNow      ds 1               ; SID detune in use (voices.asm)
detSent     ds 1               ; ... the held notes have
fxT0        ds 1
beatTempo   ds 1               ; menu BEAT TEMPO: 0 DEFAULT, 1 IGNORE
beatFresh   ds 1               ; 1 = the beat's own tempo hasn't been set yet (start uses it)
menuPage    ds 1               ; 0 main, 1 ADVANCED SOUND, 2 DEVICE SYNC
sweepLvl    ds 1               ; FILTER SWEEP 0-255
sweepOn     ds 1               ; ... the filter switched on for it (unfiltered sounds)
fillK       ds 1               ; BEAT FILL: step in the fill
fillEnd     ds 1               ; ... let go: a crash next step (2: then stop)
fillSolo    ds 1               ; ... the fill started the beat
wideWas     ds 1               ; WIDE / TAPE WOBBLE last sent to the Game Boy
wobWas      ds 1
; v0.14 visualizer (viz.asm)
vizOn       ds 1
vizLvl      ds NUM_VOICES      ; bar height, half rows (0-40)
vizShown    ds NUM_VOICES      ; height drawn
vizNote     ds NUM_VOICES      ; note it last saw
vizKick     ds 1               ; a kick: the border flashes
vizBorder   ds 1
vizV        ds 1
vizStep     ds 1
vizAt       ds 1               ; the visualizer's last step (ticks)
gR          ds 2               ; GLITCH: random numbers
gShake      ds 1               ; ... steps of shaking left
gK          ds 1
gV          ds 1
gLen        ds 1
gChr        ds 1
gCol        ds 1
; v0.18: the live patch. Every sound setting is read from here (the field
; names are in soundtab.asm); choosing a built-in patch copies it in
livePatch   ds 128             ; PATCH_SIZE of it used
sxBuf       ds 128             ; v0.20: a patch arriving over SysEx
sxOn        ds 1               ; 1 = inside a SysEx
sxPos       ds 1               ; data bytes so far
sxCount     ds 1               ; patches received
vFat        ds NUM_VOICES      ; v0.21: this bass voice plays Fat Bass now
vDrum       ds NUM_VOICES      ; v0.21: held by the drums (none yet)
allocFree   ds 1               ; voices spare after the notes and Fat Bass
vSent       ds NUM_VOICES      ; v0.21: the note number each MIDI voice was sent
mlNew       ds 1
cbmDown     ds 1               ; v0.22: C= held
stopDown    ds 1               ; v0.22: RUN/STOP held
stopUsed    ds 1               ;   ... and used with another key (no beat start/stop)
keyCodeNow  ds 1               ; the command key being handled
kArm        ds 1               ; v0.22: K tapped: the next notes pick key and scale
kCount      ds 1               ;   notes still down in that shape
kLow        ds 1               ;   its lowest note
kMaskL      ds 1               ;   its pitch classes (bit = C .. B)
kMaskH      ds 1
kNote       ds NIDX            ;   1 = this key is part of the shape (not played)
exLenM1     ds 1               ; the scale's length - 1 (Expand)
curBank     ds 1               ; v0.22: the bank (A S D F G) and slot (Z X C V B) chosen
curSlot     ds 1
dcE         ds 1               ; DiceRoll: effect, fields, row
dcN         ds 1
dcP         ds 1
undoOk      ds 1               ; v0.22: a dice roll can be undone (C= + /)
diceUndo    ds 128             ;   the live patch before the roll
sxCmd       ds 1               ; v0.23: the SysEx's command (1 patch, 2 chips)
sxArg       ds 1
sxI         ds 1
; v0.24: editing the patch (patchedit.asm)
pnP         ds 1
pnN         ds 1
pnI         ds 1
pnBI        ds 1
pnVL        ds 1
pnVH        ds 1
pnDL        ds 1
pnDH        ds 1
pnBL        ds 1
pnBH        ds 1
peS         ds 1
peQ         ds 1
peN         ds 1
peRow       ds 1
peMode      ds 1
peE         ds 1
peP         ds 1
peCnt       ds 1
peSet       ds 1
peSP        ds 1
peSE        ds 1
mvRow       ds 1               ; the menu line's screen row
; v0.24: the devices
useShs      ds 1               ; DEVICES: 1 = in use
useDh       ds 1
useSc       ds 1
shsTempo    ds 1               ; SHS-10 TEMPO: 0 FOLLOW, 1 IGNORE
shsRhythm   ds 1               ;   SHS-10 RHYTHM: 0 IGNORE, 1 PLAY ON MIDINES
shsStart    ds 1               ;   START/STOP: 0 BUILT-IN BEATS, 1 IGNORE
dhBreath    ds 1               ; DH-100 BREATH: 0 VOLUME, 1 VOLUME+FILTER, 2 FILTER, 3 OFF
dhFx1       ds 1               ;   BREATH FX 1, 2 (BREATH_FX)
dhFx2       ds 1
dhFeel      ds 1               ;   0 SOFT, 1 NORMAL, 2 HARD
dhNotes     ds 1               ;   0 AS PLAYED, 1 CHORD, 2 HARMONY
dhPort      ds 1               ;   PORTAMENTO BUTTON's task
dhTone      ds 1               ;   TONE BUTTONS: 0 PICK BANK, 1 IGNORE
scSync      ds 1               ; SYNTHCART: 0 OFF, 1 SYNC
scTrim      ds 1               ;   TRIM: 0-16 (8 = none)
breath      ds 1               ; the DH-100's breath, 0-127 (after FEEL)
breathRaw   ds 1
breathHeld  ds 2               ; FX 1, 2's held task is on
breathOn    ds 1               ; a breath arrived since DH-100 went in use
dhCC65      ds 1               ; the DH-100's portamento button is down
nudgeOn     ds 1               ; , . held with the Synthcart: the tempo before
nudgeL      ds 1
nudgeH      ds 1
scIdx       ds 1               ; the Synthcart tempo chosen last
scSound     ds 1               ; SYNTHCART TUNE TO: 0 OFF, 1 SQUARE .. 5 SAW
scKey       ds 1               ;   MATCH KEY: 1 ON
mvDir       ds 1               ; the menu: 0 down a line, 1 up
mvBack      ds 1               ;   1: step a value back
mvCnt       ds 1
tuneNow     ds 1
; v0.27: fine tune, chord changes, drone, One Key Play
fineTune    ds 1               ; PLAYING FINE TUNE: 0-100 (50 = 0 cents)
tuneC       ds 1               ; the whole tuning in cents (signed, -100..+100)
tuneN       ds 1               ;   in 1/64 semitones (the NES)
gbTune      ds 1               ;   as the Game Boy's CC 103 value
chgMode     ds 1               ; CHORD CHANGE: 0 AS MODE, 1 ATTACK, 2 GLIDE, 3 STAGGER, 4 WANDER
wanderT     ds 1               ; WANDER TIME (wanderU)
droneVc     ds 1               ; DRONE VOICING: 0 FIFTHS, 1 + 9TH, 2 SUS4
sndGlideK   ds 1               ; the patch's own glide (glideK may add CHORD CHANGE's)
vsGlide     ds 1               ; VoiceSet: glide this change (0: jump)
vWaitOn     ds NUM_VOICES      ; WANDER: the voice waits to move
vDue        ds NUM_VOICES      ;   until this time (32 ms units)
unitNow     ds 1
nbFrac      ds 1               ; NesBendRaw: 1/64 semitones on top (0-3)
okpOn       ds 1               ; ONE KEY PLAY: 1 on
okpSrc      ds 1               ;   0 PENTATONIC PAIRS, 1 CHORD NOTES
okpMotion   ds 1               ;   0 DOWN, 1 MOSTLY DOWN, 2 PING PONG, 3 RANDOM WALK
okpTurn     ds 1               ;   0 NEVER .. 3 A LOT
okpDir      ds 1               ;   0 DOWN, 1 UP
okpRing     ds 1               ;   0 CUTS, 1 RINGS ON
okpPos      ds 1               ; where the phrase is
okpGoing    ds 1               ; 0 going down, 1 up (PING PONG, RANDOM WALK)
okpDown     ds 1               ; cursor keys held (bit 0 CRSR DOWN, bit 1 CRSR RIGHT)
okpCount    ds 1               ; notes sounding (0-4)
okpNotes    ds 4               ; [0, 1] this press, [2, 3] the last (RINGS ON)
okpHit      ds 1               ; a press since the last voice update
okpLen      ds 1               ; the phrase's length
okpList     ds 16              ; the phrase's notes
okpChord    ds 8               ; the chord (CHORD NOTES), from BuildHeld
okpChordN   ds 1
lastEff     ds 1
exFifth     ds 1               ; Expand: 5TH (tones 0 and 2)
exKK        ds 1
numBuf      ds 16              ; the menu: a number to print
; v0.28: Chord + Lead
clMode      ds 1               ; SPLIT: 0 OFF, 1 KEY, 2 BASS, 3 TRIAD (v0.32 / v0.36)
splitKey    ds 1               ; SPLIT KEY: the C64 overlay key (0-23) the lead starts at
splitNote   ds 1               ; SPLIT NOTE: the MIDI note in (as sent) the lead starts at
leadOct     ds 1               ; LEAD OCTAVE (KEY): 0-4 = -2..+2
clKeyOn     ds 1               ; SPLIT is KEY (the menu shows its rows)
clOn        ds 1               ; SPLIT is on (LEAD OCTAVE's row)
clLast      ds 1               ; v0.36: SPLIT's mode when last on (SHIFT + F5 back to it)
clCIdx      ds 8               ; TRIAD: the chord's keys
spArm       ds 1               ; C= + V held: a note sets the split point
spUsed      ds 1               ;   and one did (so letting go doesn't cycle SPLIT)
clChordIdx  ds 1               ; LOW NOTE: the chord's key ($FF: none)
clLeadIdx   ds 1               ; the lead's key ($FF: none)
clBurst     ds 1               ; LATCH 3: keys pressed close together
clLastL     ds 2               ;   when the last one was
clChordN    ds 1               ; LATCH 3: the chord's notes
clChord     ds 8
leadNote    ds 1               ; the lead's note now (NO_NOTE: none)
vLead       ds NUM_VOICES      ; the voice plays the lead
vPat        ds NUM_VOICES      ; the patch on its channel now: 0 chord, 1 lead ($FF: not sure)
leadBank    ds 1
leadSlot    ds 1
leadPatch   ds 128             ; the lead's patch
; v0.30: attacks, bends, echoes, gates
sK          ds 3               ; per SID voice: its own glide k now (BEND IN / OUT), 0: glideK
glK         ds 1               ; GlideStep: the k in use
rdOn        ds 3               ; per SID voice: BEND OUT while its release rings
atkT        ds 3               ; per SID voice: 4 ms steps since its attack (ATTACK)
clickOn     ds 3               ; per SID voice: the CLICK's noise is on
blT         ds 1               ; BlipApply's scratch
atkOn       ds 1               ; this sound has a BLIP or CLICK (FxVars)
nesK        ds NUM_VOICES      ; per NES voice: its own glide k now (BEND IN)
nesRd       ds NUM_VOICES      ; per NES voice: BEND OUT's drop (-semitones; the glide eases it in)
nesFoT      ds NUM_VOICES      ; per NES voice: a fall-off's 10 ms steps left (then the note-off)
foAny       ds 1               ; fall-offs running
tremNes     ds 1               ; v0.33: the NES follows tremA now
sidVolNow   ds 1               ; v0.34: the SID's master volume now (the IRQ moves it
sidVolTgt   ds 1               ;   a step every 2 ms towards this: no big jumps, no thump)
sidRelT     ds 3               ; per SID voice: 50 ms steps its release still rings
relDiv      ds 1               ; (counts 10 ms steps to 50)
tremRnd     ds 1               ; TREMOLO RANDOM: this cycle's level
sinX        ds 1               ; Smooth's
sinT        ds 1
tremMask    ds 1               ;   the patch's tremolo chips (1 NES, 2 SID)
gbCcS       ds 16              ; the Game Boy's CC 80 / 81 / 87 / 88 last sent, per channel
gbK         ds 1
gbCc        ds 1
gbV         ds 1
foW         ds 2               ; NesFxVal's scratch
rpShift     ds 1               ; REPEAT: each echo moved by this (signed)
rpMode      ds 1               ;   bit 0 scale steps, bits 1-2 ECHOES (0 GB + NES, 1 ALL CHIPS, 2 ONE CHIP)
rpCur       ds 1               ;   RepeatPress: the echo's note
rpNEcho     ds 1               ;   echo voices now
tremSyncL   ds 1               ; TREMOLO SYNC: the phase step per 10 ms
tremSyncH   ds 1
tremMode    ds 1               ; TREMOLO MODE now: 0 LFO, 1 PUMP, 2-4 GATEs
d24         ds 3               ; Div24: dividend (quotient)
d24r        ds 2               ;   remainder
dhAct       ds 1               ; the DH-100 portamento button's task while held
brLvl       ds 1               ; breath / 8, last seen
brVol       ds 1               ; the breath's jobs (BreathFlags)
brVib       ds 1
brWarb      ds 1
brDet       ds 1
brFilt      ds 1
brAtt       ds 1               ; BREATH VOLUME's drop, 0-15
ramEnd      ds 0
  if ramEnd > $CA00
    echo "RAM variables run past $CA00: clear more in Start"
    err
  endif
