"""程序化合成 4 套背景音乐（每套 3 首：explore/battle/boss），每张地图一套。
用法: python tools/audio/synth_music.py
输出: assets/audio/music/<map_id>_{explore,battle,boss}.wav（22050 Hz 单声道 16 位）
地图主题：灰烬王城（D 小调暗黑）、霜冻冰原（E 小调空灵）、沙海遗迹（A 小调神秘）、幽暗森林（F# 小调诡异）
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

# 四张地图的音乐主题（调式根音 + 音阶 + 和弦进行 + BPM 范围）
THEMES = {
    "ashen_city": {
        "root": 62, "scale": [0, 2, 3, 5, 7, 8, 10],  # D 小调
        "progression": [[0, 7, 12, 15], [-4, 3, 8, 12], [-7, 0, 5, 8], [-5, 2, 7, 11]],  # i-VI-iv-V
        "explore_bpm": 70, "battle_bpm": 128, "boss_bpm": 150,
    },
    "frost_wastes": {
        "root": 64, "scale": [0, 2, 3, 5, 7, 8, 10],  # E 小调
        "progression": [[0, 7, 12, 15], [-3, 4, 9, 12], [-5, 2, 7, 10], [2, 9, 14, 17]],  # i-bVII-bVI-III
        "explore_bpm": 60, "battle_bpm": 120, "boss_bpm": 145,
    },
    "sand_ruins": {
        "root": 57, "scale": [0, 2, 3, 5, 7, 8, 11],  # A 小调和声（升 7 级）
        "progression": [[0, 7, 12, 16], [-5, 2, 7, 12], [-3, 4, 7, 12], [-1, 2, 7, 11]],  # i-iv-bVI-V7
        "explore_bpm": 75, "battle_bpm": 132, "boss_bpm": 155,
    },
    "dark_forest": {
        "root": 66, "scale": [0, 2, 3, 5, 7, 8, 10],  # F# 小调
        "progression": [[0, 7, 12, 15], [-2, 5, 9, 12], [-5, 2, 7, 10], [-3, 4, 7, 12]],  # i-bVII-iv-bVI
        "explore_bpm": 65, "battle_bpm": 124, "boss_bpm": 148,
    },
}


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


# 保留旧接口的默认主题（灰烬王城）
D_MINOR = [62, 64, 65, 67, 69, 70, 72]
PROGRESSION = [[50, 57, 62, 65], [46, 53, 58, 62], [43, 50, 55, 58], [45, 52, 57, 61]]


def explore(rng, theme=None):
    if theme is None:
        theme = THEMES["ashen_city"]
    bpm, bars = theme["explore_bpm"], 16
    beat = 60.0 / bpm
    tr = Track(bars * 4 * beat)
    progression = [[theme["root"] + n for n in ch] for ch in theme["progression"]]
    scale = [theme["root"] + n for n in theme["scale"]]
    for bar in range(bars):
        chord = progression[bar % 4]
        t0 = bar * 4 * beat
        for note in chord:
            tr.add(t0, 4 * beat, pad(note), 0.05)
        for step in range(8):
            if rng.random() < 0.45:
                tr.add(t0 + step * beat / 2, beat * 1.5, pluck(rng.choice(scale) + 12), 0.18)
    return tr


def battle(rng, theme=None):
    if theme is None:
        theme = THEMES["ashen_city"]
    bpm, bars = theme["battle_bpm"], 16
    beat = 60.0 / bpm
    tr = Track(bars * 4 * beat)
    progression = [[theme["root"] + n for n in ch] for ch in theme["progression"]]
    scale = [theme["root"] + n for n in theme["scale"]]
    snare, hat = make_snare(rng), make_hat(rng)
    for bar in range(bars):
        chord = progression[bar % 4]
        t0 = bar * 4 * beat
        for note in chord[1:]:
            tr.add(t0, 4 * beat, pad(note), 0.035)
        for step in range(8):
            note = chord[0] - 12 + (12 if step % 4 == 3 else 0)
            tr.add(t0 + step * beat / 2, beat / 2, bass(note), 0.35)
        for b in range(4):
            tr.add(t0 + b * beat, 0.4, kick, 0.6 if b % 2 == 0 else 0.4)
            if b % 2 == 1:
                tr.add(t0 + b * beat, 0.25, snare, 0.35)
            tr.add(t0 + b * beat + beat / 2, 0.06, hat, 0.12)
        if bar % 2 == 1:
            for i, off in enumerate((0, 2, 4, 3)):
                tr.add(t0 + (2 + i * 0.5) * beat, beat, pluck(scale[off] + 12), 0.2)
    return tr


def boss(rng, theme=None):
    if theme is None:
        theme = THEMES["ashen_city"]
    bpm, bars = theme["boss_bpm"], 16
    beat = 60.0 / bpm
    tr = Track(bars * 4 * beat)
    progression = [[theme["root"] + n for n in ch] for ch in theme["progression"]]
    scale = [theme["root"] + n for n in theme["scale"]]
    snare, hat = make_snare(rng), make_hat(rng)
    motif = [0, 0, 5, 4, 3, 1, 2, 0]
    for bar in range(bars):
        chord = progression[bar % 4]
        t0 = bar * 4 * beat
        for step in range(16):
            tr.add(t0 + step * beat / 4, beat / 4, bass(chord[0] - 12), 0.3)
        for b in range(4):
            tr.add(t0 + b * beat, 0.4, kick, 0.65)
            tr.add(t0 + b * beat + beat / 2, 0.4, kick, 0.35)
            if b % 2 == 1:
                tr.add(t0 + b * beat, 0.25, snare, 0.45)
            for h in range(2):
                tr.add(t0 + b * beat + h * beat / 2 + beat / 4, 0.06, hat, 0.1)
        if bar >= 4:
            shift = 1 if bar % 4 == 3 else 0
            for i, deg in enumerate(motif):
                note = scale[(deg + shift) % len(scale)] + (12 if bar >= 12 else 0)
                tr.add(t0 + i * beat / 2, beat / 2 * 0.9, lead(note), 0.09)
    return tr


def main():
    os.makedirs(OUT, exist_ok=True)
    for map_id, theme in THEMES.items():
        for name, fn in (("explore", explore), ("battle", battle), ("boss", boss)):
            track = fn(random.Random(hash(map_id + name) & 0xFFFF), theme)
            path = os.path.join(OUT, "%s_%s.wav" % (map_id, name))
            track.save(path)
            print("[music] %s_%s: %.1f s, %d KB" % (map_id, name, track.n / RATE, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
