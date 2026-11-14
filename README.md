# Fat Chip 64

The C64 half of **Fat Chip**: one live instrument made of the C64's SID, a
Game Boy running [Fat Chip GB](../fat-chip-gb) and an NES running MidiNES. Fat
Chip 64 plays the SID itself and drives the other two over the Kerberos MIDI
out. The plans are in `../fat-chip/fat-chip-brief.md`; the Game Boy protocol is
`../fat-chip-gb/docs/fatchip-protocol.md`.

**v0.32:** SPLIT, with a keyboard split.
- **CHORD + LEAD is now SPLIT** (PLAYING, or **C= + V**): **OFF**, **KEY**, **LOW NOTE**, **LATCH 3**. LOW NOTE and LATCH 3 work as before.
- **KEY** is a keyboard split: keys below the split point play the chord (as the notes mode plays them: SMART CHORD makes the left side one-finger chords), keys from it up play the lead's patch on the lead's voices, **LEAD OCTAVE** up (+1 at first, −2…+2). On the C64's keys the split is a key, so it stays put when F1 / F3 change the octave; over MIDI it's a note as the keyboard sends it (before MIDI IN OCTAVE). Row 3 shows SPLIT AT and the note the split key plays now.
- **C= + V** tapped steps SPLIT round. **Hold C= + V and press a key** to put the split there (and turn KEY on): a C64 key sets SPLIT KEY, a note over MIDI sets SPLIT NOTE. That note doesn't play. Both are on the PLAYING page too (shown while SPLIT is KEY).
- KEY's chord side has no latch, like the other SPLIT modes: hold the chord with one hand.
- **CHORD CHANGE**'s SPLIT is renamed **STAGGER** (it works as before).

**v0.31:** BEND OUT on every chip (needs Fat Chip GB v0.09 for the Game Boy).
- **Game Boy:** Fat Chip GB v0.09 has its own release drop (CC 87 amount, CC 88 time), so the note-off goes on time and the Game Boy bends the note down itself while its release rings, smoothly and with no extra MIDI. Its time is the nearest of its sixteen.
- **NES with an envelope** (most patches): Fat Chip already holds the pulses' note-off until its release has faded; now the note bends down while it fades.
- **NES without one** (FAT, RAW): a **fall-off**: the note holds on for TIME as it falls, then stops. Play that voice again and the fall-off ends there. The triangle does the same.
- The SID's BEND OUT is unchanged. In Chip Lab, BEND OUT now has SID / GB / NES buttons like the other effects.
- The Game Boy's BEND IN / OUT CCs only go out when they change, which keeps a sound change short on the link.

**v0.30:** pitch attacks and releases, climbing echoes, tempo tremolo.
- **ATTACK** (PATCH, SID): **BLIP** starts each note up and drops to it, the chiptune way: OCTAVE, OCTAVE + 5TH, or 2 OCTAVES (two up, one up, the note), each step **BLIP STEP** long (10–40 ms). **CLICK** plays the note's first ~20 ms as noise, a hard pick.
- **BEND IN** (all chips): each new note starts AMOUNT semitones away and bends to its pitch over TIME (5 ms – 1 s). Above is a drop, below a scoop. The SID bends each voice; the NES uses its glide; the Game Boy uses its own pitch envelope (CC 80 / 81), so its time is the nearest of its sixteen. Legato notes don't bend in.
- **BEND OUT** (SID; every chip from v0.31): a note you let go sags AMOUNT semitones over TIME while its release rings.
- **REPEAT** gains **SHIFT** (−12 … +12) and **SHIFT IN** (SEMITONES or SCALE STEPS of the key): each echo moves on from the last, so +12 climbs in octaves and −1 SCALE STEPS walks down the key; echoes stop at the top or bottom of the range. **ECHOES**: GB + NES (as before), **ALL CHIPS** (SID 3 joins in, so the echo hops SID → GB → NES), or **ONE CHIP** (one voice, each echo cuts the last).
- **TREMOLO** gains **SYNC** (FREE, or 1 BAR … 1/32 of the tempo, including dotted and triplets; with the beat running it starts each bar on the downbeat) and **MODE**: LFO, **PUMP** (a sidechain-style duck on each cycle, swelling back) or one of three **GATE** patterns (X.X.XX.X, XX.XX.X., X..X..X.). As before, a patch's tremolo plays on the NES (and the SID with the tremolo key); the Game Boy has none.
- The menu's tables moved into the RAM under the KERNAL (copied there at start), which freed about 8 KB for code.
- Patches are 96 bytes now (Chip Lab's SysEx too).

**v0.29:** SMART CHORD sizes; CHORD + LEAD holds what the mode says; the arp leaves the lead alone.
- **SMART CHORD** now has five sizes on C= + X: **5TH**, **TRIAD** (the default), **7TH**, **9TH**, **11TH**. EXT is folded into it, so C= + Z is POLY → SMART CHORD → DRONE. 5TH is the key's fifth (B in C major gets its diminished fifth, F); a note outside the key gets a perfect fifth. The screen shows SMART 5TH / TRI / 7TH / 9TH / 11TH. (13ths are gone.)
- **CHORD + LEAD** holds what the notes mode says: POLY just the chord key's note, SMART CHORD its chord at the size you chose, DRONE the drone.
- **The arp plays the chord part, never the lead:** UNISON leaves the lead's voices alone (no new attacks on each step), and SPARKLE's pair moves to SID 2 and Game Boy pulse 2 (NES pulse 2 or SID 1 without the Game Boy) while CHORD + LEAD is on.

**v0.28:** CHORD + LEAD, two sounds at once. The visualizer is GLITCH only.
- **CHORD + LEAD** (PLAYING): **LOW NOTE**: the first key you press is the chord's root (POLY: root and fifth; SMART CHORD, EXT and DRONE: their chord), and every other key is the lead while you hold it. Let go of the chord key and the next key is the new chord. **LATCH 3**: three keys pressed together (within 100 ms) latch as the chord and keep sounding; every other key is the lead; three more together make a new chord; L lets the chord go. The ordinary latch doesn't apply in CHORD + LEAD (each mode has its own).
- **The lead** is one note, the last key pressed, on one voice per chip (SID 3, Game Boy pulse 1, NES pulse 1; fewer chips, fewer voices), and only while it plays: otherwise those voices fatten the chord as before.
- **Its own patch:** SHIFT + A S D F G / Z X C V B pick it from the banks (LEADS 1, DUTY LEAD, to start); row 3 of the play screen shows it. It brings the SID voice's waveform, width, envelope and octave, the Game Boy pulse's CCs (envelope, duty, glide, detune, LFO) and the NES pulse's duty. Shared with the chord's patch for now: the effects (vibrato, glide on the SID, PWM, filter, tremolo, warble, repeat) and the NES envelope. A voice that changes part plays again with the other patch, so it never keeps the wrong sound.
- **The visualizer** is GLITCH only (F7 on / off); the BARS are gone (about 650 bytes back).

**v0.27:** FINE TUNE, chord changes that glide or wander, DRONE, One Key Play.
- **FINE TUNE** (PLAYING): −50 … +50 cents, for tape loops. It moves every chip: the SID's note frequencies (the notes sounding move at once), the Game Boy's master tune, the NES's bends. It adds to the Synthcart's TUNE TO.
- **Finer NES pitch:** Fat Chip now adds up the NES's pitch offsets (tuning, detune, vibrato, glide) in 1/64 semitone (about 1.6 cents) instead of 1/16, so the MidiNES's own fine bends get used: smoother vibrato and glides, and tuning within a few cents.
- **CHORD CHANGE** (PLAYING) is how the voices move when the chord changes: **AS MODE** (DRONE wanders, the rest ATTACK), **ATTACK** (as before), **GLIDE** (every voice slides to its new note, from the last note it played, even if the patch has no glide), **SPLIT** (**STAGGER** from v0.32: the SID and the bass glide, the Game Boy and NES pulses start again), **WANDER** (each voice moves at its own moment within **WANDER TIME**, 0.5–8 s, the bass late; some glide, some start again). The arp, MONO and One Key Play notes always move at once.
- **DRONE** joins C= + Z (POLY → SMART CHORD → EXT → DRONE): the lowest key held is the root, and the voices play open fifths up from it (**DRONE VOICING**: FIFTHS, FIFTHS + 9TH, SUS4). A new key moves the drone, wandering by default. Latch it and play the root changes.
- **ONE KEY PLAY** (on by default; its own page on the main menu): the **cursor keys** step through a phrase, your timing; alternate the two for fast runs. NOTES: **PENTATONIC PAIRS** (two notes of the key's pentatonic scale, one apart, like the SK-1; minor keys get the minor pentatonic) or **CHORD NOTES** (one note at a time of the chord you hold or latched, over two octaves). MOTION: DOWN, MOSTLY DOWN, **PING PONG**, RANDOM WALK; TURN: NEVER, A LITTLE, **SOME**, A LOT (how often it turns early); DIRECTION DOWN / UP; EACH PRESS **CUTS** the last step or lets it RING ON while you hold it. Its notes are never turned into chords.
- Menu numbers (FINE TUNE, Synthcart TRIM) are a new kind of line, which saved about 1 KB.

**v0.26:** the menu on the F keys, and a HELP page.
- In the menu, **F1 / F3** move up / down a line and **F5 / F7** change the value back / forward (an effect: off / on; a page: opens it). The cursor keys still work. While the menu is open the F keys don't change octave, start the arp or open the visualizer; C= + F1 / F3 / F5 / F7 still turn the chips on and off and panic.
- **HELP: THE KEYS** is the first line of the main menu: a page listing the keyboard shortcuts (plain, C=, RUN/STOP and the menu's). The play screen already shows RETURN: MENU top right.

**v0.25:** Fat Chip tunes itself to the Synthcart.
- The SYNTHCART page has **TUNE TO**: OFF or one of Synthcart's five sounds, with the key and tuning its manual gives for the major / minor scales (SQUARE C −10 cents, LEAD F −10, BASS C# −35, PITFALL C# −30, SAW C# +10). While the Synthcart is in use, Fat Chip moves by those cents on every chip: the SID's note frequencies, the Game Boy's master tune (CC 103), and the NES's bends (to the nearest 1/16 semitone, about 6 cents).
- **MATCH KEY** (ON by default): choosing a sound also sets the key's root to its key (the scale stays), so SMART CHORD, EXT and the arp land on notes the Atari plays. OFF leaves the key to you (K) for experimenting.
- Defaults: TUNE TO SQUARE, MATCH KEY ON; nothing changes until DEVICES says the Synthcart is in use. Synthcart's ten tempos were already right (they agree with the manual's table to 0.01 BPM).

**v0.24:** the new menu, and the devices on MIDI IN.
- **The menu (RETURN)** starts with SID / GAME BOY / MIDINES on or off, then **PATCH**, **PLAYING**, **DEVICES**, and a page for each device that's in use. CRSR DOWN (SHIFT: up) chooses a line and skips the gaps, CRSR RIGHT (SHIFT: back) changes it, RETURN opens a page, SHIFT+RETURN backs out. Every other key keeps its job, so you can play while you change things.
- **PATCH** edits the live patch: MONO, FAT BASS, then the effects. CRSR RIGHT turns an effect on or off; RETURN opens its settings (TONE and ENVELOPE are always on, so RIGHT opens them too). Each setting steps through ready-made values in the shared units (cents, Hz, ms, %), heard at once, and the name gets a `*`. The envelope's Game Boy and NES parts follow the SID's as you change it, and the Game Boy's one LFO goes to VIBRATO when it's on, else PWM.
- **The dice:** SHIFT + / anywhere rolls the patch (as before, now through the same settings and ranges Chip Lab uses); SHIFT + / on a setting in the menu rolls just that setting. C= + / undoes either. No locks.
- **DEVICES:** YAMAHA SHS-10, CASIO DH-100, ATARI SYNTHCART, each IN USE or NOT USED (the SHS-10 starts in use, as before). A device not in use is ignored on MIDI IN.
- **SHS-10:** TEMPO (FOLLOW / IGNORE), SHS-10 RHYTHM (its drum notes on the MidiNES, or IGNORE), START/STOP (its Start / Stop run the built-in beats, or IGNORE), then VOICE BUTTONS, RHYTHM BUTTONS, WHEEL and its three buttons as before. Its rhythm and the built-in beats can play together. RUN/STOP always starts and stops the built-in beats. **Its 25 voice buttons now pick the 25 bank slots** (voice 1–5 = FAT 1–5, 6–10 = PADS 1–5 …; an empty slot does nothing), not the patches by number.
- **DH-100** (MIDI out only: notes, its breath as channel pressure, the portamento button as CC 65, the tone selector as program changes 0–5):
  - BREATH: VOLUME (blow harder, louder: the SID and NES; the Game Boy is left alone, it would click), VOLUME+FILTER, FILTER (the SID's cutoff opens with the breath; a patch without the filter gets the low-pass), or OFF.
  - BREATH FX1 / FX2: a depth that follows the breath (VIBRATO, WARBLE, DETUNE: the patch's, or the ADVANCED amount when it has none; or FILTER), or HELD: an action, on while you blow hard (with a little slack so it doesn't flutter).
  - BREATH FEEL: SOFT / NORMAL / HARD. NOTES: AS PLAYED (the C= + Z mode), CHORD (SMART CHORD) or HARMONY (a third above in the key). PORTAMENTO BUTTON: an action (GLIDE). TONE BUTTONS: the first five pick the banks, the sixth rolls the dice.
- **Synthcart:** TEMPO SYNC snaps tempos to Synthcart's ten. Then **, .** nudge about 3% slower / faster while held (to line up with it by ear), and SHIFT + **, .** step through its ten tempos. TRIM (−8 … +8, about 0.1% a step) makes up for the two machines' clocks drifting apart.
- The old SOUND switches and ADVANCED SOUND page are gone; their job is the PATCH pages now. The ADVANCED amounts stay as what held VIBRATO, GLIDE, TREMOLO and REPEAT use on a patch with none of its own.
- `tools/gen_menu.py` builds the menu and every patch setting's steps from `patch/effects.json` (→ `src/menutab.asm`); `src/patchedit.asm` edits the patch, `src/devices.asm` handles the devices.

**v0.23:** the chips on and off from Chip Lab.
- A SysEx `F0 7D 46 43 02 m F7` turns the SID (bit 0), Game Boy (bit 1) and NES (bit 2) on or off, as C= + F1 / F3 / F5 do. Chip Lab's new SID / GB / NES buttons in its top bar send it, so you can hear a patch on one chip at a time.
- Chip Lab: the note keys (A W S E D …) keep playing after you've touched a slider (before, a slider kept the keyboard until you clicked elsewhere), and a slider being dragged is sent every 120 ms as it moves.

**v0.22:** the keyboard, redone (the tables under Playing).
- **Patches in banks:** A S D F G pick a bank (FAT, PADS, LEADS, BASS, FX) and switch at once; Z X C V B pick patch 1–5 in it. 19 of the 25 slots are filled; Chip Lab favourites fill the rest. V's step-through is gone (the NEXT SOUND action still steps).
- **C= is the "how you play" layer** (arp type and settings, notes mode, extensions, MONO, latch style, SPACE's action, MIDI-in octave, undo the dice, chips on / off, panic) and **RUN/STOP the beats** (tap: start / stop; held + A–H: pick a beat).
- **L** is just latch on / off (NEXT is gone); **=** taps the tempo; **, .** change it by 1 BPM (SHIFT: 10); **/** mutes; **F5** turns the arp on and off in the type you chose with C= + A.
- **K, then a note or a shape** sets key and scale: ten scales, from major and minor to the modes, pentatonic, whole tone and diminished. SMART CHORD and EXT stack "thirds" in whichever scale (whole tone gives augmented chords).
- **The dice (SHIFT + /)** roll the patch's effects; C= + / undoes the last roll.
- C= and RUN/STOP count as modifiers like SHIFT, so pressing one together with its key in the same instant still works.

**v0.21:** voice priority: Polyphony > Fat Bass > the patch's effects.
- Every note you hold gets a voice first. Fat Bass then takes as many of the bass voices (Game Boy wave, NES triangle) as are spare, and REPEAT's echo voices come out of what's left; whatever is still spare stacks on the lowest notes as before.
- Before, Fat Bass always took both bass voices, so with a chip off and a big chord a note could go silent (six notes with the SID off: now all six play, with one bass voice on Fat Bass). REPEAT now takes one echo voice when only one is spare, instead of none.
- The Game Boy and NES always get the note-off for the note they were sent, even when a bass voice moves between Fat Bass and a chord note.
- Voices can be marked as held by the drums; nothing uses that yet, it's ready for the beats overhaul (a sampled kit on the Game Boy wave channel, say).
- **Fix:** the variables added in v0.20 and v0.21 sit past the memory Fat Chip clears at start, so they could start with leftover values (a patch arriving over SysEx right after power-on could be misread). Start now clears them too, and the build stops if they ever outgrow it.

**v0.20:** patches over MIDI, for Chip Lab.
- Fat Chip 64 takes a whole patch as a SysEx message on its MIDI in and plays it at once, notes held or not: its name shows as the sound. V or a program change goes back to the built-in patches.
- The message is `F0 7D 46 43 01 <size>`, the patch's bytes as 4-bit halves, `F7`. Only a complete one with the right size is used; anything else is ignored.
- **Chip Lab** (ReeveHunter.github.io `fatchip/chiplab/`) now builds patches from `patch/effects.json`: effects on and off, limited to some chips, every setting, the dice with locks, blending two patches, your own patches and notes. Each change goes to the C64 as you make it; the on-screen keys and a keyboard plugged into the Mac play it on MIDI channel 1.
- `patch/fatchip-patch.js` is the JavaScript twin of `tools/gen_patches.py` (Chip Lab uses it); `test/test_patch_js.py` checks they agree on every built-in patch and 300 dice-rolled ones. `patch/c64-layout.json` (generated) gives Chip Lab the live patch's layout. `tools/sync_chiplab.sh` copies these files to Chip Lab.
- **MIDI in fix:** a long 1 ms tick could leave a received byte waiting while the next arrived, and the MIDI chip holds only one, so a byte was lost now and then (a note-off, say) in a dense stream. The tick now picks up a waiting byte half way through as well as at the end.
- The 8 × 8 multiply the vibrato uses is unrolled, a little quicker, so the longest main-loop pass stays under 4 ms.

**v0.19:** the built-in patches are written in the shared units, and the Game Boy and NES follow each patch's envelope.
- `patch/patches.json` holds the 19 built-in patches as TONE + effects in the units of `patch/effects.json` (ms, Hz, cents, %). `tools/gen_patches.py` turns them into what each chip plays (SID registers, Fat Chip GB CCs, the NES envelope); the old `tools/gen_sounds.py` is gone. Chip Lab will use the same files.
- **One main envelope.** The Game Boy and NES now follow each patch's envelope (the SID's), so they ring out with it. Before, each chip had its own (FAT's Game Boy notes stopped almost at once and its NES notes had no envelope).
  - The Game Boy has no sustain level yet, so it holds at its level when the sustain is 8 or more, and falls away to silence below that (ELECTRIC PIANO, VIBRAPHONE, ECHO PLUCK).
  - Game Boy envelope times top out at about 1.6 s, so long pad releases stop there.
  - A patch can still give the Game Boy or the NES an envelope of its own (GB / NES ENVELOPE: OWN) when its character needs one. None of the 19 does for now.
- **Other effects follow the shared settings too,** so a few Game Boy details moved a little:
  - Detune is the same number of cents on every chip: FAT's Game Boy pulses are about 7 cents apart like the SID, not 5.
  - WHISTLE and GLIDE BASS's Game Boy glide and WHISTLE's vibrato delay now match the SID's times.
  - PADS's glide, which was on Game Boy pulse 2 only, is now on all three Game Boy channels (and still not the SID).
  - DUTY SHIMMER PAD's Game Boy duty wobble runs at the SID's PWM rate.
- An effect can be limited to some chips in a patch (`"on": ["gb"]`), which is how PADS glides only on the Game Boy and the warble stays on the Game Boy.
- `tools/check_effects.py` now checks the patches too, and the build runs it.

**v0.18:** the live patch, the first step of the patch rework. Nothing should sound different.
- Every sound setting is now read from one block in memory, the **live patch**, instead of straight from the table of built-in sounds. Choosing a sound (V, the menu or a program change) copies that built-in patch into it whole, name included.
- That's what the next steps build on: effect menus that change the live patch, and Chip Lab sending a whole patch to the C64 over MIDI.
- The 19 sounds are the first 19 built-in patches. In the simulator each one sends the same MIDI and sets the same SID registers as in v0.17; the only differences are where a vibrato or envelope step lands a fraction of a millisecond later.
- RAW's three SID widths are now a setting in the patch rather than something tied to its number.
- `patch/effects.json` is the shared definition of a patch (every effect's parameters, ranges, dice ranges, blending and what each chip does); `tools/check_effects.py` checks it. New since it was written: DRIFT on every effect with an oscillator, WANDER on DETUNE, and the Game Boy's filter sweeps as their own effect, WAVE FILTER, separate from the SID's FILTER.

**v0.17:** bends up to two octaves on every chip.
- **VINYL STOP** now takes the SID, Game Boy and NES down two octaves together. Before, only the SID went past one octave.
- **BEND RANGE** (menu) goes up to 24 semitones, for SPACE's BEND DOWN / BEND UP and the keytar's wheel.
- **Game Boy:** its bend range is now set to 24 (CC 85 = 127). The Fat Chip GB ROM already allowed that, so the ROM is unchanged.
- **NES:** the bend tables go to two octaves. Upward bends always fit the MidiNES's range.
- **No wrap-around.** Going down, a Game Boy or NES note only bends as far as the bottom of its channel and holds there; lower would wrap round to a high note.
  - Game Boy: pulses C2, wave C1.
  - NES: pulses A1, triangle A0.
  - So with a two-octave bend, a G3 on the Game Boy pulses stops at C2, while the SID keeps going.
- Let go of VINYL STOP from a full stop, and the beat and arp pick up straight away instead of waiting out the long step they had while stopped.

**v0.16:** speed: MIDI chip interrupts and a quicker keyboard scan.
- **MIDI chip interrupts.** Until now Fat Chip checked the Kerberos's MIDI chip (an MC68B50 in Datel mode) 4,000 times a second, and that alone took 25–30% of the C64's time. Now the chip interrupts only when a byte has come in or the next one can go out, and the timer just ticks each millisecond.
  - At start-up Fat Chip asks the chip for one interrupt to see whether it reaches the C64. If it doesn't, it goes back to the old polling, so nothing breaks either way. (`midiIrq` in memory says which mode it's in.)
  - In the simulator, the main loop now goes round about twice as often with a chord held. The SID's effects run every 4 ms as intended (they had slipped to every 13 ms), the NES effects twice as often, and the longest pass is under 4 ms.
  - MIDI in reacts sooner too, since each byte is picked up the moment it arrives.
- **Quicker keyboard scan.** When the keyboard reads exactly as it did last time (nothing pressed or let go, even with keys held), the scan stops after reading it. That roughly halves the cost of most scans.
- **Glide** (SID) now slides from the voice's last note even if that note was let go just before, like a mono synth's portamento and like the NES's.
- The visualizers step at most every 8 ms, so they look as they did, not twice as fast.
- Lookup tables for the NES bend maths are still an option for later.

**v0.15:** VINYL STOP stops, OCTAVE UP, a GLITCH visualizer, MidiNES vibrato / glide / detune.
- **VINYL STOP** works like a record stopping. Speed and pitch fall together: an octave down at half speed, then the SID carries on down a second octave while fading out. The beat and arp slow down (up to 8x) and then stop completely: silent, no drums. Let go and it all winds back up in 0.5 s. (The Game Boy and NES go down an octave and cut out at the stop.)
- **OCTAVE UP** (held) now moves everything you play up an octave, the overlay and MIDI in, held notes included. Before, it only moved MIDI notes that came in afterwards, so from SPACE it seemed to do nothing.
- **Visualizers:** F7 steps BARS → **GLITCH** → the play screen. GLITCH uses the whole screen with no text:
  - Each new note tears a streak of PETSCII blocks across a row picked by its pitch, in its colour, and held notes keep spattering.
  - Runs of the screen get copied over other places (datamosh) and wiped away, so it fills while you play and dissolves within a second or two when you stop.
  - Kick drums shake the picture (the VIC's fine scroll) and flash the background in the key's colour. VINYL STOP makes it drip down the screen.
- **MidiNES vibrato, glide and detune**, done with pitch bend on each NES channel and added on top of the SPACE / wheel / VINYL STOP bends:
  - **Detune** pushes the pulses apart, by the same amount as the SID's detune (WIDE: more).
  - **Vibrato** is the SID's (depth, rate, delay, spread, TAPE WOBBLE), on the two pulses; the triangle bass stays steady.
  - **Glide** starts each new note bent back to the voice's last note and slides it in, on all three channels.
  - The menu's sound settings now reach the NES. Bends only go out when they change (FAT's steady detune once, not before every note), and in steps of about 1/16 semitone.
  - The NES effects get passes of their own, taking turns with the SID's (one NES channel a pass). In v0.15 that slowed the SID's glide and vibrato a little while the NES was busy too; v0.16's speed-up more than makes up for it.
- **Main loop:** the screen no longer takes a pass after each keyboard scan when there's nothing to draw. The SID's glide and vibrato catch up after up to 32 ms instead of 16, and catching up takes one sum instead of one per 4 ms step.

**v0.14:** keys, menu pages, sound switches, four new actions, a new play screen, a visualizer.
- **Keys:** RETURN opens the menu, SHIFT+RETURN backs out (RETURN never changes a value). F1 / F3 move the octave up / down (the lowest key C0–C6). F5 starts / stops the beat. F7 is the visualizer. The N key is gone.
- **Latch NEXT:** with a chord latched, = shows NEXT and the next key you press starts a new chord. Press = again before that and latch goes off (= with nothing sounding turns it straight off). NEW CHORD is gone from the actions.
- **BEAT TEMPO** (menu, PLAYING): **DEFAULT**: choosing a beat (G or the keytar's rhythm buttons) sets its tempo, and the first start after power-on uses the beat's tempo. After that any tempo you set is kept, even when you stop and start the beat. **IGNORE**: beats never change the tempo. The keytar's clock overrides both.
- **Sound switches** (menu, SOUND): MONO/POLY (AS SOUND / MONO / POLY), FAT BASS, and AS SOUND / ON / OFF for VIBRATO, GLIDE, TREMOLO, DETUNE, WARBLE (Game Boy) and REPEAT. AS SOUND is the sound's own setting. ON uses the **ADVANCED SOUND** page's values, kept for the session: vibrato depth / rate / delay, glide time, tremolo depth / rate / shape, detune, warble, repeat time / repeats / level. OFF switches the effect off. Held VIBRATO, GLIDE, TREMOLO or REPEAT on a sound that has none of its own also uses those values.
- **Menu pages:** the main page (SOUND, PLAYING), ADVANCED SOUND and DEVICE SYNC. RETURN (or CRSR RIGHT) on a page's line opens it; SHIFT+RETURN comes back.
- **New actions** (SPACE and the keytar buttons, held):
  - **FILTER SWEEP:** a filtered sound's SID filter opens to the top. On an unfiltered sound a resonant low-pass comes in and closes down, then opens and switches off when you let go.
  - **BEAT FILL:** snare and toms in place of the beat, then a crash and kick when you let go. With no beat playing, the fill plays alone and stops after the crash.
  - **TAPE WOBBLE:** a slow, deep SID vibrato (each voice drifting its own way), a slow Game Boy pitch wobble and heavy warble.
  - **WIDE:** about twice the SID and Game Boy detune, with the Game Boy pulses panned hard left and right.
- **Play screen, redrawn from scratch:** one line per chip (SID, GAME BOY, MIDINES) with on / off or channels and the three notes it plays. The other lines are the sound, key / mode / latch, arp, tempo / beat / mute, SPACE / octave, held notes, MIDI in, and one line of F-key help. The MIDI OUT counter and the panic / device help lines are gone. Ten small redraw steps (3 ms at most each, down from 17 steps of up to 17 ms), so the screen catches up much faster.
- **Visualizer (F7), a demo:** nine bars, one per voice, grouped SID / GAME BOY / MIDINES. A new note throws its bar to the top, and it settles to a height set by its pitch while the note sounds. The bars breathe with the tremolo and take the colour of their note (C red … B white), with each note's name underneath. Kick drums flash the border in the key's colour. The bottom line shows the sound, the tempo and which beat of the bar is playing. It draws one bar per step, about 13 frames a second, and never delays the keyboard or the arp. The menu opens and closes back to it.

**v0.13:** the menu and keytar sync.
- **Menu (SHIFT+RETURN in and out; v0.14: RETURN in):** CRSR DOWN / SHIFT+CRSR DOWN choose a line, CRSR RIGHT or RETURN the next value, SHIFT+CRSR RIGHT the previous one. Notes and the other keys keep working while it's up; the play screen pauses and redraws when it closes. Sections:
  - **SOUND:** FAT BASS — AS SOUND (default) / ALWAYS / NEVER. REPEAT — AS SOUND / ON / OFF; REPEAT TIME — 1/4, 1/8 DOTTED, 1/8, 1/8 TRIPLET, 1/16, or FREE 80–500 ms; REPEATS — 1–8; REPEAT LEVEL — FULL, 90 … 50 PERCENT (each sound loads its own values when chosen).
  - **PLAYING:** LATCH STYLE — SMART (default) / HOLD / ADD: what = turns on. SPACE — its action (default **BEND DOWN**; , and . step through them too). BEND RANGE — 1–12 semitones (default 2), for the BEND actions and the keytar's wheel.
  - **DEVICE SYNC** (the keytar on MIDI in, and Synthcart):
    - TEMPO FROM — **KEYTAR** / OWN / SYNTHCART. KEYTAR: the keytar's MIDI clock sets the tempo (averaged over beats; the arp and the Game Boy follow; taps are ignored while it runs; 300 ms without a clock and Fat Chip's own tempo is back). SYNTHCART: taps and the beats' tempos snap to Synthcart's ten NTSC tempos (16–52 Atari frames a beat).
    - START/STOP — **KEYTAR** / OWN: the keytar's Start (or synchro start) starts the beat demo, step 1 on its next beat; Stop stops it. While following, every beat re-locks to the keytar's beat clock.
    - RHYTHM BUTTONS — **PICK BEAT** / IGNORE: the keytar's 25 styles pick the six beats by feel (e.g. Hard Rock → ROCK, Jazz Waltz → 6/8).
    - DRUM NOTES — **IGNORE** / PLAY: the keytar's own drum hits on the MidiNES (v0.12 played them always).
    - VOICE BUTTONS — **PICK SOUND** / IGNORE: the keytar's 25 voices pick sounds (0–16 the 17 sounds, 17–24 repeat favourites).
    - WHEEL — **BEND** / OFF: ±2 semitones on the SID, Game Boy and NES (with the SPACE bend on top).
    - VIBRATO / PORTAMENTO / SUSTAIN BUTTON — each **its own action** by default, or any other.
- **Actions** (SPACE and the three keytar buttons share one list). While held: **MUTE**; **BEND DOWN** / **BEND UP** (to BEND RANGE over about 1 s, back in 0.5 s); **VIBRATO** (SID 0.25 semitone at 5.5 Hz if the sound has none, Game Boy LFO on pitch); **TREMOLO** (NES pulses and the SID's volume; the Game Boy has no tremolo yet); **ARP** (the arp runs in the last mode A picked, off again when let go); **STUTTER** (the notes keep sounding but cut out on random 16ths, never the first of a beat; on the beat demo's grid when it plays); **VINYL STOP** (pitch drops an octave over about 1 s and the beat and arp slow to half speed; let go and they wind back up in 0.5 s); **GLIDE** (SID and Game Boy); **SUSTAIN** (like a pedal); **OCTAVE UP** (incoming notes). On a press: **NEW CHORD**, **TAP TEMPO**, **BEAT ON/OFF**, **NEXT SOUND**; or **NOTHING**. The NES doesn't do vibrato or glide yet.
- **REPEAT (echoes):** each key you press plays again REPEATS times, every REPEAT TIME, each REPEAT LEVEL as loud as the last (by velocity). The echoes play on two echo voices (Game Boy pulse 2 and NES pulse 2 first), taken out of the chord while REPEAT is on, unless the notes you hold need them (held notes come first). Each echo lasts 3/4 of the gap. The SID doesn't echo. New sounds: **REPEAT LEAD** (mono lead, three 1/8 repeats at full volume) and **ECHO PLUCK** (a pluck with five dotted-1/8 echoes falling to 70 % each). REPEAT is also an action (held: echoes on).
- **Bends** are exact now (2^(semitones/12) on the SID, the MidiNES bend maths, the Game Boy's bend range set to 12), up to an octave.
- **Voice table:** each voice shows the note it really plays (Fat Bass folding, a sound's octave offsets).
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

**Plain keys (v0.22)**

| Key | Does |
|---|---|
| Overlay keys | Play notes (through the notes mode) |
| A S D F G | Bank: FAT, PADS, LEADS, BASS, FX. Switches at once, keeping the slot (an empty slot: the bank's first patch) |
| Z X C V B | Patch 1–5 in the bank (an empty slot does nothing). The sound line shows bank, slot and patch: `PADS  3 BREATHING PAD` |
| L | Latch on / off (in the LATCH STYLE) |
| K, then a note or a shape | Key and scale, when you let go (the notes don't play): one note or a major triad = major; root + minor third / minor triad = minor; minor triad + 6th = dorian; root + flat 2nd = phrygian; root + sharp 4th = lydian; root + flat 7th = mixolydian; minor triad + major 7th = harmonic minor; root + 4th + 5th = pentatonic; augmented triad = whole tone; diminished triad = diminished. K again first: never mind. SMART CHORD and EXT build in the scale |
| = | Tap tempo |
| , / . (< >) | Tempo −1 / +1 BPM; with SHIFT −10 / +10. With SYNTHCART SYNC: about 3% slower / faster while held; with SHIFT, Synthcart's next tempo |
| / | Mute everything (border red) |
| SHIFT + / (?) | The dice: the effects (detune, glide, warble, filter, PWM, tremolo, vibrato) roll, each on with its chance; tone, envelope and levels stay. The name gets a *. In the menu, on a patch setting: just that setting |
| ; / : | FREE arp speed faster / slower |
| SPACE | Its action while held |
| F1 / F3 | Octave up / down |
| F5 | Arp on / off, in the type C= + A chose |
| F7 | The visualizer (GLITCH) on / off |
| CRSR DOWN / CRSR RIGHT | One Key Play (when it's on): the next step of the phrase |
| RUN/STOP | Tapped: beat start / stop |
| RETURN | The menu (SHIFT+RETURN backs out; F1 / F3 choose a line, F5 / F7 change it; HELP lists the keys) |
| RESTORE (the overlay's top B) | Both screens off / on (C64 and Game Boy) |
| CTRL + F3 / F5 | Game Boy / NES to the next block of channels |

**C= held: how you play**

| C= + | Does |
|---|---|
| A | Arp type: UNISON ↔ SPARKLE (doesn't start it; F5 and the ARP action use it) |
| S / D / F | Arp pattern / speed / SPARKLE octave |
| Z | POLY → SMART CHORD → DRONE |
| X | SMART CHORD size: 5TH → TRIAD → 7TH → 9TH → 11TH |
| C | POLY ↔ MONO |
| L | Latch style: SMART / HOLD / ADD |
| , / . | What SPACE does |
| ; / : | Incoming MIDI notes an octave down / up (−4 to +4) |
| / | Undo the last dice roll |
| F1 / F3 / F5 | SID / Game Boy / NES on or off (SHIFT + F1/F3/F5 too) |
| F7 | Panic (SHIFT + F7 too) |

**RUN/STOP held: beats** (more after the beats overhaul)

| RUN/STOP + | Does |
|---|---|
| A S D F G H | Pick a beat: ELECTRO, JUNGLE, DNB, BOOMBAP, ROCK, 6/8 (and its drum kit) |

**Banks**

| | Z | X | C | V | B |
|---|---|---|---|---|---|
| A: FAT | FAT | RAW | COMBO ORGAN | | |
| S: PADS | PADS | WARM SID PAD | BREATHING PAD | DUTY SHIMMER PAD | TREMOLO GATE |
| D: LEADS | DUTY LEAD | WHISTLE | SCREAMER | REPEAT LEAD | |
| F: BASS | GLIDE BASS | WAVE BASS | | | |
| G: FX | ECHO PLUCK | ELECTRIC PIANO | VIBRAPHONE | WARBLE PAD | SEASICK CHORUS |

The banks are in `patch/patches.json`. The SHS-10's voice buttons 1–25 pick the slots in this order (A1–A5, S1–S5 …); the DH-100's tone buttons pick the banks.

**Smart stacking:** nine voices (3 SID, Game Boy pulse 1, pulse 2, wave, NES
pulse 1, pulse 2, triangle). The Game Boy wave and NES triangle play the
lowest held note folded into E1–E2 (Fat Bass, when the patch has it and
there are voices to spare: every note gets a voice first); leftover voices
stack on the lowest two notes. One note = a nine-voice unison across three
chips. The screen shows which voice plays what. In FAT the voices are
detuned about ±7 cents on every chip, with a little warble on the Game Boy.

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
| `src/bend.asm`, `tools/gen_bend.py` → `src/bendtab.asm` | bends (actions, wheel, VINYL STOP), SPACE's action keys |
| `patch/effects.json`, `patch/patches.json`, `tools/gen_patches.py` → `src/soundtab.asm`; `src/sounds.asm` | the patch definition, the built-in patches (V) and what each becomes on each chip; MONO (C), Fat Bass, SID effects, duty steps |
| `src/drums.asm`, `tools/gen_beats.py` → `src/beats.asm` | keytar drums (MIDI in ch 16), beat demos and kits |
| `src/menu.asm`, `tools/gen_menu.py` → `src/menutab.asm` | the menu (RETURN): its pages and lines, every patch setting's steps |
| `src/patchedit.asm` | editing the live patch: settings, effects on / off, the dice, the envelope and Game Boy LFO kept in step |
| `src/lead.asm` | SPLIT (was CHORD + LEAD): KEY, LOW NOTE, LATCH 3, the lead's voices and patch |
| `test/test_v028.py` | CHORD + LEAD (LOW NOTE, LATCH 3), the lead's patch and voices |
| `test/test_v032.py` | SPLIT KEY: by key on the C64, by note over MIDI, C= + V, LEAD OCTAVE, STAGGER |
| `src/wander.asm` | CHORD CHANGE (glide, stagger, wander), DRONE, One Key Play |
| `test/test_v027.py` | FINE TUNE, NES 1/64 semitones, DRONE, wander, GLIDE, One Key Play |
| `src/devices.asm` | DEVICES: SHS-10 / DH-100 / Synthcart settings, the breath, Synthcart nudges and steps |
| `test/test_v024.py` | the menu, PATCH pages, the dice, DEVICES, SHS-10 voice buttons, DH-100 breath and buttons, Synthcart tempo |
| `src/viz.asm` | the visualizers (F7): BARS, GLITCH |
| `src/nesfx.asm` | MidiNES vibrato, glide, detune (pitch bend) |
| `test/test_v015.py` | VINYL STOP, OCTAVE UP, GLITCH, MidiNES effects |
| `test/test_v016.py` | MIDI chip interrupts (and the polling fallback), the quicker keyboard scan |
| `test/test_v017.py` | two-octave bends on every chip, holding at the bottom of each channel |
| `test/test_v014.py` | keys, latch NEXT, BEAT TEMPO, sound switches, ADVANCED SOUND, the new actions, play screen, visualizer |
| `src/repeat.asm` | REPEAT (echoes) |
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

## Not yet (v0.32)

- Saving settings (a password to type back in) waits; the menu's settings last until the C64 is switched off.
- The DH-100 is untested on the real horn: the breath curve, the HELD threshold and how its MIDI channel mixes with the SHS-10 (both in use: the SHS-10 gets the program changes, the DH-100 gets CC 65) may want tuning.

- The Game Boy has no tremolo of its own yet (it needs a Fat Chip GB feature); in the tremolo sounds the NES does it and the Game Boy holds steady. The SID doesn't take over the tremolo when it's alone.
- The patches' "jobs" (Combo organ's octave-up voice, Bright stack's octave sparkle), a Fat Bass range per patch, and blending are for later.
- FILTER SWEEP is SID only. The NES's vibrato, glide and detune are a little stepped (the MidiNES bends in steps of about 1/16 semitone).
- Noise levels go out as CC7 (level × 8); the MidiNES's response to low levels on the noise channel is untested. Kits are picked from Reeve's Sound Sorter types by name only; tom pitch order (A47 / A46 / A43) is a guess.

## Next

One Key Play (cursor keys, pentatonic pairs), more modes (ambient pads, drone,
chord series), tempo + beats, paddles, MIDI controller input (SHS-10),
Synthcart match.
