"""最小 MIDI 写入器（标准 MIDI 文件 type 1），不依赖第三方库。
Song 由若干 Track 组成；每个 Track 一个通道 + 一个 GM 音色，音符按拍（四分音符）计时。"""
import struct

TPQ = 480  # 每拍 tick 数


class Track:
    def __init__(self, name, channel, program, volume=100, pan=64, reverb=60, chorus=0):
        self.name = name
        self.channel = channel
        self.program = program
        self.cc = {7: volume, 10: pan, 91: reverb, 93: chorus}
        self.notes = []  # (开始拍, 时长拍, 音高, 力度)
        self.events = []  # (拍, 控制器, 值)

    def note(self, beat, dur, pitch, vel=90):
        if 0 <= pitch <= 127 and dur > 0:
            self.notes.append((beat, dur, int(pitch), max(1, min(127, int(vel)))))

    def chord(self, beat, dur, pitches, vel=80):
        for p in pitches:
            self.note(beat, dur, p, vel)

    def control(self, beat, cc, value):
        self.events.append((beat, cc, max(0, min(127, int(value)))))


class Song:
    def __init__(self, bpm):
        self.bpm = bpm
        self.tracks = []

    def track(self, *args, **kwargs):
        t = Track(*args, **kwargs)
        self.tracks.append(t)
        return t

    def save(self, path, repeat=1, loop_beats=0.0, tail_beats=0.0):
        """repeat>1 时把整首重复 repeat 遍（每遍 loop_beats 拍），末尾再留 tail_beats 拍空白给混响收尾。"""
        self._repeat, self._loop, self._tail = repeat, loop_beats, tail_beats
        chunks = [self._tempo_track()] + [self._track_chunk(t) for t in self.tracks]
        with open(path, "wb") as f:
            f.write(b"MThd" + struct.pack(">IHHH", 6, 1, len(chunks), TPQ))
            for c in chunks:
                f.write(b"MTrk" + struct.pack(">I", len(c)) + c)

    def _tempo_track(self):
        us = int(60_000_000 / self.bpm)
        data = _vlq(0) + b"\xff\x51\x03" + us.to_bytes(3, "big")
        data += _vlq(0) + b"\xff\x58\x04\x04\x02\x18\x08"  # 4/4 拍
        return data + _vlq(0) + b"\xff\x2f\x00"

    def _track_chunk(self, t):
        ch = t.channel
        ev = []  # (tick, 排序键, 字节)
        name = t.name.encode("utf-8")
        ev.append((0, 0, b"\xff\x03" + _vlq(len(name)) + name))
        if ch != 9:
            ev.append((0, 1, bytes([0xC0 | ch, t.program])))
        for cc, v in t.cc.items():
            ev.append((0, 2, bytes([0xB0 | ch, cc, v])))
        rep = getattr(self, "_repeat", 1)
        loop = getattr(self, "_loop", 0.0)
        events = [(b + k * loop, c, v) for k in range(rep) for b, c, v in t.events]
        notes = [(b + k * loop, d, p, v) for k in range(rep) for b, d, p, v in t.notes]
        tail = getattr(self, "_tail", 0.0)
        if tail > 0:  # 尾部占位事件，保证渲染器播到混响结束
            events.append((rep * loop + tail, 7, t.cc[7]))
        for beat, cc, v in events:
            ev.append((int(round(beat * TPQ)), 2, bytes([0xB0 | ch, cc, v])))
        for beat, dur, pitch, vel in notes:
            on = int(round(beat * TPQ))
            off = int(round((beat + dur) * TPQ)) - 1  # 早 1 tick 松开，避免与同音下一拍重叠
            ev.append((on, 4, bytes([0x90 | ch, pitch, vel])))
            ev.append((max(on + 1, off), 3, bytes([0x80 | ch, pitch, 0])))
        ev.sort(key=lambda e: (e[0], e[1]))
        data = b""
        last = 0
        for tick, _, b in ev:
            data += _vlq(tick - last) + b
            last = tick
        return data + _vlq(0) + b"\xff\x2f\x00"


def _vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(out))
