"""py65 model of the parts of a C64 Fat Chip 64 uses.

- CIA1 timer A: an IRQ every latch + 1 cycles when enabled ($DC0D bit 0);
  its counter reads back at $DC04/$DC05
- the MC6850's interrupts (control bit 7: a byte in; bits 5-6 = 01: ready
  to send) on the IRQ line, status bit 7 (acia_irq=False: the chip's IRQ
  pin isn't wired, as on a cartridge without it)
- keyboard matrix through CIA1 ports A/B (press keys by name)
- RESTORE: an NMI
- Kerberos MIDI out (MC6850 at $DE04-$DE07, DATEL layout): a byte written to
  TX takes 320 us (327 cycles at 31250 baud) before TDRE is set again; every
  byte is logged with its cycle time.
"""
import os
import re

from py65.devices.mpu6502 import MPU
from py65.memory import ObservableMemory

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
CYCLES_PER_MS = 1023
IRQ_CYCLES = 256
BYTE_CYCLES = 327

# key name -> (column bit for $DC00, row bit for $DC01)
_MATRIX = [
    ["instdel", "return", "crsrright", "f7", "f1", "f3", "f5", "crsrdown"],
    ["3", "w", "a", "4", "z", "s", "e", "lshift"],
    ["5", "r", "d", "6", "c", "f", "t", "x"],
    ["7", "y", "g", "8", "b", "h", "u", "v"],
    ["9", "i", "j", "0", "m", "k", "o", "n"],
    ["+", "p", "l", "-", ".", ":", "@", ","],
    ["pound", "*", ";", "clr", "rshift", "=", "up", "/"],
    ["1", "left", "ctrl", "2", "space", "cbm", "q", "runstop"],
]
KEYS = {name: (1 << c, 1 << r) for c, col in enumerate(_MATRIX) for r, name in enumerate(col)}
# overlay keys in note order (index 0 = lowest C)
OVERLAY = ["q", "2", "w", "3", "e", "r", "5", "t", "6", "y", "7", "u",
           "i", "9", "o", "0", "p", "@", "-", "*", "pound", "up", "clr"]


def load_symbols(path):
    sym = {}
    for line in open(path):
        p = line.split()
        if len(p) >= 2 and re.fullmatch(r"[0-9a-f]{4}", p[1]):
            sym[p[0]] = int(p[1], 16)
    return sym


class C64:
    def __init__(self, prg=None, sym=None, seed=1, channels=(0, 5), acia_irq=True, legacy_keys=None, boot=True):
        """channels = (Game Boy base, NES base) set before the devices start:
        (0, 5) is v0.11's layout (Game Boy on 1-5, MidiNES on 6-10), which the
        older tests assume; None keeps the program's own (11-15, 1-5)."""
        # (v0.41: bin/fatchip64.prg unpacks itself, about a second on a C64;
        #  the tests load what it unpacks to: the image, its tables at $E000.
        #  test_crunch runs the packed file and checks they match)
        prg = prg or os.path.join(ROOT, "bin", "fatchip64-image.prg")
        sym = sym or os.path.join(ROOT, "bin", "fatchip64.sym")
        self.sym = load_symbols(sym)
        data = open(prg, "rb").read()
        load = data[0] | (data[1] << 8)
        import random
        rnd = random.Random(seed)
        raw = bytearray(rnd.randrange(256) for _ in range(65536))  # RAM is random at power-on
        raw[0xD000:0xE000] = bytes(0x1000)
        raw[load:load + len(data) - 2] = data[2:]
        if prg.endswith("-image.prg"):
            hp, hs, he = self.sym["hiPhys"], self.sym["hiStart"], self.sym["hiEnd"]
            raw[hs:he] = raw[hp:hp + he - hs]
        self.raw = raw
        self.mem = ObservableMemory(subject=raw)
        self.pressed = set()
        self._virt = set()
        self._ren = {}
        self.dc00 = 0xFF
        self.tx = []            # (cycle, byte)
        self.tx_busy_until = 0
        self.timer_on = False
        self.latch = IRQ_CYCLES - 1
        self.next_irq = IRQ_CYCLES
        self.irq_pending = False
        self.acia_ctrl = 0
        self.acia_wired = acia_irq
        self.rx_q = []          # (arrival cycle, byte) still on the way in
        self.rx_last = 0
        self.rdr = None         # ACIA receive data register
        self.rx_overrun = 0

        m = self.mem

        def rd_dc01(_):
            # The real matrix has no diodes: current flows from a driven
            # column through any chain of held keys, so three keys on the
            # corners of a rectangle make the fourth corner read as held too
            # (ghosting). Follow the chains.
            cols = (~self.dc00) & 0xFF
            rows = 0
            keys = [KEYS[k] for k in self.pressed]
            if self._xl_busy:                    # (v0.40's keys standing in for an old one: as
                for c, rw in keys:               #  that one key was, no ghosts from it)
                    if cols & c:
                        rows |= rw
                return (~rows) & 0xFF
            while True:
                nrows = rows
                for c, rw in keys:
                    if cols & c:
                        nrows |= rw
                ncols = cols
                for c, rw in keys:
                    if nrows & rw:
                        ncols |= c
                if (nrows, ncols) == (rows, cols):
                    break
                rows, cols = nrows, ncols
            return (~rows) & 0xFF

        def wr_dc00(_, v):
            self.dc00 = v

        def rd_icr(_):
            v = 0x81 if self.irq_pending else 0
            self.irq_pending = False
            return v

        def wr_talo(_, v):
            self.latch = (self.latch & 0xFF00) | v

        def wr_tahi(_, v):
            self.latch = (self.latch & 0xFF) | (v << 8)

        def wr_cra(_, v):
            if v & 0x10:            # force load
                self.next_irq = self.cpu.processorCycles + self.latch + 1

        def rd_ta(i):
            def f(_):
                cnt = max(0, self.next_irq - self.cpu.processorCycles - 1)
                return (cnt >> (8 * i)) & 0xFF
            return f

        def wr_ctrl(_, v):
            self.acia_ctrl = v

        def wr_icr(_, v):
            if v & 0x80 and v & 1:
                self.timer_on = True
            elif not v & 0x80 and v & 1:
                self.timer_on = False

        def rx_update():
            now = self.cpu.processorCycles
            while self.rx_q and self.rx_q[0][0] <= now:
                _, b = self.rx_q.pop(0)
                if self.rdr is None:
                    self.rdr = b
                else:
                    self.rx_overrun += 1

        def rd_stat(_):
            rx_update()
            return (0x02 if self.cpu.processorCycles >= self.tx_busy_until else 0x00) | (1 if self.rdr is not None else 0) \
                | (0x80 if self.acia_asks() else 0)

        def rd_rx(_):
            rx_update()
            b, self.rdr = self.rdr, None
            return 0 if b is None else b

        def wr_tx(_, v):
            now = self.cpu.processorCycles
            assert now >= self.tx_busy_until, "wrote TX while the ACIA was busy"
            self.tx.append((now, v))
            self.tx_busy_until = now + BYTE_CYCLES

        m.subscribe_to_read([0xDC01], rd_dc01)
        m.subscribe_to_write([0xDC00], wr_dc00)
        m.subscribe_to_read([0xDC0D], rd_icr)
        m.subscribe_to_write([0xDC0D], wr_icr)
        m.subscribe_to_write([0xDC04], wr_talo)
        m.subscribe_to_write([0xDC05], wr_tahi)
        m.subscribe_to_write([0xDC0E], wr_cra)
        m.subscribe_to_read([0xDC04], rd_ta(0))
        m.subscribe_to_read([0xDC05], rd_ta(1))
        m.subscribe_to_write([0xDE04], wr_ctrl)
        self.rx_update = rx_update
        m.subscribe_to_read([0xDE06], rd_stat)
        m.subscribe_to_write([0xDE05], wr_tx)
        m.subscribe_to_read([0xDE07], rd_rx)
        m.subscribe_to_read([0xD012], lambda _: (self.cpu.processorCycles // 65) & 0xFF)

        self.cpu = MPU(memory=m)
        self.cpu.pc = 0x0810
        self.cpu.sp = 0xFF
        if not boot:                    # (test_crunch steps it itself)
            return
        self.run_until(self.sym["StartDevices"], limit=3_000_000)
        if channels is not None:
            self.set("gbBase", channels[0])
            self.set("nesBase", channels[1])
        self.run_until(self.sym["Loop"], limit=3_000_000)

    # ------------------------------------------------------------ running
    def acia_asks(self):
        """The MC6850's IRQ output: a byte in (receive interrupt on), or
        ready for the next byte (transmit interrupt on)."""
        c = self.acia_ctrl
        if c & 3 == 3:
            return False
        if c & 0x80 and self.rdr is not None:
            return True
        return (c & 0x60) == 0x20 and self.cpu.processorCycles >= self.tx_busy_until

    def step(self):
        cpu = self.cpu
        cpu.step()
        if cpu.processorCycles >= self.next_irq:
            self.next_irq += self.latch + 1
            if self.timer_on:
                self.irq_pending = True
        if not (cpu.p & cpu.INTERRUPT):
            if self.irq_pending:
                cpu.irq()
            elif self.acia_wired and self.acia_ctrl & 0xA0:
                if self.rx_q and self.rx_q[0][0] <= cpu.processorCycles:
                    self.rx_update()
                if self.acia_asks():
                    cpu.irq()

    def run_until(self, pc, limit=1_000_000):
        n = 0
        while self.cpu.pc != pc:
            self.step()
            n += 1
            assert n < limit, "stuck at %04x" % self.cpu.pc

    def run_ms(self, ms):
        end = self.cpu.processorCycles + ms * CYCLES_PER_MS
        while self.cpu.processorCycles < end:
            self.step()

    # ------------------------------------------------------------ input
    # legacy_keys: the tests written before v0.22's keyboard (V next sound,
    # = latch, Z X C A S D F , . H J with no C=, M mute, G next beat, B tap,
    # F5 beat, L major/minor, K held + a note) press the v0.22 keys that do
    # the same job. New tests leave it off.
    legacy_keys = False
    LEG_CBM = {"z": "z", "x": "x", "c": "c", "s": "s", "d": "d", "f": "f", ",": ",", ".": ".", "h": ";", "j": ":"}
    LEG_SAME = {"m": "/", "=": "l", "b": "=", "f5": "runstop"}
    OVERLAY = ["q", "2", "w", "3", "e", "r", "5", "t", "6", "y", "7", "u"]

    def _legacy_action(self, k):
        """keys whose old job is a sequence now (done on press)"""
        if k == "v":
            n = self.v("soundMode")
            n = (n - 1) % 19 if "lshift" in self.pressed or "rshift" in self.pressed else (n + 1) % 19
            self.midi_in(0xC0, n, ms=2)
        elif k == "a":                           # OFF -> UNISON -> SPARKLE -> OFF
            m = self.v("arpMode")
            if m == 0:
                if self.v("arpLast") != 1:
                    self._mod("a")
                self._raw_tap("f7")              # (the arp's key: F7 from v0.37)
            elif m == 1:
                self._mod("a")
            else:
                self._raw_tap("f7")              # (SPARKLE stays the type, as A left it)
        elif k == "g":
            nxt = (self.v("beatSel") + 1) % 6
            self._raw_press("runstop")
            self._raw_tap("asdfgh"[nxt])
            self._raw_release("runstop")
        elif k == "l":                           # major <-> minor
            root = self.OVERLAY[self.v("keyRoot")]
            shape = [root] if self.v("keyScale") else [root, self.OVERLAY[(self.v("keyRoot") + 3) % 12]]
            self._raw_tap("k")
            self._raw_press(*shape)
            self._raw_release(*shape)
        elif k == "k":                           # K held + a note: the next note sets the root
            self._raw_tap("k")

    def _raw_press(self, *keys, ms=12):
        for k in keys:
            if (self.menu_fkeys and not self._xl_busy and k in self.MENU_F and "cbm" not in self.pressed
                    and self.v("menuOn")):
                self._with(on=["lshift"] if k in ("f1", "f5") else [], keys=[self.MENU_F[k]])
                self._virt.add(k)
                continue
            if self.keys_039 and not self._xl_busy:
                x = self._xlat_press(k)
                if isinstance(x, str):                 # (the same job on another key)
                    self._ren[k] = x
                    self.pressed.add(x)
                    continue
                if x:
                    self._virt.add(k)
                    continue
            self.pressed.add(k)
        self.run_ms(ms)

    def _raw_release(self, *keys, ms=12):
        for k in keys:
            if k in self._ren:
                self.pressed.discard(self._ren.pop(k))
                continue
            if k in self._virt:
                self._virt.discard(k)
                self._xlat_release(k)
                continue
            self.pressed.discard(k)
        self.run_ms(ms)

    # ------------------------------------------------------------ v0.40's keys
    # keys_039: tests written before v0.40's layout (Reeve's Fat Chip Shortcuts)
    # press the v0.39 keys; each old key (with the modifiers held) does the
    # same job with the new keys. test_v040 and later turn it off.
    keys_039 = True
    # menu_fkeys: tests from before v0.43 move round the menu with F1 / F3 (a
    # line up / down) and F5 / F7 (a value back / on); v0.43's menu takes the
    # cursor keys only, so those become SHIFT + CRSR DOWN, CRSR DOWN, SHIFT +
    # CRSR RIGHT, CRSR RIGHT. test_v043 and later turn it off.
    menu_fkeys = True
    MENU_F = {"f1": "crsrdown", "f3": "crsrdown", "f5": "crsrright", "f7": "crsrright"}
    _xl_busy = False
    _virt = set()
    SHIFTS = {"lshift", "rshift"}

    def _with(self, off=(), on=(), keys=(), ms=20, settle=10):
        """take modifiers `off` up and hold `on`, tap `keys`, then put them back"""
        self._xl_busy = True
        saved = self.pressed & set(off)
        added = set(on) - self.pressed
        self.pressed -= saved
        self.pressed |= added
        if saved or added:
            self.run_ms(settle)
        for k in keys:
            self.pressed.add(k)
            self.run_ms(ms)
            self.pressed.discard(k)
            self.run_ms(ms)
        self.pressed -= added
        self.pressed |= saved
        if saved or added:
            self.run_ms(settle)
        self._xl_busy = False

    def _focus_arp(self):
        self.set("fxFocus", self.sym["FOCUS_ARP"])

    def _menu_chan(self, label):
        """the menu's DEVICES page: LABEL a block on (was CTRL + F3 / F5)"""
        self._xl_busy = True
        saved = self.pressed & {"ctrl"}
        self.pressed -= saved
        self.run_ms(30)
        self._raw_tap("return", ms=60)
        for want in ("DEVICES", label):
            for _ in range(40):
                if any(self.screen_row(r).startswith("> " + want) for r in range(25)):
                    break
                self._raw_tap("crsrdown", ms=25)
            if want == "DEVICES":
                self._raw_tap("return", ms=60)
        self._raw_tap("crsrright", ms=150)
        self.pressed.add("lshift")
        self.run_ms(10)
        self._raw_tap("return", ms=50)
        self._raw_tap("return", ms=50)
        self.pressed.discard("lshift")
        self.run_ms(60)
        self.pressed |= saved
        self._xl_busy = False

    def _xlat_press(self, k):
        """k pressed with the old layout in mind: True if it was done another way"""
        p = self.pressed
        shift, cbm, stop, ctrl = bool(p & self.SHIFTS), "cbm" in p, "runstop" in p, "ctrl" in p
        menu = self.v("menuOn")
        if menu and (k in ("f1", "f3", "f5", "f7", "crsrdown", "crsrright", "return") or (k == "/" and shift)):
            return False
        if ctrl:
            if k == "f3":
                self._menu_chan("GAME BOY CHANNELS")
                return True
            if k == "f5":
                self._menu_chan("MIDINES CHANNELS")
                return True
            return False
        if cbm:
            if k == "a":                                  # the arp's type
                return "f7"
            elif k == "s":                                # its pattern (as ArpPatKey does)
                self.set("arpPat", (self.v("arpPat") + 1) % 5)
                self.set("arpIdx", 255)
                self.set("screenDirty", 1)
            elif k == "d":                                # its length: 1/4 .. 1/32, FREE, round
                n = self.v("arpLen")
                if n == 5:
                    self.set("arpSyncLen", 0 ^ 3)
                    self._with(keys=["f5"])
                elif n == 4:
                    self._with(keys=["f5"])
                else:
                    self._focus_arp()
                    self._with(keys=["."])
            elif k == "f":                                # SPARKLE octave, round
                self._with(keys=["f3"] if self.v("arpOct") < 2 else ["f1", "f1"])
            elif k == "z":                                # POLY, SMART CHORD, DRONE
                m = self.v("playMode")
                self.set("playLast", 1 if m == 0 else 0)
                if m == 0:
                    self.set("playMode", 2)
                self._with(off=["cbm"], on=["ctrl"], keys=["crsrdown"])
            elif k == "x":                                # the chord's size
                self._with(off=["cbm"], keys=["n"])
            elif k == "c":                                # POLY <-> MONO
                if self.v("monoMode") == 0 and self.v("playMode") == 0:
                    self._with(off=["cbm"], keys=["f7"])
                elif self.v("monoMode") == 1 and self.v("playMode") == 0:
                    self._with(off=["cbm"], keys=["f7", "f7"])
                else:
                    self.set("monoMode", self.v("monoMode") ^ 1)
            elif k == "l":
                self._with(off=["cbm"], on=["ctrl"], keys=["l"])
            elif k in (",", "."):                         # SPACE's action
                self._with(off=["cbm"], on=["ctrl"], keys=[k])
            elif k in (";", ":"):                         # MIDI in octave down / up
                self._with(off=["cbm"], on=["ctrl"], keys=["f3" if k == ";" else "f1"])
            elif k == "/":                                # undo the dice
                if self.v("undoOk"):
                    self._with(off=["cbm"], keys=["left"])
            elif k in ("f1", "f3", "f5"):                 # the chips
                self._with(off=["cbm"], on=["ctrl"], keys=[{"f1": "a", "f3": "s", "f5": "d"}[k]])
            elif k == "f7":                               # panic
                self._with(off=["cbm"], on=["ctrl"], keys=["m"])
            else:
                return False
            return True
        if stop:
            if k in "asdfgh" and len(k) == 1:
                i = "asdfgh".index(k)
                if i == 5:
                    self._with(keys=["s"])
                else:
                    if self.v("beatBank") != 0:
                        self._with(keys=["a"])
                    self._with(keys=["zxcvb"[i]])
                return True
            return False
        sc = self.v("syncTempo") == 2
        if shift:
            if k == "/":                                  # the dice
                self._with(off=self.SHIFTS, keys=["/"])
            elif k in (",", "."):                         # tempo 10 (Synthcart: its next)
                self._with(off=self.SHIFTS, on=["runstop"], keys=[k] * (1 if sc else 10), ms=10)
            elif k == "f5":                               # SPLIT on / off; held + a note: the split point
                self._with(keys=["k"])
            elif k == "f7":                               # SPLIT's mode
                return "f5"
            else:
                return False
            return True
        if k == "/":                                      # mute
            return "m"
        elif k in (",", ".") and not sc:                  # tempo 1
            self._with(on=["runstop"], keys=[k])
        elif k in (";", ":"):                             # the arp: FREE, then faster / slower
            if self.v("arpLen") != 5:
                self._with(on=["cbm"], keys=["f5"])
            else:
                self._focus_arp()
                self._with(on=["cbm"], keys=["." if k == ";" else ","])
        elif k == "f7":                                   # the arp on / off
            self._with(on=["cbm"], keys=["a"])
        else:
            return False
        return True

    def _xlat_release(self, k):
        if k == "f5" and self.v("spArm"):                 # SHIFT + F5 let go, no note: SPLIT on / off
            self._with(on=["lshift"], keys=["k", "f7"])

    def _raw_tap(self, *keys, ms=12):
        self._raw_press(*keys, ms=ms)
        self._raw_release(*keys, ms=ms)

    def _mod(self, k):
        self._raw_press("cbm", ms=6)
        self._raw_tap(k)
        self._raw_release("cbm", ms=6)

    # v0.37 moved the arp to F7 (F5 is Fat Bass) and the visualizer to RESTORE:
    # tests written before then still say F5 / F7 for those (in play, unmodified)
    fkeys_036 = True

    def _fkeys(self, keys):
        if not self.fkeys_036 or self.v("menuOn") or self.pressed & {"ctrl", "lshift", "rshift", "cbm", "runstop"}:
            return keys, False
        viz = "f7" in keys
        out = tuple(k for k in keys if k != "f7")
        if not self.legacy_keys:
            out = tuple("f7" if k == "f5" else k for k in out)
        return out, viz

    def _viz_toggle(self):
        self.restore()
        self.run_ms(60)
        if self.v("vidState") == 2:              # (the old F7 was GLITCH on / off: past SCREENS OFF)
            self.restore()
            self.run_ms(60)

    def press(self, *keys, ms=12):
        keys, viz = self._fkeys(keys)
        if viz:
            self._viz_toggle()
        if not self.legacy_keys:
            return self._raw_press(*keys, ms=ms)
        plain = []
        for k in keys:
            if k in self.LEG_CBM:
                self._raw_press("cbm", ms=30)          # (C= well before the key, as hands do: a busy MIDI link can hold a scan up 25 ms)
                self._raw_press(self.LEG_CBM[k], ms=0)
            elif k == "f5" and self.pressed & {"ctrl", "lshift", "rshift"}:
                plain.append(k)                  # (CTRL / SHIFT + F5 kept their jobs)
            elif k in self.LEG_SAME:
                plain.append(self.LEG_SAME[k])
            elif k in ("v", "a", "g", "l", "k"):
                self._legacy_action(k)
            else:
                plain.append(k)
        if any(k in self.LEG_CBM for k in keys):
            ms = max(ms, 40)                     # (and held long enough to outlast a long pass)
        self._raw_press(*plain, ms=ms)

    def release(self, *keys, ms=12):
        keys, _ = self._fkeys(keys)
        if not self.legacy_keys:
            return self._raw_release(*keys, ms=ms)
        plain, cbm = [], False
        for k in keys:
            if k in self.LEG_CBM:
                self._raw_release(self.LEG_CBM[k], ms=0)
                cbm = True
            elif k == "f5" and "runstop" not in self.pressed:
                plain.append(k)
            elif k in self.LEG_SAME:
                plain.append(self.LEG_SAME[k])
            elif k in ("v", "a", "g", "l", "k"):
                pass
            else:
                plain.append(k)
        if cbm:
            self._raw_release("cbm", ms=0)
        self._raw_release(*plain, ms=ms)

    def tap(self, *keys, ms=12):
        self.press(*keys, ms=ms)
        self.release(*keys, ms=ms)

    def midi_in(self, *data, ms=0):
        """Bytes arriving at MIDI IN, back to back at 31250 baud from now."""
        t = max(self.cpu.processorCycles, self.rx_last)
        if self.legacy_keys:                     # (v0.24: voice buttons pick bank slots;
            data = list(data)                    #  the old tests meant patch numbers)
            slots = self.v("patchSlot", 19)
            for i in range(len(data) - 1):
                if 0xC0 <= data[i] <= 0xCA and data[i + 1] < 19:
                    data[i + 1] = slots[data[i + 1]]
        for b in data:
            t += BYTE_CYCLES
            self.rx_q.append((t, b))
        self.rx_last = t
        if ms:
            self.run_ms(ms)

    def restore(self):
        self.cpu.nmi()

    # ------------------------------------------------------------ inspection
    def v(self, name, n=1):
        a = self.sym[name]
        return list(self.raw[a:a + n]) if n > 1 else self.raw[a]

    def set(self, name, val):
        self.raw[self.sym[name]] = val

    def midi(self, since=0):
        """Decoded MIDI messages sent after cycle `since`: (cycle, status, d1, d2)."""
        out, status, need, data, t0 = [], None, 0, [], 0
        for cyc, b in self.tx:
            if b & 0x80:
                status, data, t0 = b, [], cyc
                need = 1 if (b & 0xE0) == 0xC0 else 2
                continue
            if status is None:
                continue
            if not data:
                t0 = cyc if not out or out[-1][0] != cyc else t0
            data.append(b)
            if len(data) == need:
                if cyc >= since:
                    out.append((t0, status, data[0], data[1] if need == 2 else None))
                data = []
        return out

    def screen_row(self, r):
        s = ""
        for c in self.raw[0x0400 + 40 * r:0x0400 + 40 * r + 40]:
            c &= 0x7F
            s += chr(c + 64) if 1 <= c <= 26 else (chr(c) if 32 <= c < 64 else "@" if c == 0 else "?")
        return s

    def sid(self, voice):
        base = 0xD400 + 7 * voice
        f = self.raw[base] | (self.raw[base + 1] << 8)
        return f, self.raw[base + 4]
