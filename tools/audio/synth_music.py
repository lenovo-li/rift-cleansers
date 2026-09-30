"""程序化合成 3 首可无缝循环的背景音乐（纯 Python 标准库，无外部依赖，原创无版权问题）。
用法: python tools/audio/synth_music.py
输出: assets/audio/music/{explore,battle,boss}.wav（22050 Hz 单声道 16 位）
风格：D 小调暗黑氛围。探索 = 低沉长音 + 稀疏拨弦；战斗 = 加鼓和低音固定音型；Boss = 更快、更刺耳的主旋律。
每首长度都是整数小节，音符在小节内收尾，所以首尾相接不会有爆音。
"""
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio", "music")

# D 小调音阶（MIDI 音高）
D_MINOR = [62, 64, 65, 67, 69, 70, 72]


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


class Track:
    def __init__(self, seconds):
        self.n = int(seconds * RATE)
        self.buf = [0.0] * self.n

    def add(self, start, dur, fn, gain):
        """在 start 秒处叠加 fn(t, local_t) 生成的 dur 秒声音。越界部分绕回开头（保证循环连续）。"""
        s0 = int(start * RATE)
        length = int(dur * RATE)
        for i in range(length):
            self.buf[(s0 + i) % self.n] += fn(i / RATE, dur) * gain

    def save(self, path):
        peak = max(abs(x) for x in self.buf) or 1.0
        scale = 0.85 / peak
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(x * scale * 32767)) for x in self.buf))


def env(t, dur, attack, release):
    """线性起音 + 线性释音的包络。"""
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def pad(midi):
    """长音铺底：两个略微失谐的锯齿近似（前 4 个谐波）+ 缓慢颤动。"""
    f = freq(midi)

    def fn(t, dur):
        e = env(t, dur, 1.5, 1.5)
        s = 0.0
        for detune in (0.997, 1.003):
            for h in range(1, 5):
                s += math.sin(2 * math.pi * f * detune * h * t) / h
        return s * e * (0.8 + 0.2 * math.sin(2 * math.pi * 0.3 * t))
    return fn


def pluck(midi):
    """拨弦：快速衰减的三角波。"""
    f = freq(midi)

    def fn(t, dur):
        phase = (f * t) % 1.0
        tri = 4 * abs(phase - 0.5) - 1
        return tri * math.exp(-t * 5.0) * env(t, dur, 0.005, 0.05)
    return fn


def bass(midi):
    f = freq(midi)

    def fn(t, dur):
        sq = 1.0 if (f * t) % 1.0 < 0.5 else -1.0
        return (0.6 * math.sin(2 * math.pi * f * t) + 0.25 * sq) * math.exp(-t * 3.0) * env(t, dur, 0.005, 0.05)
    return fn


def lead(midi):
    """Boss 主旋律：带失真的锯齿。"""
    f = freq(midi)

    def fn(t, dur):
        saw = 2 * ((f * t) % 1.0) - 1
        vib = 1.0 + 0.004 * math.sin(2 * math.pi * 5.5 * t)
        saw = 2 * ((f * vib * t) % 1.0) - 1
        return math.tanh(saw * 2.5) * env(t, dur, 0.02, 0.1)
    return fn


def kick(t, dur):
    f = 110 * math.exp(-t * 18) + 45
    return math.sin(2 * math.pi * f * t) * math.exp(-t * 9)


def make_snare(rng):
    noise = [rng.uniform(-1, 1) for _ in range(int(0.25 * RATE))]

    def fn(t, dur):
        i = min(int(t * RATE), len(noise) - 1)
        return (noise[i] * 0.7 + 0.3 * math.sin(2 * math.pi * 190 * t)) * math.exp(-t * 16)
    return fn


def make_hat(rng):
    noise = [rng.uniform(-1, 1) for _ in range(int(0.06 * RATE))]

    def fn(t, dur):
        i = min(int(t * RATE), len(noise) - 1)
        # 一阶高通：差分让噪声更「嘶」
        prev = noise[i - 1] if i > 0 else 0.0
        return (noise[i] - prev) * math.exp(-t * 60)
    return fn


# 和弦进行（小节级）：Dm - B♭ - Gm - A（A 是小调里的属和弦，给紧张感）
PROGRESSION = [[50, 57, 62, 65], [46, 53, 58, 62], [43, 50, 55, 58], [45, 52, 57, 61]]


def explore(rng):
    bpm, bars = 70, 16
    beat = 60.0 / bpm
    tr = Track(bars * 4 * beat)
    for bar in range(bars):
        chord = PROGRESSION[bar % 4]
        t0 = bar * 4 * beat
        for note in chord:
            tr.add(t0, 4 * beat, pad(note), 0.05)
        for step in range(8):
            if rng.random() < 0.45:
                tr.add(t0 + step * beat / 2, beat * 1.5, pluck(rng.choice(D_MINOR) + 12), 0.18)
    return tr


def battle(rng):
    bpm, bars = 128, 16
    beat = 60.0 / bpm
    tr = Track(bars * 4 * beat)
    snare, hat = make_snare(rng), make_hat(rng)
    for bar in range(bars):
        chord = PROGRESSION[bar % 4]
        t0 = bar * 4 * beat
        for note in chord[1:]:
            tr.add(t0, 4 * beat, pad(note), 0.035)
        for step in range(8):  # 八分音符低音固定音型
            note = chord[0] - 12 + (12 if step % 4 == 3 else 0)
            tr.add(t0 + step * beat / 2, beat / 2, bass(note), 0.35)
        for b in range(4):
            tr.add(t0 + b * beat, 0.4, kick, 0.6 if b % 2 == 0 else 0.4)
            if b % 2 == 1:
                tr.add(t0 + b * beat, 0.25, snare, 0.35)
            tr.add(t0 + b * beat + beat / 2, 0.06, hat, 0.12)
        if bar % 2 == 1:  # 每两小节一句拨弦动机
            for i, off in enumerate((0, 2, 4, 3)):
                tr.add(t0 + (2 + i * 0.5) * beat, beat, pluck(D_MINOR[off] + 12), 0.2)
    return tr


def boss(rng):
    bpm, bars = 150, 16
    beat = 60.0 / bpm
    tr = Track(bars * 4 * beat)
    snare, hat = make_snare(rng), make_hat(rng)
    motif = [0, 0, 5, 4, 3, 1, 2, 0]  # 音阶序号，八分音符
    for bar in range(bars):
        chord = PROGRESSION[bar % 4]
        t0 = bar * 4 * beat
        for step in range(16):  # 十六分音符低音
            tr.add(t0 + step * beat / 4, beat / 4, bass(chord[0] - 12), 0.3)
        for b in range(4):
            tr.add(t0 + b * beat, 0.4, kick, 0.65)
            tr.add(t0 + b * beat + beat / 2, 0.4, kick, 0.35)
            if b % 2 == 1:
                tr.add(t0 + b * beat, 0.25, snare, 0.45)
            for h in range(2):
                tr.add(t0 + b * beat + h * beat / 2 + beat / 4, 0.06, hat, 0.1)
        if bar >= 4:  # 前 4 小节只有节奏，之后主旋律进入
            shift = 1 if bar % 4 == 3 else 0
            for i, deg in enumerate(motif):
                note = D_MINOR[(deg + shift) % len(D_MINOR)] + (12 if bar >= 12 else 0)
                tr.add(t0 + i * beat / 2, beat / 2 * 0.9, lead(note), 0.09)
    return tr


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("explore", explore), ("battle", battle), ("boss", boss)):
        track = fn(random.Random(hash(name) & 0xFFFF))
        path = os.path.join(OUT, name + ".wav")
        track.save(path)
        print("[music] %s: %.1f s, %d KB" % (name, track.n / RATE, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
