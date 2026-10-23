# Fat Chip 64

The C64 half of **Fat Chip**: one live instrument made of the C64's SID, a
Game Boy running [Fat Chip GB](../fat-chip-gb) and an NES running MidiNES. Fat
Chip 64 plays the SID itself and drives the other two over the Kerberos MIDI
out. The plans are in `../fat-chip/fat-chip-brief.md`; the Game Boy protocol is
`../fat-chip-gb/docs/fatchip-protocol.md`.

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
| Overlay keys | Play notes (poly synth, smart stacking) |
| F1 / F3 / F5 / F7 | Octave: Q = C4 / C3 / C2 / C1 (held notes move with it) |
| = | Latch: OFF → HOLD → BUILD → OFF. HOLD: notes keep sounding after you let go; a fresh press after letting go of everything starts a new chord. BUILD: every press adds a note, pressing a latched note takes it out |
| N | New chord: latched notes go (keys still held stay) |
| M | Mute the SID (volume 0: kills the C64's hum; its voices keep their notes) |
| SHIFT + F1 / F3 / F5 | SID / Game Boy / NES on or off. Off = silent: SID volume 0, Game Boy panic, NES all notes off |
| SHIFT + F7 | Panic: every voice off, latch off, devices set up again |
| CTRL + F3 / F5 | Game Boy / NES to the next block of channels (1–5, 2–6 … 12–16) |
| RESTORE (the overlay's top B) | *Test for now:* white border blink, "1 TAP" count, downbeat re-sync (the Game Boy's header blinks the beat) |
| RESTORE twice quickly | *Test for now:* red border blink, "2 TAPS" count, Game Boy screen off / on (CC 112) |

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
- **Screen:** redrawn in 11 small steps, one per keyboard scan, so a redraw
  never holds up the keys (the longest step is about 8 ms).
- **Phantom keys:** the C64 matrix has no diodes, so three held keys on the
  corners of a rectangle make the fourth read as held. A new key that is the
  corner of such a rectangle waits until it breaks (a real fourth key and a
  ghost look the same). Unused keys are ignored, so a ghost on one costs
  nothing. On the overlay about 12% of 3-note and 36% of 4-note chords can
  lose their newest note this way; BUILD latch never does (one key at a time).
  `test/sim.py` ghosts like the real keyboard.
- **Keyboard:** full matrix scan every 4 ms; RESTORE is the NMI (presses only;
  40 ms debounce; the single action is immediate so re-sync lands on the beat).
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
