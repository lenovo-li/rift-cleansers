"""作曲 + 渲染背景音乐：4 张地图 × 3 首（explore / battle / boss）。
流程：脚本写 MIDI（tools/audio/midi/<名字>.mid，可用 MuseScore 打开看谱）→ FluidSynth + GeneralUser GS 音色库渲染
→ 首尾无缝处理（把混响尾巴叠回开头）→ 响度统一 → assets/audio/music/<名字>.ogg。
用法（项目根目录）：python tools/audio/compose_music.py [名字 ...]    例：ashen_city_battle
依赖：pip install numpy soundfile；FluidSynth 和音色库路径见 FLUIDSYNTH / SOUNDFONT（可用环境变量覆盖）。
"""
import os
import random
import subprocess
import tempfile
import zlib
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from midi import Song  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MIDI_DIR = os.path.join(ROOT, "tools", "audio", "midi")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "music")
FLUIDSYNTH = os.environ.get("FLUIDSYNTH", r"D:\tools\fluidsynth\fluidsynth-v2.6.1-win10-x64-cpp11\bin\fluidsynth.exe")
SOUNDFONT = os.environ.get("SOUNDFONT", r"D:\tools\soundfonts\GeneralUser-GS.sf2")
RATE = 44100

# GM 音色编号（0 起）
GM = {
    "celesta": 8, "glock": 9, "music_box": 10, "church_organ": 19, "nylon": 24, "acoustic_bass": 32,
    "strings_trem": 44, "pizz": 45, "harp": 46, "timpani": 47, "strings": 48, "strings_slow": 49,
    "choir": 52, "voice_oohs": 53, "trumpet": 56, "trombone": 57, "tuba": 58, "horn": 60, "brass": 61,
    "oboe": 68, "bassoon": 70, "clarinet": 71, "flute": 73, "pan_flute": 75, "shakuhachi": 77,
    "pad_warm": 89, "pad_halo": 94, "sitar": 104, "koto": 107, "contrabass": 43, "cello": 42,
}
# GM 打击乐音高
KICK, SNARE, RIM, TOM_L, TOM_M, TOM_H, HAT, HAT_O, CRASH, RIDE = 36, 38, 37, 41, 45, 48, 42, 46, 49, 51
TAMB, BONGO_H, BONGO_L, CONGA_H, CONGA_L, SHAKER = 54, 60, 61, 62, 64, 70

# 地图主题：根音（MIDI 音高，旋律八度）、音阶、和弦进行（音阶级数，每小节一个）、配器、速度
THEMES = {
    "ashen_city": {  # D 小调，暗黑王城：弦乐、圆号、合唱、管风琴
        "root": 62, "scale": [0, 2, 3, 5, 7, 8, 10],
        "prog": [0, 5, 3, 4], "prog_b": [5, 6, 2, 4],
        "explore": {"bpm": 72, "lead": "horn", "pad": "strings_slow", "arp": "harp", "bass": "contrabass", "pad2": "choir"},
        "battle": {"bpm": 132, "lead": "brass", "pad": "strings", "arp": "strings", "bass": "contrabass", "pad2": "trombone"},
        "boss": {"bpm": 150, "lead": "brass", "pad": "church_organ", "arp": "strings", "bass": "tuba", "pad2": "choir"},
    },
    "frost_wastes": {  # E 小调，空灵冰原：钢片琴、长笛、温暖铺底
        "root": 64, "scale": [0, 2, 3, 5, 7, 8, 10],
        "prog": [0, 6, 5, 2], "prog_b": [3, 0, 6, 4],
        "explore": {"bpm": 64, "lead": "flute", "pad": "pad_halo", "arp": "celesta", "bass": "cello", "pad2": "voice_oohs"},
        "battle": {"bpm": 124, "lead": "horn", "pad": "strings", "arp": "glock", "bass": "contrabass", "pad2": "strings_slow"},
        "boss": {"bpm": 146, "lead": "brass", "pad": "strings_slow", "arp": "strings", "bass": "contrabass", "pad2": "choir"},
    },
    "sand_ruins": {  # A 和声小调，神秘沙海：双簧管、西塔琴、手鼓
        "root": 57, "scale": [0, 1, 4, 5, 7, 8, 10],  # 弗里几亚属音阶（中东色彩）
        "prog": [0, 1, 0, 6], "prog_b": [5, 6, 1, 0],
        "explore": {"bpm": 76, "lead": "oboe", "pad": "pad_warm", "arp": "sitar", "bass": "cello", "pad2": "strings_slow"},
        "battle": {"bpm": 128, "lead": "oboe", "pad": "strings", "arp": "sitar", "bass": "contrabass", "pad2": "brass"},
        "boss": {"bpm": 148, "lead": "brass", "pad": "strings", "arp": "koto", "bass": "tuba", "pad2": "choir"},
    },
    "dark_forest": {  # F# 小调，诡异森林：八音盒、巴松、人声哼唱、拨弦
        "root": 66, "scale": [0, 2, 3, 5, 7, 8, 11],
        "prog": [0, 5, 1, 4], "prog_b": [3, 5, 6, 4],
        "explore": {"bpm": 66, "lead": "music_box", "pad": "voice_oohs", "arp": "pizz", "bass": "bassoon", "pad2": "strings_trem"},
        "battle": {"bpm": 126, "lead": "clarinet", "pad": "strings", "arp": "pizz", "bass": "contrabass", "pad2": "horn"},
        "boss": {"bpm": 144, "lead": "brass", "pad": "church_organ", "arp": "strings", "bass": "tuba", "pad2": "choir"},
    },
}
BARS = {"explore": 16, "battle": 32, "boss": 32}


def degree_pitch(theme, degree, octave=0):
    """音阶级数 → 音高（级数可为负或超过 7，自动换八度）。"""
    sc = theme["scale"]
    o, d = divmod(degree, len(sc))
    return theme["root"] + sc[d] + 12 * (o + octave)


def chord(theme, degree, octave=0, size=3):
    """以 degree 为根的三和弦 / 七和弦（音阶内叠三度）。"""
    return [degree_pitch(theme, degree + 2 * i, octave) for i in range(size)]


# ---------------------------------------------------------------- 旋律

RHYTHMS = {  # 两小节动机的节奏型：(拍内起点, 时长)
    "explore": [[(0, 2), (2, 1), (3, 1), (4, 3), (7, 1)], [(0, 1.5), (1.5, 0.5), (2, 2), (4, 2), (6, 2)],
                [(0, 3), (3, 1), (4, 1), (5, 1), (6, 2)]],
    "battle": [[(0, 1), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1), (4, 1.5), (5.5, 0.5), (6, 2)],
               [(0, 0.5), (0.5, 0.5), (1, 1), (2, 0.5), (2.5, 0.5), (3, 1), (4, 2), (6, 1), (7, 1)],
               [(0, 1.5), (1.5, 0.5), (2, 1.5), (3.5, 0.5), (4, 3), (7, 1)]],
}
RHYTHMS["boss"] = RHYTHMS["battle"] + [[(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1), (4, 0.5),
                                        (4.5, 0.5), (5, 1), (6, 2)]]
CHORD_TONES = (0, 2, 4, 7, -3)


def make_motif(rng, mood):
    """两小节动机：[(起拍, 时长, 相对和弦根的音阶级数)]。强拍落和弦音，弱拍级进。"""
    deg = rng.choice((0, 2, 4))
    notes = []
    for off, dur in rng.choice(RHYTHMS[mood]):
        if off % 2 == 0:
            deg = min(CHORD_TONES, key=lambda c: abs(c - deg) + rng.random() * 0.8)
        else:
            deg += rng.choice((-2, -1, -1, 1, 1, 2))
        deg = max(-3, min(9, deg))
        notes.append((off, dur, deg))
    return notes


def vary(rng, motif, shift=0, cadence=False):
    """动机变奏：整体移级；cadence=True 时最后一个音落主音并拉长到小节末。"""
    out = [(o, d, g + shift) for o, d, g in motif]
    if cadence:
        o, _, _ = out[-1]
        out[-1] = (o, 8 - o, 0)
    elif rng.random() < 0.5:  # 末音换个和弦音，避免机械重复
        o, d, g = out[-1]
        out[-1] = (o, d, rng.choice((2, 4, -3)))
    return out


def chords_for(theme, bars, b_sections):
    """每小节的和弦根级数；b_sections 里的 8 小节段用副进行。"""
    out = []
    for bar in range(bars):
        prog = theme["prog_b"] if bar // 8 in b_sections else theme["prog"]
        out.append(prog[bar % len(prog)])
    return out


def place_melody(track, theme, phrase, bar0, chords, octave, vel, rng):
    """把一段（若干个两小节动机）旋律按每小节和弦落到音轨上。"""
    for i, motif in enumerate(phrase):
        for off, dur, deg in motif:
            bar = bar0 + i * 2 + int(off // 4)
            pitch = degree_pitch(theme, chords[bar] + deg, octave)
            accent = 8 if off % 4 == 0 else 0
            track.note((bar0 + i * 2) * 4 + off, dur * 0.95, pitch, vel + accent + rng.randint(-5, 5))


def phrase_8(rng, mood):
    """8 小节乐句：A  A'(上移)  B  A(终止)。"""
    a = make_motif(rng, mood)
    b = make_motif(rng, mood)
    return [a, vary(rng, a, shift=2), b, vary(rng, a, cadence=True)]


# ---------------------------------------------------------------- 编配

def pads(song, theme, cfg, chords, mood, rng):
    """和声铺底：探索曲长音，战斗曲每小节重新起音（带力度起伏）。"""
    pad = song.track("Pad", 0, GM[cfg["pad"]], volume=88 if mood == "explore" else 80, reverb=90)
    for bar, c in enumerate(chords):
        voicing = chord(theme, c, -1, 4 if mood == "explore" else 3)
        pad.chord(bar * 4, 4, voicing, 58 + (bar % 4 == 0) * 8 + rng.randint(-4, 4))
    pad2 = song.track("Pad2", 4, GM[cfg["pad2"]], volume=70 if mood == "explore" else 84, reverb=100)
    start = 8 if mood == "explore" else 0
    for bar in range(start, len(chords)):
        c = chords[bar]
        if mood == "explore":
            if bar % 2 == 0:
                pad2.chord(bar * 4, 8, [degree_pitch(theme, c, -1), degree_pitch(theme, c + 4, -1)], 50)
        elif mood == "battle":
            for beat in (0, 2.5):  # 铜管 / 弦乐切分强奏
                pad2.chord(bar * 4 + beat, 0.9, chord(theme, c, -1), 92 if beat == 0 else 78)
        else:
            pad2.chord(bar * 4, 4, chord(theme, c, -1) + [degree_pitch(theme, c, 0)], 86)


def bass(song, theme, cfg, chords, mood):
    tr = song.track("Bass", 1, GM[cfg["bass"]], volume=100, reverb=40)
    for bar, c in enumerate(chords):
        root = degree_pitch(theme, c, -3 if theme["root"] > 63 else -2)
        if mood == "explore":
            tr.note(bar * 4, 4, root, 70)
        elif mood == "battle":
            for k in range(8):  # 八分音符推进，第 7 个八分跳五度
                tr.note(bar * 4 + k * 0.5, 0.45, root + (7 if k == 6 else 0), 96 if k % 2 == 0 else 80)
        else:
            for k in range(16):  # 十六分音符的低音脉动
                tr.note(bar * 4 + k * 0.25, 0.22, root + (12 if k in (6, 14) else 0), 100 if k % 4 == 0 else 78)


def arpeggio(song, theme, cfg, chords, mood, rng):
    """分解和弦 / 弦乐固定音型。"""
    tr = song.track("Arp", 3, GM[cfg["arp"]], volume=78 if mood == "explore" else 86, reverb=70)
    step = {"explore": 0.5, "battle": 0.25, "boss": 0.25}[mood]
    pattern = [0, 1, 2, 3, 2, 1] if mood == "explore" else [0, 2, 1, 3, 0, 2, 1, 2]
    for bar, c in enumerate(chords):
        if mood == "explore" and bar < 2:
            continue  # 开头两小节只留铺底，入口更柔
        notes = chord(theme, c, 0 if mood == "explore" else -1, 3) + [degree_pitch(theme, c, 1)]
        for k in range(int(4 / step)):
            p = notes[pattern[k % len(pattern)]]
            vel = 64 if mood == "explore" else (84 if k % 4 == 0 else 66)
            tr.note(bar * 4 + k * step, step * (1.6 if mood == "explore" else 0.8), p, vel + rng.randint(-4, 4))


def melody(song, theme, cfg, chords, mood, rng):
    lead = song.track("Lead", 2, GM[cfg["lead"]], volume=104, reverb=80)
    bars = len(chords)
    octave = 0 if mood == "explore" else (0 if theme["root"] < 63 else -1)
    sections = range(0, bars, 8)
    themes = {0: phrase_8(rng, mood), 1: phrase_8(rng, mood)}
    for s, bar0 in enumerate(sections):
        if mood == "explore" and bar0 == 0:
            continue  # 探索曲先铺 8 小节氛围，第二段才进旋律
        key = 1 if (bar0 // 8) % 4 == 2 else 0
        place_melody(lead, theme, themes[key], bar0, chords, octave + (1 if s == 3 else 0), 84, rng)


def drums(song, theme, mood, bars, map_id, rng):
    """打击乐：战斗 / Boss 用鼓组 + 定音鼓；探索曲只有心跳式的低鼓（沙海用手鼓）。"""
    dr = song.track("Drums", 9, 0, volume=100 if mood != "explore" else 80, reverb=50)
    timp = song.track("Timpani", 5, GM["timpani"], volume=96, reverb=70)
    hand = map_id == "sand_ruins"
    for bar in range(bars):
        t = bar * 4
        fill = bar % 8 == 7
        root = degree_pitch(theme, song_chords[bar], -3 if theme["root"] > 63 else -2) + 12
        if mood == "explore":
            if bar >= 2 and bar % 2 == 0:
                timp.note(t, 2, root, 62)
            if hand:
                for k, (b, p) in enumerate(((0, CONGA_L), (1.5, BONGO_H), (2, CONGA_H), (3, BONGO_L), (3.5, BONGO_H))):
                    dr.note(t + b, 0.4, p, 54 + rng.randint(-6, 6))
            elif bar >= 4:
                dr.note(t, 0.5, KICK, 50)
                dr.note(t + 0.75, 0.5, KICK, 36)
            continue
        if bar % 8 == 0:
            dr.note(t, 2, CRASH, 100)
        kicks = (0, 1.5, 2, 3.5) if mood == "battle" else (0, 0.75, 1.5, 2, 2.75, 3.5)
        for b in kicks:
            dr.note(t + b, 0.4, KICK, 104 if b in (0, 2) else 86)
        for b in (1, 3):
            dr.note(t + b, 0.4, SNARE, 98)
        sub = 0.5 if mood == "battle" else 0.25
        for k in range(int(4 / sub)):
            dr.note(t + k * sub, sub * 0.9, TAMB if hand else (HAT_O if k % 4 == 2 and mood == "boss" else HAT),
                    62 if k % 2 else 76)
        if fill:  # 每 8 小节最后一拍半的滚奏
            for k, p in enumerate((TOM_H, TOM_H, TOM_M, TOM_M, TOM_L, TOM_L)):
                dr.note(t + 2.5 + k * 0.25, 0.25, p, 84 + k * 4)
        timp.note(t, 1, root, 100)
        timp.note(t + 2, 1, root + 7 - 12, 84)
        if mood == "boss" and bar % 2 == 1:
            for k in range(4):
                timp.note(t + 3 + k * 0.25, 0.25, root, 70 + k * 8)


song_chords = []


def compose(map_id, mood, seed):
    global song_chords
    theme = THEMES[map_id]
    cfg = theme[mood]
    rng = random.Random(seed)
    bars = BARS[mood]
    song_chords = chords_for(theme, bars, b_sections=(2,) if mood != "explore" else (1,))
    song = Song(cfg["bpm"])
    pads(song, theme, cfg, song_chords, mood, rng)
    bass(song, theme, cfg, song_chords, mood)
    arpeggio(song, theme, cfg, song_chords, mood, rng)
    melody(song, theme, cfg, song_chords, mood, rng)
    drums(song, theme, mood, bars, map_id, rng)
    return song, bars * 4 * 60.0 / cfg["bpm"]


# ---------------------------------------------------------------- 渲染

TAIL_BEATS = 8.0
TARGET_RMS = 0.16
PEAK_CAP = 0.95


def render(map_id, mood):
    """作曲 → 保存 .mid → FluidSynth 渲染两遍 → 取第二遍（开头自带上一遍的混响尾巴，循环无缝）→ 响度统一 → .ogg。"""
    import numpy as np
    import soundfile as sf
    name = "%s_%s" % (map_id, mood)
    song, loop_sec = compose(map_id, mood, zlib.crc32(name.encode()))
    os.makedirs(MIDI_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    song.save(os.path.join(MIDI_DIR, name + ".mid"))
    loop_beats = BARS[mood] * 4
    with tempfile.TemporaryDirectory() as tmp:
        mid = os.path.join(tmp, "x.mid")
        wav = os.path.join(tmp, "x.wav")
        song.save(mid, repeat=2, loop_beats=loop_beats, tail_beats=TAIL_BEATS)
        subprocess.run([FLUIDSYNTH, "-ni", "-q", "-g", "0.6", "-r", str(RATE), "-F", wav,
                        "-o", "synth.reverb.active=1", "-o", "synth.chorus.active=1", SOUNDFONT, mid],
                       check=True, stdout=subprocess.DEVNULL)
        audio, sr = sf.read(wav, dtype="float32", always_2d=True)
    n = int(round(loop_sec * sr))
    if len(audio) < 2 * n:
        audio = np.pad(audio, ((0, 2 * n - len(audio)), (0, 0)))
    loop = audio[n:2 * n].copy()
    # FluidSynth 按块调度事件，第二遍可能错开几个采样；尾部 50ms 渐变到"开头之前"的真实音频，回绕处完全连续
    k = int(0.05 * sr)
    w = np.linspace(0.0, 1.0, k, dtype=np.float32)[:, None]
    loop[-k:] = loop[-k:] * (1.0 - w) + audio[n - k:n] * w
    rms = float(np.sqrt(np.mean(loop ** 2))) or 1.0
    gain = TARGET_RMS / rms
    peak = float(np.max(np.abs(loop))) * gain
    if peak > PEAK_CAP:
        gain *= PEAK_CAP / peak
    loop = loop * gain
    out = os.path.join(OUT_DIR, name + ".ogg")
    with sf.SoundFile(out, "w", sr, loop.shape[1], format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(loop), 8192):  # libsndfile 一次写整段 Vorbis 会崩，分块写
            f.write(np.ascontiguousarray(loop[i:i + 8192]))
    print("%-24s %5.1fs  gain %.2f  -> %s" % (name, loop_sec, gain, os.path.relpath(out, ROOT)))


def main(names):
    all_names = ["%s_%s" % (m, s) for m in THEMES for s in ("explore", "battle", "boss")]
    for name in names or all_names:
        if name not in all_names:
            sys.exit("未知曲目：%s（可选：%s）" % (name, " ".join(all_names)))
        map_id, mood = name.rsplit("_", 1)
        render(map_id, mood)


if __name__ == "__main__":
    main(sys.argv[1:])
