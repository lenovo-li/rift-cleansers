"""16 个新技能的专属音效：每个技能一个合成函数，3 个变体。
复用 generate_sfx.py 的 DSP 工具和 FluidSynth 乐器层；输出 assets/sfx/generated/sk_<技能id>_00N.ogg。
SfxManager 里以 "sk_<技能id>" 类别注册。
用法：python tools/audio/skill_sfx.py [技能id ...]
"""
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import soundfile as sf
from generate_sfx import (GM, OUT_DIR, RATE, bandpass_filter, envelope, fade_in_out, frequency_sweep,
                          normalize_rms, render_midi_layer, sine_wave, time_array, white_noise)

VARIANTS = 3


def pad(sig, dur):
    """补零或截断到 dur 秒。"""
    n = int(dur * RATE)
    return np.pad(sig, (0, max(0, n - len(sig))))[:n].astype(np.float32)


def at(sig, start, dur):
    """把 sig 放到 start 秒处，总长 dur 秒。"""
    out = np.zeros(int(dur * RATE), dtype=np.float32)
    i = int(start * RATE)
    seg = sig[:max(0, len(out) - i)]
    out[i:i + len(seg)] += seg
    return out


def decay(sig, tau):
    """指数衰减包络（tau 秒衰减到 1/e）。"""
    t = np.arange(len(sig), dtype=np.float32) / RATE
    return sig * np.exp(-t / tau)


def noise_band(dur, seed, lo, hi):
    return bandpass_filter(white_noise(dur, seed), lo, hi)


def tremolo(sig, rate, depth):
    t = np.arange(len(sig), dtype=np.float32) / RATE
    return sig * (1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t)))


# ============================================================ 铁卫

def earthquake(seed, v):
    """地震：持续 1.6 秒的低沉隆隆（颤动的 180-400Hz 噪声）+ 三次碎石崩裂 + 定音鼓滚奏。"""
    dur = 1.6
    rumble = tremolo(noise_band(dur, seed + v, 150, 420), 11 + v * 2, 0.6)
    rumble = envelope(rumble, 0.08, 0.3, 0.8, 0.6) * 0.9
    cracks = sum(at(decay(noise_band(0.25, seed + 10 + k, 1200, 4500), 0.05), 0.15 + k * 0.38 + v * 0.03, dur)
                 for k in range(3))
    roll = render_midi_layer([(k * 0.09, 0.3, GM["timpani"], 41 + v, 70 + k * 3) for k in range(8)], dur)
    return normalize_rms(fade_in_out(rumble + cracks * 0.6 + roll * 0.7), 0.17)


def iron_wall(seed, v):
    """铁壁：重金属板合拢的"铛"（非谐波金属泛音，长尾）+ 低沉锁扣声。"""
    dur = 1.2
    base = 320 + v * 25
    metal = sum(decay(sine_wave(base * r, dur), 0.5 / r) * a for r, a in ((1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.9, 0.2)))
    clank = decay(noise_band(dur, seed + v, 800, 3000), 0.03) * 0.8
    lock = at(decay(sine_wave(180, 0.2) + noise_band(0.2, seed + 3, 300, 900) * 0.5, 0.04), 0.12, dur)
    return normalize_rms(fade_in_out(metal * 0.6 + clank + lock * 0.7), 0.15)


def war_cry(seed, v):
    """战吼：粗糙的咆哮（锯齿波低音 + 共振峰噪声，音高先升后降）+ 铜管长音。"""
    dur = 1.1
    t = time_array(dur)
    f0 = 140 + v * 10 + 60 * np.sin(np.pi * np.clip(t / 0.8, 0, 1))
    saw = 2.0 * ((np.cumsum(f0) / RATE) % 1.0) - 1.0
    growl = bandpass_filter(saw.astype(np.float32), 200, 2500) * tremolo(np.ones_like(t), 28, 0.4)
    breath = noise_band(dur, seed + v, 500, 1800) * 0.3
    voice = envelope(growl + breath, 0.05, 0.2, 0.75, 0.35)
    horn = render_midi_layer([(0.05, 0.9, 61, 50 + v, 95), (0.05, 0.9, 61, 57 + v, 85)], dur)  # 61 = 铜管组
    return normalize_rms(fade_in_out(voice + horn * 0.6), 0.17)


def flame_cleave(seed, v):
    """烈焰斩：刀刃破风（下扫噪声）+ 火焰呼地燃起（低通噪声膨胀）+ 噼啪火星。"""
    dur = 0.9
    swish = envelope(noise_band(0.25, seed + v, 1500, 6000) * frequency_sweep(3000, 600, 0.25), 0.005, 0.05, 0.6, 0.15)
    roar = envelope(noise_band(dur, seed + 5, 200, 1400), 0.06, 0.15, 0.6, 0.5)
    rng = np.random.RandomState(seed + v)
    crackle = sum(at(decay(noise_band(0.03, seed + 20 + k, 2500, 7000), 0.008), rng.uniform(0.15, 0.8), dur)
                  for k in range(14))
    return normalize_rms(fade_in_out(pad(swish, dur) * 0.9 + roar * 0.8 + crackle * 0.7), 0.16)


# ============================================================ 元素术士

def thunderstorm(seed, v):
    """雷暴：低沉的雷鸣滚动（80-200Hz 噪声膨胀）+ 密集电流滋滋声 + 定音鼓击打。"""
    dur = 1.4
    thunder = tremolo(noise_band(dur, seed + v, 80, 250), 7 + v, 0.5)
    thunder = envelope(thunder, 0.15, 0.4, 0.7, 0.6)
    electric = tremolo(noise_band(dur, seed + 10, 3500, 8000), 45 + v * 5, 0.8) * 0.5
    electric = envelope(electric, 0.08, 0.25, 0.6, 0.4)
    drum = render_midi_layer([(k * 0.18, 0.4, GM["timpani"], 38 + v, 80 + k * 2) for k in range(5)], dur)
    return normalize_rms(fade_in_out(thunder * 0.9 + electric * 0.7 + drum * 0.6), 0.17)


def frost_barrier(seed, v):
    """冰霜护盾：冰晶形成的破裂（高频碎裂音）+ 冰墙升起（扫频噪声）+ 钟琴和弦。"""
    dur = 0.9
    shatter = decay(noise_band(0.4, seed + v, 4000, 9000), 0.08)
    rise = envelope(frequency_sweep(200, 800, 0.5) * noise_band(0.5, seed + 5, 500, 2000), 0.02, 0.1, 0.7, 0.3)
    notes = [(0, 0.7, GM["glock"], p, 75) for p in [72 + v, 76 + v, 79 + v]]
    chime = render_midi_layer(notes, dur)
    return normalize_rms(fade_in_out(pad(shatter, dur) * 0.7 + pad(rise, dur) * 0.8 + chime * 0.5), 0.14)


def arcane_barrage(seed, v):
    """奥术弹幕：连续脉冲（10 发短促的 zap，音高递减）+ 魔法粒子嗡鸣。"""
    dur = 1.3
    rng = np.random.RandomState(seed + v)
    zaps = sum(at(decay(sine_wave(1200 - k * 60, 0.05) * noise_band(0.05, seed + k, 1500, 4000), 0.012),
                  k * 0.12 + rng.uniform(0, 0.02), dur) for k in range(10))
    hum = tremolo(sine_wave(420 + v * 20, dur), 18, 0.6) * 0.4
    hum = envelope(hum, 0.05, 0.2, 0.6, 0.5)
    return normalize_rms(fade_in_out(zaps * 0.8 + hum), 0.15)


def lava_blast(seed, v):
    """熔岩爆发：深沉爆炸（80Hz 冲击 + 中频轰鸣）+ 岩石碎裂 + 火焰呼啸。"""
    dur = 1.2
    boom = decay(sine_wave(80 + v * 5, 0.3) * 2.5, 0.15)
    rumble = envelope(noise_band(dur, seed + v, 150, 600), 0.05, 0.2, 0.7, 0.5)
    rocks = decay(noise_band(0.5, seed + 10, 800, 3500), 0.12)
    roar = envelope(noise_band(dur, seed + 15, 300, 1800), 0.08, 0.25, 0.65, 0.45)
    return normalize_rms(fade_in_out(pad(boom, dur) + rumble * 0.7 + pad(rocks, dur) * 0.6 + roar * 0.5), 0.18)


# ============================================================ 影行者

def eviscerate(seed, v):
    """剔骨：快速切割（刀刃摩擦金属，下扫）+ 血液飞溅（液体喷射噪声）+ 沉闷撞击。"""
    dur = 0.8
    slice_sound = frequency_sweep(2200, 800, 0.22) * noise_band(0.22, seed + v, 1500, 5000)
    slice_sound = envelope(slice_sound, 0.002, 0.05, 0.6, 0.12)
    splash = decay(noise_band(0.35, seed + 10, 600, 2000), 0.08) * 0.7
    thud = decay(sine_wave(120 + v * 8, 0.15) + noise_band(0.15, seed + 15, 200, 800), 0.05)
    return normalize_rms(fade_in_out(pad(slice_sound, dur) + at(splash, 0.18, dur) + at(thud, 0.25, dur)), 0.16)


def shadow_clone(seed, v):
    """暗影分身：空间撕裂（快速下扫噪声 + 回音）+ 暗影雾气（低频脉动）。"""
    dur = 0.9
    tear = frequency_sweep(3500, 400, 0.25) * noise_band(0.25, seed + v, 1000, 6000)
    tear = envelope(tear, 0.005, 0.06, 0.5, 0.15)
    echo = at(tear * 0.4, 0.18, dur) + at(tear * 0.2, 0.36, dur)
    mist = tremolo(sine_wave(180 + v * 12, dur), 9 + v, 0.7) * 0.5
    mist = envelope(mist, 0.1, 0.2, 0.6, 0.4)
    return normalize_rms(fade_in_out(pad(tear, dur) + echo + mist), 0.14)


def backstab(seed, v):
    """背刺：锐器刺穿（尖锐冲击 + 入肉声）+ 短促喘息。"""
    dur = 0.6
    pierce = decay(sine_wave(1800 + v * 100, 0.08) * noise_band(0.08, seed + v, 2000, 6000), 0.02)
    flesh = decay(noise_band(0.15, seed + 10, 400, 1200), 0.05) * 0.6
    gasp = at(decay(noise_band(0.12, seed + 15, 800, 2500), 0.04), 0.22, dur) * 0.5
    return normalize_rms(fade_in_out(pad(pierce, dur) + at(flesh, 0.08, dur) + gasp), 0.15)


def poison_blade(seed, v):
    """毒刃：液体滋滋声（腐蚀性噪声，带颤音）+ 毒雾扩散（低沉嘶嘶声）+ 水晶琴点缀。"""
    dur = 1.0
    hiss = tremolo(noise_band(dur, seed + v, 2500, 7000), 35 + v * 5, 0.7) * 0.6
    hiss = envelope(hiss, 0.05, 0.15, 0.65, 0.45)
    fog = envelope(noise_band(dur, seed + 10, 300, 1000), 0.08, 0.25, 0.6, 0.5) * 0.5
    notes = [(k * 0.15, 0.3, GM["celesta"], 60 + v * 2 + k * 3, 70) for k in range(5)]
    bell = render_midi_layer(notes, dur) * 0.4
    return normalize_rms(fade_in_out(hiss + fog + bell), 0.14)


# ============================================================ 牧师

def guardian_angel(seed, v):
    """守护天使：圣洁合唱（人声和弦）+ 翅膀扇动（柔和气流声）+ 竖琴琶音。"""
    dur = 1.3
    chord = render_midi_layer([(0, 1.1, 52, p, 65) for p in [60 + v, 64 + v, 67 + v, 72 + v]], dur)  # 52 = 合唱"啊"
    wings = envelope(noise_band(dur, seed + v, 400, 1500), 0.15, 0.3, 0.7, 0.5) * 0.4
    harp = render_midi_layer([(k * 0.08, 0.6, GM["harp"], 60 + v * 2 + k * 2, 68 + k * 2) for k in range(8)], dur)
    return normalize_rms(fade_in_out(chord * 0.6 + wings + harp * 0.5), 0.13)


def purify(seed, v):
    """净化：光波扩散（上扫频 + 颤音琴）+ 驱散声（高频碎裂消散）。"""
    dur = 1.0
    wave = frequency_sweep(300, 1200, 0.6) * envelope(sine_wave(600, 0.6), 0.05, 0.15, 0.8, 0.3)
    shatter = at(decay(noise_band(0.4, seed + v, 4000, 8000), 0.12), 0.35, dur) * 0.6
    notes = [(k * 0.12, 0.4, GM["vibraphone"], 72 + v * 2 + k * 3, 72 - k * 2) for k in range(6)]
    chime = render_midi_layer(notes, dur)
    return normalize_rms(fade_in_out(pad(wave, dur) + shatter + chime * 0.6), 0.14)


def resurrection(seed, v):
    """复活术：升天合唱（庄严和弦 + 上行旋律）+ 光芒（明亮钟琴）+ 深沉鼓点。"""
    dur = 1.8
    choir_notes = [(0, 1.5, 52, p, 70) for p in [55 + v, 60 + v, 64 + v, 67 + v]]
    melody = [(k * 0.2, 0.5, 52, 67 + v + k * 2, 75 - k * 3) for k in range(7)]
    choir = render_midi_layer(choir_notes + melody, dur)
    bells = render_midi_layer([(k * 0.15, 0.7, GM["glock"], 79 + v + k * 2, 80 - k * 2) for k in range(8)], dur)
    drum = render_midi_layer([(k * 0.45, 0.5, GM["timpani"], 43 + v, 75) for k in range(3)], dur)
    return normalize_rms(fade_in_out(choir * 0.65 + bells * 0.6 + drum * 0.5), 0.15)


def holy_wrath(seed, v):
    """圣怒：天罚雷击（尖锐电击 + 深沉轰鸣）+ 圣焰爆炸（高频碎裂）+ 管风琴强音。"""
    dur = 1.1
    strike = decay(sine_wave(2200 + v * 150, 0.12) * noise_band(0.12, seed + v, 2000, 7000), 0.03)
    thunder = decay(sine_wave(90 + v * 5, 0.4), 0.18) * 1.8
    explosion = at(decay(noise_band(0.5, seed + 10, 3000, 8000), 0.15), 0.15, dur) * 0.7
    organ = render_midi_layer([(0.05, 0.9, 19, p, 100) for p in [48 + v, 55 + v, 60 + v]], dur)  # 19 = 管风琴
    return normalize_rms(fade_in_out(pad(strike, dur) + pad(thunder, dur) + explosion + organ * 0.7), 0.18)


# ============================================================ 渲染和主入口

SKILL_SPECS = {
    "earthquake": earthquake, "iron_wall": iron_wall, "war_cry": war_cry, "flame_cleave": flame_cleave,
    "thunderstorm": thunderstorm, "frost_barrier": frost_barrier, "arcane_barrage": arcane_barrage,
    "lava_blast": lava_blast, "eviscerate": eviscerate, "shadow_clone": shadow_clone, "backstab": backstab,
    "poison_blade": poison_blade, "guardian_angel": guardian_angel, "purify": purify, "resurrection": resurrection,
    "holy_wrath": holy_wrath,
}


def render_skill_sfx(skill_id, variant, seed):
    """渲染一个变体，输出 sk_{skill_id}_{variant:03d}.ogg"""
    func = SKILL_SPECS[skill_id]
    audio_mono = func(seed, variant)
    audio_stereo = np.column_stack([audio_mono, audio_mono])
    filename = f"sk_{skill_id}_{variant:03d}.ogg"
    out_path = os.path.join(OUT_DIR, filename)
    with sf.SoundFile(out_path, "w", RATE, 2, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(audio_stereo), 8192):
            f.write(np.ascontiguousarray(audio_stereo[i:i + 8192]))
    print(f"  {filename}")


def generate_skill(skill_id):
    if skill_id not in SKILL_SPECS:
        print(f"未知技能：{skill_id}")
        return
    print(f"{skill_id}:")
    seed = zlib.crc32(skill_id.encode()) % 100000  # 稳定种子：重新生成结果不变
    for v in range(VARIANTS):
        render_skill_sfx(skill_id, v, seed)


def main(skills):
    os.makedirs(OUT_DIR, exist_ok=True)
    all_skills = list(SKILL_SPECS.keys())
    to_gen = skills if skills else all_skills
    for sk in to_gen:
        if sk not in all_skills:
            print(f"跳过未知技能：{sk}")
            continue
        generate_skill(sk)
    print(f"\n完成！输出目录：{os.path.relpath(OUT_DIR, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))}")


if __name__ == "__main__":
    main(sys.argv[1:])



