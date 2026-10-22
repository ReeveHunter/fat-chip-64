"""py65 model of the parts of a C64 Fat Chip 64 uses.

- CIA1 timer A: an IRQ every 341 cycles (1/3 ms) when enabled ($DC0D bit 0)
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
IRQ_CYCLES = 341
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
    def __init__(self, prg=None, sym=None, seed=1):
        prg = prg or os.path.join(ROOT, "bin", "fatchip64.prg")
        sym = sym or os.path.join(ROOT, "bin", "fatchip64.sym")
        self.sym = load_symbols(sym)
        data = open(prg, "rb").read()
        load = data[0] | (data[1] << 8)
        import random
        rnd = random.Random(seed)
        raw = bytearray(rnd.randrange(256) for _ in range(65536))  # RAM is random at power-on
        raw[0xD000:0xE000] = bytes(0x1000)
        raw[load:load + len(data) - 2] = data[2:]
        self.raw = raw
        self.mem = ObservableMemory(subject=raw)
        self.pressed = set()
        self.dc00 = 0xFF
        self.tx = []            # (cycle, byte)
        self.tx_busy_until = 0
        self.timer_on = False
        self.next_irq = IRQ_CYCLES
        self.irq_pending = False

        m = self.mem

        def rd_dc01(_):
            sel = (~self.dc00) & 0xFF
            r = 0xFF
            for k in self.pressed:
                c, rw = KEYS[k]
                if sel & c:
                    r &= ~rw
            return r

        def wr_dc00(_, v):
            self.dc00 = v

        def rd_icr(_):
            v = 0x81 if self.irq_pending else 0
            self.irq_pending = False
            return v

        def wr_icr(_, v):
            if v & 0x80 and v & 1:
                self.timer_on = True
            elif not v & 0x80 and v & 1:
                self.timer_on = False

        def rd_stat(_):
            return 0x02 if self.cpu.processorCycles >= self.tx_busy_until else 0x00

        def wr_tx(_, v):
            now = self.cpu.processorCycles
            assert now >= self.tx_busy_until, "wrote TX while the ACIA was busy"
            self.tx.append((now, v))
            self.tx_busy_until = now + BYTE_CYCLES

        m.subscribe_to_read([0xDC01], rd_dc01)
        m.subscribe_to_write([0xDC00], wr_dc00)
        m.subscribe_to_read([0xDC0D], rd_icr)
        m.subscribe_to_write([0xDC0D], wr_icr)
        m.subscribe_to_read([0xDE06], rd_stat)
        m.subscribe_to_write([0xDE05], wr_tx)
        m.subscribe_to_read([0xD012], lambda _: (self.cpu.processorCycles // 65) & 0xFF)

        self.cpu = MPU(memory=m)
        self.cpu.pc = 0x0810
        self.cpu.sp = 0xFF
        self.run_until(self.sym["Loop"], limit=3_000_000)

    # ------------------------------------------------------------ running
    def step(self):
        cpu = self.cpu
        cpu.step()
        if self.timer_on and cpu.processorCycles >= self.next_irq:
            self.next_irq += IRQ_CYCLES
            self.irq_pending = True
        if self.irq_pending and not (cpu.p & cpu.INTERRUPT):
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
    def press(self, *keys, ms=12):
        for k in keys:
            self.pressed.add(k)
        self.run_ms(ms)

    def release(self, *keys, ms=12):
        for k in keys:
            self.pressed.discard(k)
        self.run_ms(ms)

    def tap(self, *keys, ms=12):
        self.press(*keys, ms=ms)
        self.release(*keys, ms=ms)

    def restore(self):
        self.cpu.nmi()

    # ------------------------------------------------------------ inspection
    def v(self, name, n=1):
        a = self.sym[name]
        return list(self.raw[a:a + n]) if n > 1 else self.raw[a]

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
