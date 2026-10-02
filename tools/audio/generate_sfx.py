"""游戏音效生成器 v3：优化频谱分布，确保能量在可听范围（200Hz-8kHz）。
v2 的问题：大量能量在 0-150Hz 超低频，笔记本扬声器无法播放。
v3 改进：
  - 撞击音用 250-800Hz 的咚声 + 高频咔嗒（不再用 60-80Hz）
  - 加入录音风格的噪声纹理（带通滤波白噪声）
  - 爆炸用 200Hz 低音 + 中频轰鸣 + 高频碎裂
  - 所有音效确保 80% 以上能量在 150Hz 以上
用法：python tools/audio/generate_sfx_v3.py [类别 ...]
"""
import os, sys, random, subprocess, tempfile, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from midi import Song

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "sfx", "generated")
FLUIDSYNTH = os.environ.get("FLUIDSYNTH", r"D:\tools\fluidsynth\fluidsynth-v2.6.1-win10-x64-cpp11\bin\fluidsynth.exe")
SOUNDFONT = os.environ.get("SOUNDFONT", r"D:\tools\soundfonts\GeneralUser-GS.sf2")
RATE = 44100

GM = {
    "celesta": 8, "glock": 9, "vibraphone": 11, "marimba": 12, "xylophone": 13,
    "harp": 46, "timpani": 47, "taiko": 116, "synth_drum": 118,
}

import numpy as np
import soundfile as sf

# ============================================================ DSP 工具

def time_array(duration):
    return np.arange(int(duration * RATE), dtype=np.float32) / RATE

def white_noise(duration, seed):
    rng = np.random.RandomState(seed)
    return rng.uniform(-1, 1, int(duration * RATE)).astype(np.float32)

def envelope(samples, attack=0.01, decay=0.05, sustain_level=0.7, release=0.1):
    n = len(samples)
    a_n = int(attack * RATE)
    d_n = int(decay * RATE)
    r_n = int(release * RATE)
    s_n = max(0, n - a_n - d_n - r_n)
    env = np.ones(n, dtype=np.float32)
    if a_n > 0:
        env[:a_n] = np.linspace(0, 1, a_n)
    if d_n > 0:
        env[a_n:a_n+d_n] = np.linspace(1, sustain_level, d_n)
    if s_n > 0:
        env[a_n+d_n:a_n+d_n+s_n] = sustain_level
    if r_n > 0:
        env[-r_n:] = np.linspace(sustain_level, 0, r_n)
    return samples * env

def fade_in_out(samples, fade_ms=5):
    n_fade = int(fade_ms * RATE / 1000)
    if n_fade >= len(samples) // 2:
        return samples
    fade = np.linspace(0, 1, n_fade, dtype=np.float32)
    samples[:n_fade] *= fade
    samples[-n_fade:] *= fade[::-1]
    return samples

def bandpass_filter(signal, low_freq, high_freq):
    fft = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1.0 / RATE)
    mask = np.zeros_like(freqs, dtype=np.float32)
    for i, f in enumerate(freqs):
        if low_freq <= f <= high_freq:
            mask[i] = 1.0
        elif f < low_freq:
            mask[i] = 1.0 / (1.0 + ((low_freq - f) / (low_freq * 0.15)) ** 4)
        else:
            mask[i] = 1.0 / (1.0 + ((f - high_freq) / (high_freq * 0.15)) ** 4)
    fft = fft * mask
    return np.fft.irfft(fft, len(signal)).astype(np.float32)

def sine_wave(freq, duration):
    t = time_array(duration)
    return np.sin(2 * np.pi * freq * t).astype(np.float32)

def frequency_sweep(f_start, f_end, duration):
    t = time_array(duration)
    ratio = f_end / f_start
    freq = f_start * (ratio ** (t / duration))
    phase = 2 * np.pi * f_start * duration / np.log(ratio) * ((ratio ** (t / duration)) - 1)
    return np.sin(phase).astype(np.float32)

def normalize_rms(signal, target_rms=0.15):
    rms = np.sqrt(np.mean(signal ** 2))
    if rms < 1e-6:
        return signal
    gain = target_rms / rms
    peak = np.max(np.abs(signal * gain))
    if peak > 0.95:
        gain *= 0.95 / peak
    return signal * gain

def mix_layers(*layers):
    max_len = max(len(layer) for layer in layers)
    mixed = np.zeros(max_len, dtype=np.float32)
    for layer in layers:
        mixed[:len(layer)] += layer
    return mixed

def render_midi_layer(notes, duration):
    """notes: [(time_sec, duration_sec, program, pitch, velocity), ...]"""
    song = Song(bpm=60)
    by_prog = {}
    for t, dur, prog, pitch, vel in notes:
        if prog not in by_prog:
            by_prog[prog] = []
        by_prog[prog].append((t, dur, pitch, vel))
    for i, (prog, note_list) in enumerate(by_prog.items()):
        track = song.track(f"T{i}", i, prog, volume=100, reverb=50)
        for t, dur, pitch, vel in note_list:
            track.note(t, dur, pitch, vel)
    with tempfile.TemporaryDirectory() as tmp:
        mid = os.path.join(tmp, "x.mid")
        wav = os.path.join(tmp, "x.wav")
        song.save(mid)
        subprocess.run([FLUIDSYNTH, "-ni", "-q", "-g", "0.5", "-r", str(RATE), "-F", wav,
                        "-o", "synth.reverb.active=1", SOUNDFONT, mid],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        audio, sr = sf.read(wav, dtype="float32", always_2d=True)
    n = int(duration * sr)
    if len(audio) > n:
        audio = audio[:n]
    elif len(audio) < n:
        audio = np.pad(audio, ((0, n - len(audio)), (0, 0)))
    return audio.mean(axis=1).astype(np.float32)

# ============================================================ 音效合成

def enemy_hit(seed, variant):
    """敌人受击：中频咚声（250-600Hz）+ 咔嗒（2kHz）。"""
    dur = 0.12
    # 咚声：下降扫频
    thud = frequency_sweep(500 + variant * 30, 250, dur * 0.6) * 0.6
    thud = envelope(thud[:int(dur * 0.6 * RATE)], 0.003, 0.03, 0, 0.04)
    # 咔嗒：短噪声
    click = white_noise(0.015, seed + variant)
    click = bandpass_filter(click, 1800, 3500) * 0.3
    click = envelope(click, 0.001, 0.008, 0, 0.006)
    # 混合
    result = np.zeros(int(dur * RATE), dtype=np.float32)
    result[:len(click)] += click
    result[:len(thud)] += thud
    return normalize_rms(fade_in_out(result), 0.13)

def enemy_death(seed, variant):
    """敌人死亡：闷响（200-400Hz）+ 气声。"""
    dur = 0.35
    # 闷响
    thump = frequency_sweep(350 + variant * 20, 180, dur) * 0.5
    thump = envelope(thump, 0.008, 0.08, 0.2, 0.15)
    # 气声
    breath = white_noise(dur, seed + variant) * 0.25
    breath = bandpass_filter(breath, 300, 1200)
    breath = envelope(breath, 0.02, 0.1, 0.3, 0.12)
    return normalize_rms(fade_in_out(thump + breath), 0.11)

def elite_death(seed, variant):
    """精英死亡：爆炸（200Hz 低音 + 轰鸣 + 碎裂）。"""
    dur = 0.7
    # 低频冲击（提升到 200Hz，避免超低频）
    boom = sine_wave(200 + variant * 10, dur) * 0.6
    boom += sine_wave(300, dur) * 0.3
    boom = envelope(boom, 0.005, 0.15, 0.35, 0.25)
    # 中频轰鸣
    rumble = white_noise(dur, seed + variant) * 0.4
    rumble = bandpass_filter(rumble, 250, 1500)
    rumble = envelope(rumble, 0.01, 0.18, 0.3, 0.22)
    # 高频碎裂
    crackle = white_noise(dur, seed + variant + 100) * 0.25
    crackle = bandpass_filter(crackle, 2000, 6000)
    crackle = envelope(crackle, 0.002, 0.12, 0.2, 0.18)
    return normalize_rms(fade_in_out(boom + rumble + crackle), 0.17)

def player_hurt(seed, variant):
    """玩家受伤：闷击（300Hz）+ 中频噪声。"""
    dur = 0.22
    hit = sine_wave(300 + variant * 15, dur) * 0.55
    hit = envelope(hit, 0.005, 0.06, 0.2, 0.12)
    noise = white_noise(dur, seed + variant) * 0.3
    noise = bandpass_filter(noise, 400, 1800)
    noise = envelope(noise, 0.008, 0.07, 0.15, 0.1)
    return normalize_rms(fade_in_out(hit + noise), 0.13)

def shield_block(seed, variant):
    """盾牌格挡：金属撞击（600-1200Hz）+ 共鸣。"""
    dur = 0.28
    # 金属音：调制正弦
    t = time_array(dur)
    metal = sine_wave(800 + variant * 50, dur) * (1 + 0.5 * np.sin(2 * np.pi * 17 * t))
    metal += sine_wave(1200, dur) * 0.4
    metal = envelope(metal, 0.003, 0.06, 0.25, 0.14) * 0.5
    # 共鸣
    ring = sine_wave(650, dur) * 0.3
    ring = envelope(ring, 0.005, 0.08, 0.2, 0.15)
    return normalize_rms(fade_in_out(metal + ring), 0.14)

def auto_pulse(seed, variant):
    """铁卫普攻：盾纹冲击波（300-700Hz）+ 敲击声。"""
    dur = 0.25
    # 冲击波：下降扫频
    pulse = frequency_sweep(650 + variant * 30, 300, dur) * 0.55
    pulse = envelope(pulse, 0.008, 0.06, 0.35, 0.12)
    # 敲击：鼓声感
    notes = [(0, 0.15, GM["taiko"], 48 + variant, 95)]
    drum = render_midi_layer(notes, dur) * 0.5
    return normalize_rms(fade_in_out(pulse + drum), 0.12)

def auto_slash(seed, variant):
    """影行者普攻：快速挥舞（500-2500Hz 噪声扫描）。"""
    dur = 0.20
    whoosh = white_noise(dur, seed + variant) * 0.5
    whoosh = bandpass_filter(whoosh, 600 + variant * 50, 2500)
    whoosh = envelope(whoosh, 0.015, 0.06, 0.4, 0.09)
    # 金属闪
    shimmer = sine_wave(1800 + variant * 100, dur) * 0.2
    shimmer = envelope(shimmer, 0.01, 0.05, 0.3, 0.08)
    return normalize_rms(fade_in_out(whoosh + shimmer), 0.11)

def auto_crystal(seed, variant):
    """术士普攻：水晶音（800-2200Hz 下扫）。"""
    dur = 0.26
    zap = frequency_sweep(2000 + variant * 100, 800, dur) * 0.5
    zap = envelope(zap, 0.01, 0.07, 0.3, 0.11)
    sparkle = sine_wave(2800, dur) * 0.18
    sparkle = envelope(sparkle, 0.012, 0.06, 0.25, 0.1)
    return normalize_rms(fade_in_out(zap + sparkle), 0.11)

def auto_holy(seed, variant):
    """牧师普攻：圣光钟声。"""
    pentatonic = [0, 2, 4, 7, 9]
    pitch = 72 + pentatonic[variant % 5]
    notes = [(0, 0.35, GM["vibraphone"], pitch, 72)]
    audio = render_midi_layer(notes, 0.45)
    return normalize_rms(fade_in_out(audio), 0.10)

def fire_cast(seed, variant):
    """火焰施法：低吼（200-600Hz）+ 火焰纹理。"""
    dur = 0.38
    roar = sine_wave(280 + variant * 15, dur) * 0.45
    roar += sine_wave(420, dur) * 0.25
    roar = envelope(roar, 0.02, 0.1, 0.5, 0.13)
    flame = white_noise(dur, seed + variant) * 0.3
    flame = bandpass_filter(flame, 300, 1400)
    flame = envelope(flame, 0.025, 0.11, 0.45, 0.14)
    return normalize_rms(fade_in_out(roar + flame), 0.13)

def fire_impact(seed, variant):
    """火焰爆炸：轰鸣（220Hz）+ 噪声爆发 + 鼓。"""
    dur = 0.60
    boom = sine_wave(220 + variant * 8, dur) * 0.55
    boom += sine_wave(330, dur) * 0.3
    boom = envelope(boom, 0.006, 0.16, 0.32, 0.26)
    noise = white_noise(dur, seed + variant) * 0.45
    noise = bandpass_filter(noise, 300, 1600)
    noise = envelope(noise, 0.008, 0.17, 0.28, 0.24)
    notes = [(0, 0.18, GM["timpani"], 36 + variant, 115)]
    drum = render_midi_layer(notes, dur) * 0.6
    return normalize_rms(fade_in_out(mix_layers(boom, noise, drum)), 0.16)

def ice_cast(seed, variant):
    """冰霜施法：钟琴（2000-3500Hz）。"""
    dur = 0.32
    shimmer = sine_wave(2400 + variant * 150, dur) * 0.4
    shimmer += sine_wave(3200, dur) * 0.22
    shimmer = envelope(shimmer, 0.012, 0.08, 0.45, 0.11)
    notes = [(0, 0.28, GM["glock"], 84 + variant, 78)]
    bells = render_midi_layer(notes, dur) * 0.5
    return normalize_rms(fade_in_out(shimmer + bells), 0.12)

def ice_shatter(seed, variant):
    """冰霜碎裂：多层玻璃音（1800-5000Hz）。"""
    dur = 0.48
    shatter = np.zeros(int(dur * RATE), dtype=np.float32)
    rng = random.Random(seed + variant)
    for _ in range(10):
        freq = rng.uniform(2200, 4800)
        delay = rng.uniform(0, 0.12)
        start = int(delay * RATE)
        chunk = sine_wave(freq, 0.16) * 0.2
        chunk = envelope(chunk, 0.001, 0.05, 0, 0.1)
        end = min(start + len(chunk), len(shatter))
        shatter[start:end] += chunk[:end-start]
    noise = white_noise(dur, seed + variant) * 0.22
    noise = bandpass_filter(noise, 2500, 6500)
    noise = envelope(noise, 0.002, 0.09, 0.18, 0.18)
    return normalize_rms(fade_in_out(shatter + noise), 0.14)

def lightning_cast(seed, variant):
    """闪电施法：电流噼啪（3500-9000Hz）+ 中频嗡鸣。"""
    dur = 0.24
    crackle = white_noise(dur, seed + variant) * 0.55
    crackle = bandpass_filter(crackle, 3800, 9500)
    crackle = envelope(crackle, 0.001, 0.05, 0.32, 0.11)
    buzz = sine_wave(1100 + variant * 80, dur) * 0.35
    buzz = envelope(buzz, 0.003, 0.06, 0.28, 0.12)
    return normalize_rms(fade_in_out(crackle + buzz), 0.14)

def lightning_hit(seed, variant):
    """闪电命中：电击爆裂（2500-8000Hz）。"""
    dur = 0.28
    snap = white_noise(dur, seed + variant) * 0.48
    snap = bandpass_filter(snap, 2800, 8500)
    snap = envelope(snap, 0.002, 0.07, 0.22, 0.12)
    zap = frequency_sweep(1600 + variant * 70, 900, dur) * 0.32
    zap = envelope(zap, 0.003, 0.065, 0.2, 0.11)
    return normalize_rms(fade_in_out(snap + zap), 0.13)

def shield_up(seed, variant):
    """护盾激活：能量上升（300-900Hz）+ 管乐。"""
    dur = 0.45
    sweep = frequency_sweep(320 + variant * 15, 880, dur) * 0.48
    sweep = envelope(sweep, 0.018, 0.1, 0.55, 0.16)
    notes = [(0, 0.38, GM["harp"], 52 + variant, 72)]
    brass = render_midi_layer(notes, dur) * 0.4
    return normalize_rms(fade_in_out(sweep + brass), 0.12)

def explosion_heavy(seed, variant):
    """重型爆炸：深沉轰鸣（200-800Hz）+ 定音鼓。"""
    dur = 0.65
    boom = sine_wave(240 + variant * 8, dur) * 0.6
    boom += sine_wave(360, dur) * 0.35
    boom = envelope(boom, 0.005, 0.18, 0.38, 0.28)
    rumble = white_noise(dur, seed + variant) * 0.5
    rumble = bandpass_filter(rumble, 280, 1300)
    rumble = envelope(rumble, 0.007, 0.19, 0.32, 0.26)
    notes = [(0, 0.22, GM["timpani"], 33 + variant, 120)]
    drum = render_midi_layer(notes, dur) * 0.65
    return normalize_rms(fade_in_out(mix_layers(boom, rumble, drum)), 0.18)

def crit_hit(seed, variant):
    """暴击：锐利撞击（1200-2800Hz）+ 下扫。"""
    dur = 0.32
    # 金属音：调制
    t = time_array(dur)
    metal = sine_wave(2200 + variant * 150, dur) * (1 + 0.6 * np.sin(2 * np.pi * 23 * t))
    metal = envelope(metal, 0.002, 0.07, 0.28, 0.13) * 0.45
    energy = frequency_sweep(2000, 700, dur) * 0.35
    energy = envelope(energy, 0.003, 0.08, 0.22, 0.12)
    notes = [(0, 0.14, GM["xylophone"], 84 + variant, 90)]
    bell = render_midi_layer(notes, dur) * 0.4
    return normalize_rms(fade_in_out(metal + energy + bell), 0.15)

def heal_cast(seed, variant):
    """治疗施法：竖琴琶音。"""
    scale = [0, 2, 4, 7, 9, 12, 14, 16]
    notes = []
    start_pitch = 60 + (variant % 3) * 2
    for i in range(6):
        pitch = start_pitch + scale[i]
        notes.append((i * 0.07, 0.42, GM["harp"], pitch, 68 + i * 3))
    audio = render_midi_layer(notes, 0.7)
    return normalize_rms(fade_in_out(audio), 0.11)

def holy_buff(seed, variant):
    """神圣祝福：合唱和弦 + 颤音琴。"""
    root = 60 + variant
    notes = [
        (0, 1.0, 52, root, 58),      # choir
        (0, 1.0, 52, root + 4, 54),
        (0, 1.0, 52, root + 7, 60),
        (0.08, 0.85, GM["vibraphone"], root + 12, 68),
    ]
    audio = render_midi_layer(notes, 1.3)
    return normalize_rms(fade_in_out(audio), 0.11)

def evolve_magic(seed, variant):
    """进化：上升音阶 + 钟琴。"""
    scale = [0, 2, 4, 5, 7, 9, 11, 12]
    notes = []
    for i, offset in enumerate(scale):
        pitch = 60 + offset + variant
        notes.append((i * 0.065, 0.32, GM["celesta"], pitch, 70 + i * 2))
    notes.append((0.45, 0.55, GM["glock"], 84 + variant, 85))
    audio = render_midi_layer(notes, 1.0)
    return normalize_rms(fade_in_out(audio), 0.12)

def pickup_magic(seed, variant):
    """拾取：闪光。"""
    root = 72 + variant * 2
    notes = [
        (0, 0.22, GM["glock"], root, 82),
        (0.055, 0.26, GM["glock"], root + 7, 76),
    ]
    audio = render_midi_layer(notes, 0.35)
    return normalize_rms(fade_in_out(audio), 0.10)

# ============================================================ 渲染

SFX_SPECS = {
    "enemy_hit": {"func": enemy_hit, "variants": 5},
    "enemy_death": {"func": enemy_death, "variants": 5},
    "elite_death": {"func": elite_death, "variants": 5},
    "player_hurt": {"func": player_hurt, "variants": 5},
    "shield_block": {"func": shield_block, "variants": 5},
    "auto_pulse": {"func": auto_pulse, "variants": 5},
    "auto_slash": {"func": auto_slash, "variants": 5},
    "auto_crystal": {"func": auto_crystal, "variants": 5},
    "auto_holy": {"func": auto_holy, "variants": 5},
    "fire_cast": {"func": fire_cast, "variants": 5},
    "fire_impact": {"func": fire_impact, "variants": 5},
    "ice_cast": {"func": ice_cast, "variants": 5},
    "ice_shatter": {"func": ice_shatter, "variants": 5},
    "lightning_cast": {"func": lightning_cast, "variants": 5},
    "lightning_hit": {"func": lightning_hit, "variants": 5},
    "shield_up": {"func": shield_up, "variants": 5},
    "explosion_heavy": {"func": explosion_heavy, "variants": 5},
    "crit_hit": {"func": crit_hit, "variants": 5},
    "heal_cast": {"func": heal_cast, "variants": 5},
    "holy_buff": {"func": holy_buff, "variants": 5},
    "evolve_magic": {"func": evolve_magic, "variants": 5},
    "pickup_magic": {"func": pickup_magic, "variants": 5},
}

def render_sfx(category, variant, seed):
    spec = SFX_SPECS[category]
    func = spec["func"]
    audio = func(seed, variant)
    audio = np.stack([audio, audio], axis=1)
    filename = f"{category}_{variant:03d}.ogg"
    out_path = os.path.join(OUT_DIR, filename)
    with sf.SoundFile(out_path, "w", RATE, 2, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(audio), 8192):
            f.write(np.ascontiguousarray(audio[i:i + 8192]))
    print(f"  {filename}")

def generate_category(category):
    if category not in SFX_SPECS:
        print(f"未知类别：{category}")
        return
    print(f"{category}:")
    spec = SFX_SPECS[category]
    seed = hash(category) % (2**31)
    for variant in range(spec["variants"]):
        render_sfx(category, variant, seed)

def main(categories):
    os.makedirs(OUT_DIR, exist_ok=True)
    all_categories = list(SFX_SPECS.keys())
    to_generate = categories if categories else all_categories
    for cat in to_generate:
        if cat not in all_categories:
            print(f"跳过未知类别：{cat}")
            continue
        generate_category(cat)
    print(f"\n完成！输出目录：{os.path.relpath(OUT_DIR, ROOT)}")

if __name__ == "__main__":
    main(sys.argv[1:])
