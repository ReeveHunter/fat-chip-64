# Fat Chip 64

The C64 half of **Fat Chip**: one live instrument made of the C64's SID, a
Game Boy running [Fat Chip GB](../fat-chip-gb) and an NES running MidiNES. Fat
Chip 64 plays the SID itself and drives the other two over the Kerberos MIDI
out. The plans are in `../fat-chip/fat-chip-brief.md`; the Game Boy protocol is
`../fat-chip-gb/docs/fatchip-protocol.md`.

**v0.1 (first playable skeleton):** poly synth mode with smart stacking across
all three chips, device on/off and channels, panic, RESTORE as a command key.

## Setup

1. **Flash** `bin/fatchip64.prg` to the Kerberos (reevehunter.com/flash) with
   **MIDI emulation = DATEL / Siel / JMS** (same as Cynthcart).
2. **Wire** Kerberos MIDI OUT → a MIDI thru/splitter → the Game Boy's MIDI
   adapter and the MidiNES.
3. **Game Boy:** Fat Chip GB v0.6 or newer, voices on channels **1–5** (its
   default). Fat Chip 64 switches it to the FAT CHIP profile (header shows FC).
4. **NES:** MidiNES on channels **6–10** (D-pad on the NES to shift its block).
   Mode 1 (graphics off) sounds best.
   Different channels? SHIFT+F3 / SHIFT+F5 on the C64 move the Game Boy / NES
   block to match. Fat Chip 64 warns if the two blocks overlap.

## Playing

The Incredible Musical Keyboard overlay plays two octaves from C3 (Q) up.

| Key | Does |
|---|---|
| Overlay keys | Play notes (poly synth, smart stacking) |
| F1 / F3 / F5 | SID / Game Boy / NES on or off |
| SHIFT + F3 / F5 | Game Boy / NES to the next block of channels (1–5, 2–6 … 12–16) |
| F7 | Panic: every voice off, devices set up again |
| RESTORE (the overlay's top B) | Downbeat re-sync (border blinks; Game Boy CC 109) |
| RESTORE twice quickly | Screen off / on (the Game Boy follows: CC 112) |

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
- **Keyboard:** full matrix scan every 4 ms; RESTORE is the NMI (presses only;
  40 ms debounce; the single action is immediate so re-sync lands on the beat).
- **Memory:** program at $0801 (BASIC and KERNAL banked out, own IRQ/NMI
  vectors), buffers and state at $C000–$C2FF, zero page $10–$2F.

| File | What |
|---|---|
| `src/main.asm` | start, main loop, interrupts |
| `src/midi.asm` | ACIA, wire buffer, paced device queues, Game Boy and MidiNES startup |
| `src/keys.asm` | keyboard scan, commands, RESTORE |
| `src/voices.asm` | SID, smart-stacking allocator, device on/off/channels, panic |
| `src/screen.asm`, `src/data.asm` | screen, key map, voice table, text |
| `tools/gen_tables.py` | SID frequency table (NTSC) |
| `test/sim.py` | py65 C64 model: 1/3 ms timer IRQ, keyboard matrix, RESTORE NMI, MC6850 with real byte timing |
| `test/test_main.py` | startup, pacing, stacking, devices, panic, RESTORE |
| `test/test_with_gb.py` | end to end: Fat Chip 64's bytes replayed into the Fat Chip GB ROM (PyBoy) |

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
