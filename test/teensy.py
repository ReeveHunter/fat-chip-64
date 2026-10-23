"""Model of a Teensyboy (Pro) in mGB mode, from the Arduinoboy firmware it is
forked from (catskull/Arduinoboy, Mode_MidiGb.ino) and Reeve's link tests:

- MIDI bytes land in the Teensy's serial receive buffer (64 bytes); a byte
  that arrives when it's full is lost
- the main loop takes one byte at a time. Status bytes on a mapped channel
  (default map: MIDI 1-15 -> Game Boy 1-15; 16 isn't mapped) are sent on,
  then the data bytes that follow (running status works). Bytes for other
  channels and system bytes are skipped at once
- each byte sent to the Game Boy costs about 520 us (8 bit-banged bits plus
  GB_MIDI_DELAY = 500 us)

That matches the measurements: 1 message per 2 ms is clean, 1 per 1 ms loses.
"""
SEND_CYCLES = 532           # ~520 us per forwarded byte at 1.023 MHz
BUFFER = 64
MAPPED = set(range(15))     # MIDI channels (0-based) the adapter forwards


def forward(wire, buffer=BUFFER, mapped=MAPPED):
    """wire: [(cycle, byte)] from Fat Chip 64.
    Returns ([(cycle, byte)] reaching the Game Boy, bytes lost)."""
    out, rx, lost = [], [], 0
    busy_until = 0
    send = False            # forwarding the current status's data bytes
    i = 0
    t = 0
    while i < len(wire) or rx:
        # next event: a byte arriving, or the loop taking a byte
        nxt_arrival = wire[i][0] if i < len(wire) else None
        if rx and (nxt_arrival is None or busy_until <= nxt_arrival):
            t = max(t, busy_until)
            b = rx.pop(0)
            if b & 0x80:
                if (b & 0xF0) == 0xF0:
                    pass                    # system: midiValueMode = false; doesn't stop forwarding
                else:
                    send = (b & 15) in mapped
                    if send:
                        out.append((t, b))
                        busy_until = t + SEND_CYCLES
                        continue
            elif send:
                out.append((t, b))
                busy_until = t + SEND_CYCLES
                continue
            busy_until = t
        else:
            t, b = wire[i]
            i += 1
            if len(rx) < buffer:
                rx.append(b)
            else:
                lost += 1
    return out, lost
