# Fat Chip 64

The C64 half of **Fat Chip**: one live instrument made of the C64's SID, a
Game Boy running [Fat Chip GB](../fat-chip-gb) and an NES running MidiNES. Fat
Chip 64 plays the SID itself and drives the other two over the Kerberos MIDI
out. The plans are in `../fat-chip/fat-chip-brief.md`; the Game Boy protocol is
`../fat-chip-gb/docs/fatchip-protocol.md`.

**v0.13:** the menu and keytar sync.
- **Menu (SHIFT+RETURN in and out):** CRSR DOWN / SHIFT+CRSR DOWN choose a line, CRSR RIGHT or RETURN the next value, SHIFT+CRSR RIGHT the previous one. Notes and the other keys keep working while it's up; the play screen pauses and redraws when it closes. Sections:
  - **SOUND:** FAT BASS — AS SOUND (default) / ALWAYS / NEVER.
  - **PLAYING:** LATCH STYLE — SMART (default) / HOLD / ADD: what = turns on. SPACE — MUTES / BENDS (as , and .).
  - **DEVICE SYNC** (the keytar on MIDI in, and Synthcart):
    - TEMPO FROM — **KEYTAR** / OWN / SYNTHCART. KEYTAR: the keytar's MIDI clock sets the tempo (averaged over beats; the arp and the Game Boy follow; taps are ignored while it runs; 300 ms without a clock and Fat Chip's own tempo is back). SYNTHCART: taps and the beats' tempos snap to Synthcart's ten NTSC tempos (16–52 Atari frames a beat).
    - START/STOP — **KEYTAR** / OWN: the keytar's Start (or synchro start) starts the beat demo, step 1 on its next beat; Stop stops it. While following, every beat re-locks to the keytar's beat clock.
    - RHYTHM BUTTONS — **PICK BEAT** / IGNORE: the keytar's 25 styles pick the six beats by feel (e.g. Hard Rock → ROCK, Jazz Waltz → 6/8).
    - DRUM NOTES — **IGNORE** / PLAY: the keytar's own drum hits on the MidiNES (v0.12 played them always).
    - VOICE BUTTONS — **PICK SOUND** / IGNORE: the keytar's 25 voices pick sounds (0–16 the 17 sounds, 17–24 repeat favourites).
    - WHEEL — **BEND** / OFF: ±2 semitones on the SID, Game Boy and NES (with the SPACE bend on top).
    - VIBRATO / PORTAMENTO / SUSTAIN BUTTON — each **its own job** by default, or any of: VIBRATO, GLIDE, SUSTAIN, MUTE, BEND DOWN, OCTAVE UP (while held); NEW CHORD, TAP TEMPO, BEAT ON/OFF, NEXT SOUND (on a press); NOTHING. VIBRATO: SID vibrato (0.25 semitone, 5.5 Hz if the sound has none) and the Game Boy's LFO on pitch; GLIDE: SID glide and Game Boy glide; SUSTAIN: like a pedal. The NES doesn't vibrato or glide yet.
- **; is now faster, : slower** (; is the rightmost).
- Keytar accents (velocity 80) count as accents.

**v0.12:** sounds, MONO, drums.
- **Channels:** the MidiNES is on channels **1–5** (its power-on default) and the Game Boy on **11–15**. Fat Chip 64 moves the Game Boy there itself at startup (Fat Chip GB v0.08's CC 113), so nothing needs setting by hand after power-on. CTRL+F3 / F5 still move either block.
- **Sounds (V, SHIFT+V back):** FAT, PADS, RAW plus 14 demo versions of the Chip Lab sounds: DUTY LEAD, WHISTLE, SCREAMER, WARBLE PAD, DUTY SHIMMER PAD, WARM SID PAD, BREATHING PAD, ELECTRIC PIANO, COMBO ORGAN, VIBRAPHONE, GLIDE BASS, WAVE BASS, SEASICK CHORUS, TREMOLO GATE. Row 1 shows the sound, POLY / MONO and FAT BASS. Changing sound while keys are held plays them again with the new sound.
- **MONO (C):** each sound picks POLY or MONO; C flips it. MONO plays the last key pressed (and still held) on every voice; a new key while one is held changes pitch without a new attack (SID: no re-gate; Game Boy: legato, CC 68; MidiNES: its envelope carries on), and letting go returns to the key still held.
- **Fat Bass:** each sound has it on or off. On, the Game Boy wave and NES triangle play the lowest note folded by octaves into E1–E2 (MIDI 28–40), wherever you play; off, they join the other voices at pitch.
- **SID effects** (every 4 ms, on a main-loop pass of their own, taking turns with the screen): vibrato (with a delay; voices in step unless the sound spreads them), glide, filter LFO and per-note filter envelope, pulse-width LFO, duty steps. The MidiNES gets the sound's envelope on its pulses (CC7) with an optional tremolo, and duty steps (CC1). The Game Boy gets its parameters once as CCs (attack, decay, release, duty, wave, LFO for vibrato or duty, detune, levels, glide, warble).
- **Keytar drums:** MIDI in channel 16 (the SHS-10's rhythm) plays the MidiNES: kick 45, snare 52 and tom 48 as samples (sample channel, one at a time: kick > snare > tom > percussion), hat 57 and cymbal 62 as NES noise (closed hats vary their note and level a little). Velocity 127 = accent, 64 = hit, 56 = ghost. The samples come from the kit of the beat chosen with G.
- **Beat demos (G, RETURN):** G picks ELECTRO, JUNGLE, DNB, BOOMBAP, ROCK or 6/8 (Beat Lab patterns, drums only, each with its own kit and tempo); RETURN starts / stops. B taps a new tempo while it plays. Panic stops it.

**v0.11:** MIDI in. Notes arriving at the Kerberos MIDI IN (e.g. the Yamaha SHS-10 keytar) play exactly like overlay keys: notes mode, latch, arp, K + note. Channels 1–11 play; 12–16 are ignored (the SHS-10's accompaniment and drums). H / J move incoming notes down / up an octave (−4 to +4). The screen's MIDI IN line (row 8) shows the octave and the last note and channel received. Nothing from MIDI in is passed on to the Game Boy or NES. The phantom-key toggle (G) and its line are gone (the filter stays off). The main loop is quicker: a screen step and a keyboard scan no longer share a pass (the longest pass went from about 14 ms to 4 ms, so fast arps and MIDI in are steadier).

**v0.10:** = is just OFF / SMART for now (HOLD and ADD wait for the setup menu). The arp starts in FREE at 30 ms and goes down to 10 ms; ; and : are slower / faster (H and J are free again). When a fast arp gets ahead of the Game Boy or NES, that device skips steps instead of overflowing its queue. , and . (the < > keys) pick what SPACE does: MUTES (the momentary mute, default) or BENDS (hold: everything bends down 2 semitones over about 1 s; let go: back up over about 0.5 s).

**v0.09:** a third sound, RAW (classic raw chip: everything square, instant attack and release). In PADS the NES triangle (bass) now just stops on release; the pitch-drop release is kept for a future mono bass sound.

**v0.08:** MidiNES envelopes in PADS: the NES pulses swell and fade with CC7 (A 0.6 s, D 0.4 s, S 11, R 2 s, from the NES Lab), the triangle's release is a quick pitch drop (−24 over 250 ms, slow at first, stopping at its lowest note). At startup the MidiNES gets its hardware envelope off and sweep period 0.

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
3. **Game Boy:** Fat Chip GB **v0.08** or newer. Fat Chip 64 moves its voices
   to channels **11–15** at startup (CC 113) and switches it to the FAT CHIP
   profile (header shows FC), whatever channels it was set to.
4. **NES:** MidiNES on channels **1–5**, its power-on default (D-pad on the NES
   shifts its block). Mode 1 (graphics off) sounds best.
   Different channels? CTRL+F3 / CTRL+F5 on the C64 move the Game Boy / NES
   block (the Game Boy follows by itself). Fat Chip 64 warns if the two blocks overlap.

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
| V / SHIFT+V | Next / previous sound (17: FAT, PADS, RAW and the Chip Lab demos, see v0.12). Each sets POLY / MONO and Fat Bass |
| C | POLY ↔ MONO (legato, last key pressed) |
| | PADS: SID swells through a sweeping low-pass filter with pulse-width wobble, Game Boy slow attack and release with pulse 2 gliding, NES pulses swell and fade (software envelope via CC7), NES triangle just stops. RAW: the classic raw chip sound, FAT's stacking with everything square and instant: SID pulses at 50 / 25 / 12.5%, Game Boy pulses 50 / 25% and the wave channel as a third pulse, NES pulses 50 / 25%, no warble, no filter |
| **Drums** | |
| G | Next beat demo (and the drum kit the keytar uses): ELECTRO, JUNGLE, DNB, BOOMBAP, ROCK, 6/8; sets its tempo |
| RETURN | Beat demo start / stop |
| SHIFT+RETURN | The menu (v0.13) |
| (MIDI in ch 16) | The keytar's rhythm plays the MidiNES drums |
| **Latch** | |
| = | Latch off ↔ on, in the menu's LATCH STYLE: SMART (default: notes pressed within half a second of the last, or while another key is down, build the chord; after a pause the next note starts a new one), HOLD (a fresh press after letting go of everything starts a new chord) or ADD (every press adds a note; pressing a latched note takes it out) |
| N | New chord: the current one keeps sounding and the next note starts a new one (screen: N NEXT). Press N twice to clear now |
| **Arp** | |
| A | OFF → UNISON (all nine voices step together) → SPARKLE (two voices arpeggiate over the chord as a pad) |
| S | Pattern: UP, DOWN, UPDOWN, RANDOM, PLAYED (the order you pressed or built the chord) |
| D | Speed: FREE (default, 30 ms), 1/4, 1/8, 1/8T, 1/16, 1/32 of the tempo |
| ; / : | FREE speed faster / slower (10–1000 ms per step); either one also picks FREE |
| F | SPARKLE arp octave: +0, +1 (default), +2 |
| B | Tap tempo (average of the last four taps; a gap over 2 s starts over). Sent to the Game Boy (CC 107/108) |
| **Sound control** | |
| M | Mute everything: SID volume 0, Game Boy and NES note-offs (their release tails ring out). Border goes red. Notes come back on unmute |
| , / . (< >) | What SPACE does: MUTES (default) ↔ BENDS. Shown on the tempo line |
| SPACE | MUTES: while held, flips the mute (cut the sound, or hear it while muted). BENDS: while held, everything bends down 2 semitones over about 1 s; let go and it comes back over about 0.5 s |
| RESTORE (the overlay's top B) | Both screens off / on (C64 and Game Boy) |
| **Setup-ish (for now)** | |
| SHIFT + F1 / F3 / F5 | SID / Game Boy / NES on or off. Off = silent |
| SHIFT + F7 | Panic: every voice off, latch off, devices set up again |
| CTRL + F3 / F5 | Game Boy / NES to the next block of channels (1–5, 2–6 … 12–16) |
| **MIDI in** | |
| H / J | Incoming MIDI notes an octave down / up (−4 to +4). A held note keeps its pitch until its note-off |

**Smart stacking:** nine voices (3 SID, Game Boy pulse 1, pulse 2, wave, NES
pulse 1, pulse 2, triangle). The Game Boy wave and NES triangle play the
lowest held note folded into E1–E2 (Fat Bass; when the sound has it off they
join the rest); every other note gets a voice, lowest
first; leftover voices stack on the lowest two notes. One note = a nine-voice
unison across three chips. The screen shows which voice plays what. The two
Game Boy pulses are detuned about ±5 cents with a little warble, the SID
voices ±7 cents.

## How it works

- **Timing:** CIA1 timer A interrupts every 1/4 ms. Each interrupt takes a
  received MIDI byte and feeds the MIDI chip one byte; every fourth one is a 1
  ms tick that schedules messages (and checks for a received byte again, so a
  long tick can't miss one: the ACIA holds only one byte).
- **MIDI in:** received bytes go into a 64-byte ring; the main loop parses
  them (running status; realtime and system bytes skipped). Notes on channels
  1–11 take one of eight MIDI slots, note indexes 24–31 next to the overlay's
  0–23, so everything that works with overlay keys works with them. Held notes
  from both merge through a 128-bit map (ascending, a note held twice counts
  once). Panic lets go of every MIDI slot, in case a note-off was lost.
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
  voice's next turn; the rest of the chips hold the chord. Fastest step 10 ms.
  The Game Boy link can't carry a nine-voice unison that fast, so when a
  device's queue has 8 messages waiting, its voices skip the change and catch
  up on a later pass (a note-off is never lost, only steps in between).
- **SPACE bend:** depth 0-255 (+1 per 4 ms down, -2 per 4 ms back up). SID:
  each voice's frequency × (1 − k/256), k = depth/8 − depth/64 (2 semitones at
  the bottom), on every change. Game Boy: pitch bend (Fat Chip GB's range is 2
  semitones) every 20 ms. MidiNES: its bend moves the timer, so the amount
  depends on the note (`p(n) × depth / 1024` for the triangle, twice that for
  the pulses, `p` from the triangle-drop tables), every 20 ms and before each
  new NES note while bent; notes too near the bottom of the NES range don't
  bend. Panic centres everything.
- **MidiNES envelopes (PADS):** the NES Lab showed CC7 changes a sounding note's volume, so the pulses get a software envelope: CC7 0, note-on, then the 16 levels on a 10 ms clock; the note-off waits until the release reaches 0. The triangle has no volume, so its release is a pitch drop (Reeve's Logic plugin trick) made from precomputed tables (`p(n) × h(step)`), a bend every 4 ms (8 ms while the Game Boy is on: the Teensyboy forwards the NES channels too and can't take more), stopping at MIDI 21 where the triangle's 11-bit timer would wrap. Mute, panic, turning the NES off and switching back to FAT cut at once.
- **Screen:** redrawn in 16 small steps, one per keyboard scan, each on its
  own main-loop pass 2 ms after the scan, so a redraw never holds up the keys,
  the arp or MIDI in (the longest pass is about 4 ms).
- **Phantom keys** (filter off; its toggle left for a setup menu): the C64 matrix has no diodes, so three held keys on the
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
| `test/sim.py` | py65 C64 model: 1/4 ms timer IRQ, keyboard matrix, RESTORE NMI, MC6850 with real byte timing |
| `test/teensy.py` | Teensyboy model (mGB mode): channel filter, 64-byte buffer, ~0.5 ms per byte |
| `test/test_main.py` | startup, pacing, stacking, devices, octaves, latch, mute, panic, RESTORE, long silence, link budget |
| `src/arp.asm` | tap tempo, arpeggiator |
| `src/pads.asm` | Tri, SPARKLE octave (the sounds moved to sounds.asm) |
| `src/midiin.asm` | MIDI in: receive, parse, MIDI slots, H / J octave |
| `src/bend.asm` | SPACE modes, SPACE bend |
| `src/sounds.asm`, `tools/gen_sounds.py` → `src/soundtab.asm` | sounds (V), MONO (C), Fat Bass, SID effects, duty steps |
| `src/drums.asm`, `tools/gen_beats.py` → `src/beats.asm` | keytar drums (MIDI in ch 16), beat demos and kits |
| `src/menu.asm` | the menu (SHIFT+RETURN) |
| `src/sync.asm` | keytar clock / Start / Stop / buttons / wheel, Synthcart tempos |
| `test/test_v013.py` | menu, keytar sync, wheel, buttons, Synthcart, ; / : |
| `test/test_v012.py` | channels, sounds, MONO legato, Fat Bass, effects, keytar drums, beat demos, loop timing |
| `test/test_gb_channels.py` | end to end: CC 113 moves Fat Chip GB to 11–15, chord and MONO legato arrive |
| `src/nesenv.asm`, `src/nestables.asm` | MidiNES envelopes (PADS): CC7 envelope on the pulses, triangle release drop |
| `test/test_nesenv.py` | MidiNES startup settings, envelopes, drop, hard cuts |
| `test/test_modes.py` | smart chord, extensions, key, pads, sparkle octave |
| `test/test_arp.py` | tap tempo, arp modes, patterns, speeds, sparkle panning |
| `test/test_v010.py` | = OFF / SMART, the 10 ms arp (no hung notes), : ;, SPACE modes and bend |
| `test/test_fast_link.py` | 10 ms arp + bend through the Teensyboy model: nothing lost |
| `test/test_midiin.py` | MIDI in: notes, running status, channels, octave, latch / modes / arp, panic, receive timing |
| `test/test_with_gb.py` | end to end: Fat Chip 64 → Teensyboy model → the Fat Chip GB ROM (PyBoy) |

## Building and testing

```sh
DASM=/path/to/dasm ./build.sh          # bin/fatchip64.prg (+ .sym, .lst)
pip install py65 pyboy numpy
./test/run_tests.sh                    # needs ../fat-chip-gb for the end-to-end test
```

## Not yet (v0.12)

- The Game Boy has no tremolo of its own yet (it needs a Fat Chip GB feature); in the tremolo sounds the NES does it and the Game Boy holds steady. The SID doesn't take over the tremolo when it's alone.
- The patches' "jobs" (Combo organ's octave-up voice, Bright stack's octave sparkle), adjustable parameters, Fat Bass lock, a Fat Bass range per patch, and blending are for later.
- Noise levels go out as CC7 (level × 8); the MidiNES's response to low levels on the noise channel is untested. Kits are picked from Reeve's Sound Sorter types by name only; tom pitch order (A47 / A46 / A43) is a guess.

## Next

One Key Play (cursor keys, pentatonic pairs), more modes (ambient pads, drone,
chord series), tempo + beats, paddles, MIDI controller input (SHS-10),
Synthcart match.
