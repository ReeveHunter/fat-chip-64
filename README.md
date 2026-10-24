# Fat Chip 64

The C64 half of **Fat Chip**: one live instrument made of the C64's SID, a
Game Boy running [Fat Chip GB](../fat-chip-gb) and an NES running MidiNES. Fat
Chip 64 plays the SID itself and drives the other two over the Kerberos MIDI
out. The plans are in `../fat-chip/fat-chip-brief.md`; the Game Boy protocol is
`../fat-chip-gb/docs/fatchip-protocol.md`.

**v0.07:** a latched chord keeps sounding through a mode, extensions or key change; the next note starts a new chord with the new settings.

**v0.06:** SMART CHORD and EXTENSIONS modes with a key, PADS sound, SMART latch, deferred N, mute everything + SPACE momentary, RESTORE = screens, SPARKLE an octave up.

**v0.05:** tap tempo and the arpeggiator (UNISON / SPARKLE, five patterns, synced or free speed).

**v0.04:** phantom-key filter is optional (G), off at start.

**v0.03:** Build latch, N new chord, phantom-key filter.

**v0.02:** poly synth mode with smart stacking across all three chips, octaves,
latch, SID mute, device on/off and channels, panic, RESTORE test functions.
Versions count in hundredths (v0.01 was the first skeleton, called v0.1 then).

v0.02 fixes the hung Game Boy notes: after about 33 s without MIDI, v0.1's
message queues froze for another 33 s, filled up and dropped messages
(note-offs and panic included).

## Setup

1. **Flash** `bin/fatchip64.prg` to the Kerberos (reevehunter.com/flash) with
   **MIDI emulation = DATEL / Siel / JMS** (same as Cynthcart).
2. **Wire** Kerberos MIDI OUT → a MIDI thru/splitter → the Game Boy's MIDI
   adapter and the MidiNES.
3. **Game Boy:** Fat Chip GB v0.07 or newer, voices on channels **1–5** (its
   default). Fat Chip 64 switches it to the FAT CHIP profile (header shows FC).
4. **NES:** MidiNES on channels **6–10** (D-pad on the NES to shift its block).
   Mode 1 (graphics off) sounds best.
   Different channels? CTRL+F3 / CTRL+F5 on the C64 move the Game Boy / NES
   block to match. Fat Chip 64 warns if the two blocks overlap.

## Playing

The Incredible Musical Keyboard overlay plays two octaves (C to A#); the
lowest key (Q) starts at C3.

| Key | Does |
|---|---|
| Overlay keys | Play notes (through the notes mode) |
| F1 / F3 / F5 / F7 | Octave: Q = C4 / C3 / C2 / C1 (held notes move with it) |
| **Notes mode** | |
| Z | POLY (smart stacking) → SMART CHORD (each key plays its chord in the key) → EXT (the chord plus 7th, 9th, 11th or 13th) |
| X | Extensions: 7TH → 9TH → 11TH → 13TH |
| K + a note | Set the key (hold K, press the key's root; the note doesn't play) |
| L | Major / minor (natural minor) |
| **Sound** | |
| V | FAT (default) / PADS: SID swells through a sweeping low-pass filter with pulse-width wobble, Game Boy slow attack and release with pulse 2 gliding, NES keeps its sharp attacks |
| **Latch** | |
| = | OFF → SMART → HOLD → ADD → OFF. SMART: notes pressed within half a second of the last (or while another key is down) build the chord; after a pause the next note starts a new one. HOLD: a fresh press after letting go of everything starts a new chord. ADD: every press adds a note, pressing a latched note takes it out |
| N | New chord: the current one keeps sounding and the next note starts a new one (screen: N NEXT). Press N twice to clear now |
| **Arp** | |
| A | OFF → UNISON (all nine voices step together) → SPARKLE (two voices arpeggiate over the chord as a pad) |
| S | Pattern: UP, DOWN, UPDOWN, RANDOM, PLAYED (the order you pressed or built the chord) |
| D | Speed: 1/4, 1/8, 1/8T, 1/16, 1/32 of the tempo, or FREE |
| H / J | FREE speed slower / faster (30–1000 ms per step); either one also picks FREE |
| F | SPARKLE arp octave: +0, +1 (default), +2 |
| B | Tap tempo (average of the last four taps; a gap over 2 s starts over). Sent to the Game Boy (CC 107/108) |
| **Sound control** | |
| M | Mute everything: SID volume 0, Game Boy and NES note-offs (their release tails ring out). Border goes red. Notes come back on unmute |
| SPACE | Momentary: while held, flips the mute (cut the sound, or hear it while muted) |
| RESTORE (the overlay's top B) | Both screens off / on (C64 and Game Boy) |
| **Setup-ish (for now)** | |
| SHIFT + F1 / F3 / F5 | SID / Game Boy / NES on or off. Off = silent |
| SHIFT + F7 | Panic: every voice off, latch off, devices set up again |
| CTRL + F3 / F5 | Game Boy / NES to the next block of channels (1–5, 2–6 … 12–16) |
| G | *Test for now:* phantom-key filter on / off (off at start, so phantoms play) |

**Smart stacking:** nine voices (3 SID, Game Boy pulse 1, pulse 2, wave, NES
pulse 1, pulse 2, triangle). The Game Boy wave and NES triangle play the
lowest held note an octave down (bass); every other note gets a voice, lowest
first; leftover voices stack on the lowest two notes. One note = a nine-voice
unison across three chips. The screen shows which voice plays what. The two
Game Boy pulses are detuned about ±5 cents with a little warble, the SID
voices ±7 cents.

## How it works

- **Timing:** CIA1 timer A interrupts every 1/3 ms. Each interrupt feeds the
  MIDI chip one byte; every third one is a 1 ms tick that schedules messages.
- **MIDI out:** each device has its own queue. Game Boy messages go out at most
  one per 3 ms (Reeve's Teensyboy Pro drops messages faster than one per 2 ms)
  and only onto an empty wire, so the gap holds on the cable (≥ 2.5 ms worst
  case). MidiNES messages: one per ms. Running status.
- **The Teensyboy:** in mGB mode it forwards channels 1–15 to the Game Boy, the
  NES's too, at about 0.5 ms per byte with a 64-byte buffer (from its
  Arduinoboy firmware; `test/teensy.py` models it and matches the link test).
  While the Game Boy is on, Fat Chip 64 estimates the bytes waiting in it and
  holds messages back past 45, so bursts go straight out and long streams
  slow to one message per 2 ms.
- **Arp:** steps are timed from the 1 ms clock and checked on every main-loop
  pass; each step is exactly one step after the last, so it keeps tempo (a
  step lands within a few ms). SPARKLE's arp voices: the Game Boy pulses
  (panned hard left / right with CC 10, so the arp ping-pongs in stereo),
  else the NES pulses, else SID 1 and 2. Each arp note rings until its
  voice's next turn; the rest of the chips hold the chord. Fastest step 30 ms
  (the Game Boy link's budget for a nine-voice unison).
- **Screen:** redrawn in 15 small steps, one per keyboard scan, so a redraw
  never holds up the keys or the arp (the longest step is about 5 ms).
- **Phantom keys** (filter on with G): the C64 matrix has no diodes, so three held keys on the
  corners of a rectangle make the fourth read as held. A new key that is the
  corner of such a rectangle waits until it breaks (a real fourth key and a
  ghost look the same). Unused keys are ignored, so a ghost on one costs
  nothing. On the overlay about 12% of 3-note and 36% of 4-note chords can
  lose their newest note this way; BUILD latch never does (one key at a time).
  `test/sim.py` ghosts like the real keyboard.
- **Keyboard:** full matrix scan every 4 ms; modifiers (SHIFT, CTRL, K) are handled first in each scan, so a combination pressed at once still counts; RESTORE is the NMI (presses only;
  40 ms debounce).
- **Memory:** program at $0801 (BASIC and KERNAL banked out, own IRQ/NMI
  vectors), buffers and state at $C000–$C3FF, zero page $10–$2F.

| File | What |
|---|---|
| `src/main.asm` | start, main loop, interrupts |
| `src/midi.asm` | ACIA, wire buffer, paced device queues, Game Boy and MidiNES startup |
| `src/keys.asm` | keyboard scan, commands, RESTORE |
| `src/voices.asm` | SID, smart-stacking allocator, device on/off/channels, panic |
| `src/screen.asm`, `src/data.asm` | screen, key map, voice table, text |
| `tools/gen_tables.py` | SID frequency table (NTSC) |
| `test/sim.py` | py65 C64 model: 1/3 ms timer IRQ, keyboard matrix, RESTORE NMI, MC6850 with real byte timing |
| `test/teensy.py` | Teensyboy model (mGB mode): channel filter, 64-byte buffer, ~0.5 ms per byte |
| `test/test_main.py` | startup, pacing, stacking, devices, octaves, latch, mute, panic, RESTORE, long silence, link budget |
| `src/arp.asm` | tap tempo, arpeggiator |
| `src/pads.asm` | FAT / PADS sound, SPARKLE octave |
| `test/test_modes.py` | smart chord, extensions, key, pads, sparkle octave |
| `test/test_arp.py` | tap tempo, arp modes, patterns, speeds, sparkle panning |
| `test/test_with_gb.py` | end to end: Fat Chip 64 → Teensyboy model → the Fat Chip GB ROM (PyBoy) |

## Building and testing

```sh
DASM=/path/to/dasm ./build.sh          # bin/fatchip64.prg (+ .sym, .lst)
pip install py65 pyboy numpy
./test/run_tests.sh                    # needs ../fat-chip-gb for the end-to-end test
```

## Next

One Key Play (cursor keys, pentatonic pairs), more modes (ambient pads, drone,
chord series), tempo + beats, paddles, MIDI controller input (SHS-10),
Synthcart match.
