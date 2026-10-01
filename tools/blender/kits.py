"""场景零件：障碍石堆、地面装饰、四张地图的模块化零件包。
零件以地面中心为原点，碰撞尺寸由 Godot 侧 MapCatalog 决定，这里的外形尺寸与 v1 保持一致。
地面装饰每种会撒几百上千个，面数压在几百；大零件每种一两百个，压在几千。"""
import math
import random

import lowpoly as lp
from palette import BONE, GOLD



def _stone_courses(length, height, depth, color, rows, seed, y=0.0, z0=0.0, gap=0.02):
    """砌石墙体：按层错缝的圆角石块（每块颜色微调）。"""
    rng = random.Random(seed)
    h = height / rows
    for r in range(rows):
        x = -length / 2
        first = rng.uniform(0.3, 0.7) if r % 2 else rng.uniform(0.6, 1.0)
        w = first
        while x < length / 2 - 0.05:
            w = min(w, length / 2 - x)
            k = rng.uniform(0.88, 1.08)
            lp.box((x + w / 2, y + rng.uniform(-0.02, 0.02), z0 + h * r + h / 2),
                   (w - gap, depth + rng.uniform(-0.03, 0.03), h - gap), lp.shade(color, k), bevel=0.04, ao=0.1)
            x += w
            w = rng.uniform(0.7, 1.2)


def rocks():
    """障碍物石堆：3 块不规则石头 + 碎石，以 1 米为单位，Godot 按障碍物尺寸缩放。"""
    grey = (0.46, 0.43, 0.40)
    lp.rock((0, 0, 0.45), (0.55, 0.45, 0.5), grey, seed=1)
    lp.rock((0.35, 0.25, 0.3), (0.3, 0.28, 0.32), (0.5, 0.47, 0.43), seed=2)
    lp.rock((-0.3, -0.2, 0.25), (0.28, 0.3, 0.26), (0.4, 0.38, 0.35), seed=3)
    for k, (x, y) in enumerate(((0.5, -0.2), (-0.45, 0.25), (0.15, 0.45))):
        lp.rock((x, y, 0.05), (0.08, 0.07, 0.06), (0.42, 0.4, 0.37), seed=4 + k, subdiv=2)
    lp.rock((0.0, 0.05, 0.9), (0.4, 0.33, 0.08), (0.36, 0.42, 0.26), seed=8, jitter=0.1, flat_bottom=False)  # 顶上青苔


def decor():
    """地面散布装饰（Godot 用 MultiMesh 随机撒在场地上）：碎石、枯草、骨头、焦土裂缝。"""
    groups = {}
    lp.rock((0, 0, 0.06), (0.14, 0.12, 0.08), (0.42, 0.4, 0.37), seed=11, jitter=0.35, subdiv=2)
    lp.rock((0.2, 0.1, 0.04), (0.08, 0.07, 0.05), (0.36, 0.34, 0.31), seed=12, jitter=0.35, subdiv=1)
    groups["pebbles"] = lp.take_parts()
    for i, (x, y, r) in enumerate(((0, 0, 0), (0.06, 0.03, 40), (-0.05, 0.04, -35), (0.02, -0.06, 15), (-0.03, -0.03, 70))):
        lp.blade((x, y, 0.0), 0.24 + (i % 2) * 0.06, 0.03, 0.006, (0.55, 0.5, 0.28), rot=(90 - abs(r) * 0.4, 0, i * 72),
                 tip=0.6, curve=0.05, seg=3, ao=0.35)
    groups["grass"] = lp.take_parts()
    lp.capsule((-0.16, 0, 0.03), (0.16, 0.02, 0.03), 0.022, BONE, seg=6)
    for x in (-0.17, 0.17):
        for y in (-0.02, 0.025):
            lp.ball((x, y, 0.03), (0.026, 0.026, 0.024), BONE, subdiv=1)
    lp.ball((0.24, 0.12, 0.05), (0.05, 0.055, 0.045), BONE, subdiv=2)          # 小头骨
    groups["bones"] = lp.take_parts()
    lp.tube([(-0.45, -0.05, 0.004), (-0.1, 0.02, 0.004), (0.15, -0.03, 0.004), (0.45, 0.06, 0.004)],
            [0.01, 0.035, 0.03, 0.005], (0.22, 0.2, 0.19), flat=0.15, flat_axis=(0, 0, 1), seg=6, cap=False)
    lp.tube([(-0.1, 0.02, 0.004), (0.05, 0.15, 0.004), (0.2, 0.3, 0.004)], [0.025, 0.02, 0.004],
            (0.22, 0.2, 0.19), flat=0.15, flat_axis=(0, 0, 1), seg=6, cap=False)
    groups["crack"] = lp.take_parts()
    return groups


def _column(h, r, color, cap_color, flutes=12, base=1.1):
    """带凹槽的柱子：方底座 + 圆盘线脚 + 柱身（细凹槽）+ 柱头。"""
    lp.box((0, 0, 0.2), (base, base, 0.4), cap_color, bevel=0.05)
    lp.cyl((0, 0, 0.47), r * 1.25, 0.14, color)
    lp.cyl((0, 0, 0.4 + h / 2), r, h, color, radius2=r * 0.92)
    for k in range(flutes):
        a = k * 2 * math.pi / flutes
        lp.box((math.cos(a) * r * 0.98, math.sin(a) * r * 0.98, 0.4 + h / 2), (0.05, 0.05, h * 0.86),
               lp.shade(color, 0.8), rot=(0, 0, math.degrees(a)), bevel=0.02, ao=0.05)


def city_kit():
    """灰烬王城模块化零件：城墙、断墙、石柱、断柱、残塔、火盆、无头王像、瓦砾堆。"""
    stone = (0.42, 0.40, 0.38)
    stone_dark = (0.28, 0.26, 0.25)
    char = (0.14, 0.12, 0.12)
    ember = (1.0, 0.45, 0.12)
    royal = (0.38, 0.16, 0.42)
    groups = {}
    # 城墙段：长 6 米、高 1.8 米 + 残缺垛口，厚 0.8 米
    _stone_courses(6.0, 1.8, 0.8, stone, 5, seed=1)
    for x, h in ((-2.4, 0.8), (-1.2, 0.5), (0.3, 0.9), (1.6, 0.35), (2.5, 0.7)):
        lp.box((x, 0, 1.8 + h / 2), (1.1, 0.8, h), stone if h > 0.5 else stone_dark, bevel=0.06)
    lp.box((0, 0.42, 0.15), (6.1, 0.1, 0.3), char, bevel=0.03)                   # 墙根焦痕
    lp.cyl((0.3, 0.46, 2.15), 0.03, 1.2, (0.3, 0.22, 0.15), rot=(0, 90, 0))       # 旗杆
    lp.tube([(-0.12, 0.47, 2.1), (-0.1, 0.5, 1.6), (-0.06, 0.48, 1.1), (0.0, 0.5, 0.9)], [0.45, 0.45, 0.4, 0.3],
            royal, flat=0.05, flat_axis=(0, 1, 0), seg=10)                         # 残破王旗
    lp.box((0.3, 0.5, 1.7), (0.3, 0.02, 0.36), GOLD, bevel=0.01, ao=0.05)         # 旗上纹章
    for k, (x, z) in enumerate(((-2.0, 0.9), (1.2, 1.2), (2.3, 0.5))):
        lp.box((x, 0.41, z), (0.4, 0.03, 0.05), char, rot=(0, 25 * (k - 1), 0), bevel=0.01)  # 裂缝
    groups["wall"] = lp.take_parts()
    # 断墙：半截 + 倒塌碎块
    _stone_courses(3.2, 1.2, 0.8, stone_dark, 3, seed=2)
    lp.box((-0.9, 0, 1.4), (1.2, 0.8, 0.4), stone, bevel=0.06)
    for k, (x, y, s) in enumerate(((2.2, 0.4, 0.6), (2.7, -0.5, 0.4), (1.9, -0.3, 0.3), (2.6, 0.6, 0.25))):
        lp.rock((x, y, s * 0.5), (s, s * 0.85, s * 0.55), stone if k % 2 else stone_dark, seed=21 + k)
    groups["wall_broken"] = lp.take_parts()
    # 石柱
    _column(3.0, 0.38, stone, stone_dark)
    lp.cyl((0, 0, 3.47), 0.46, 0.14, stone)
    lp.box((0, 0, 3.6), (1.0, 1.0, 0.24), stone_dark, bevel=0.05)
    groups["pillar"] = lp.take_parts()
    # 断柱：短柱身 + 断口 + 倒地的上半截
    _column(0.8, 0.38, stone, stone_dark)
    lp.rock((0, 0, 1.25), (0.36, 0.36, 0.12), stone, seed=25, jitter=0.4, flat_bottom=False)  # 断口
    with lp.frame((1.3, 0.2, 0.38), (0, 90, 25)):
        lp.cyl((0, 0, 0), 0.36, 1.6, stone)
        lp.box((0, 0, 0.9), (0.9, 0.9, 0.24), stone_dark, bevel=0.05)
    groups["pillar_broken"] = lp.take_parts()
    # 残塔：直径 4.4 米，砌石外壁 + 高低不齐的垛口 + 门洞 + 窗洞
    for r in range(6):
        k = 0.92 + (r % 3) * 0.05
        lp.cyl((0, 0, 0.37 + r * 0.73), 2.2 - r * 0.02, 0.71, lp.shade(stone_dark, k), verts=24)
    lp.cyl((0, 0, 4.45), 2.15, 0.1, stone, verts=24)
    for i in range(8):
        a = i * math.pi / 4
        h = 0.5 + (i % 3) * 0.35
        lp.box((math.cos(a) * 1.9, math.sin(a) * 1.9, 4.5 + h / 2), (0.9, 0.6, h), stone,
               rot=(0, 0, math.degrees(a) + 90), bevel=0.05)
    lp.box((0, 2.1, 0.7), (1.1, 0.3, 1.4), char, bevel=0.03)                     # 拱形门洞
    lp.cyl((0, 2.1, 1.4), 0.55, 0.3, char, rot=(90, 0, 0))
    for a in (0.8, 2.4, 4.0):
        lp.box((math.cos(a) * 2.18, math.sin(a) * 2.18, 3.0), (0.15, 0.35, 0.6), char, rot=(0, 0, math.degrees(a)), bevel=0.03)
    groups["tower"] = lp.take_parts()
    # 火盆：石座 + 铁盆 + 余烬 + 火焰
    lp.lathe((0, 0, 0), [(0.42, 0.0), (0.42, 0.1), (0.3, 0.16), (0.24, 0.6), (0.34, 0.7)], stone_dark, seg=8)
    lp.lathe((0, 0, 0), [(0.3, 0.68), (0.55, 0.78), (0.72, 1.0), (0.66, 1.0), (0.5, 0.82), (0.0, 0.8)], char)
    for a in range(4):
        lp.cone((math.cos(a * 1.57) * 0.7, math.sin(a * 1.57) * 0.7, 1.04), 0.04, 0.14, char, verts=6)
    lp.ball((0, 0, 0.96), (0.55, 0.55, 0.14), ember, ao=0)
    for k in range(5):
        a = k * 1.25
        lp.tube([(math.cos(a) * 0.2, math.sin(a) * 0.2, 0.98), (math.cos(a) * 0.15, math.sin(a) * 0.15, 1.25),
                 (math.cos(a + 0.5) * 0.1, math.sin(a + 0.5) * 0.1, 1.5 - (k % 2) * 0.15)], [0.12, 0.07, 0.005],
                (1.0, 0.65, 0.2), ao=0)
    groups["brazier"] = lp.take_parts()
    return _city_kit_2(groups, stone, stone_dark, char, royal)


def _city_kit_2(groups, stone, stone_dark, char, royal):
    # 无头王像：两层台座 + 披风身躯 + 肩甲 + 断颈焦痕 + 双手拄断剑
    lp.box((0, 0, 0.6), (2.6, 2.6, 1.2), stone_dark, bevel=0.08)
    lp.box((0, 0, 1.35), (2.2, 2.2, 0.3), stone, bevel=0.06)
    lp.box((0, 1.31, 0.7), (1.2, 0.04, 0.5), lp.shade(stone_dark, 0.8), bevel=0.02)  # 铭牌
    lp.lathe((0, 0, 0), [(0.85, 1.5), (0.82, 2.0), (0.7, 2.8), (0.62, 3.5), (0.5, 3.85), (0.25, 4.0)],
             stone, wobble=0.08, seed=31, scale=(1, 0.8, 1))                       # 披风身躯
    for x in (0.62, -0.62):
        lp.ball((x, 0, 3.75), (0.36, 0.32, 0.24), stone)
        lp.limb([(x, 0.05, 3.6), (x * 1.05, 0.3, 3.0), (x * 0.25, 0.62, 2.75)], [0.18, 0.15, 0.13], stone)
    lp.ball((0, 0.65, 2.72), (0.22, 0.18, 0.18), stone)                           # 交握的双手
    lp.cyl((0, 0, 4.02), 0.28, 0.12, char)                                         # 断颈焦痕
    lp.rock((0, 0, 4.1), (0.25, 0.25, 0.08), char, seed=32, jitter=0.4, flat_bottom=False)
    lp.box((0, 0.68, 2.95), (0.6, 0.12, 0.12), stone_dark, bevel=0.03)            # 剑格
    lp.box((0, 0.68, 2.0), (0.22, 0.08, 1.8), stone_dark, bevel=0.03)             # 断剑
    lp.cyl((0, 0.68, 3.2), 0.06, 0.4, stone_dark)
    groups["statue"] = lp.take_parts()
    # 瓦砾堆
    for i, (x, y, sz) in enumerate(((0, 0, 0.7), (0.8, 0.3, 0.45), (-0.6, 0.5, 0.4), (0.2, -0.7, 0.5), (-0.5, -0.4, 0.3))):
        lp.rock((x, y, sz * 0.5), (sz, sz * 0.9, sz * 0.6), stone if i % 2 else stone_dark, seed=30 + i)
    lp.box((0.5, 0.6, 0.15), (0.7, 0.35, 0.3), stone, rot=(8, 0, 30), bevel=0.05)  # 方石块
    for k, a in enumerate((30, -20, 75)):
        lp.cyl((0.4 - k * 0.3, -0.2 + k * 0.2, 0.12 + k * 0.05), 0.07, 1.2 - k * 0.2, char, rot=(0, 85, a), verts=7)  # 焦木
    groups["rubble"] = lp.take_parts()
    return groups


def frost_kit():
    """霜冻冰原零件：冰刺、雪松、雪岩、冰墙、发光冰晶、冰图腾（地标），以及地面装饰。"""
    ice = (0.62, 0.82, 0.95)
    ice_dark = (0.35, 0.55, 0.75)
    snow = (0.92, 0.95, 0.98)
    rock = (0.40, 0.44, 0.50)
    pine = (0.16, 0.30, 0.28)
    bark = (0.30, 0.22, 0.18)
    glow = (0.45, 0.85, 1.0)
    groups = {}
    for i, (x, y, h, r) in enumerate(((0, 0, 3.6, 0.45), (0.5, 0.3, 2.4, 0.35), (-0.45, 0.25, 2.0, 0.3),
                                      (0.1, -0.5, 1.6, 0.28), (-0.3, -0.35, 1.1, 0.2), (0.55, -0.2, 0.9, 0.18))):
        lp.cone((x, y, h / 2), r, h, ice if i % 2 == 0 else ice_dark, rot=(i * 6 - 8, i * 5, i * 40), verts=6, ao=0.3)
    lp.rock((0, 0, 0.15), (0.9, 0.8, 0.25), snow, seed=40, jitter=0.15)
    groups["ice_spire"] = lp.take_parts()
    lp.tube([(0, 0, 0), (0.02, 0, 1.0), (0, 0.02, 4.4)], [0.24, 0.18, 0.04], bark, seg=10)
    for i, (z, r) in enumerate(((1.3, 1.25), (2.1, 1.05), (2.85, 0.85), (3.55, 0.62), (4.2, 0.4))):
        lp.lathe((0, 0, z), [(r, 0.0), (r * 0.82, 0.12), (r * 0.45, 0.6), (0.0, 1.0)], pine, wobble=0.12, seed=i, seg=14)
        lp.lathe((0, 0, z + 0.08), [(r * 0.86, 0.06), (r * 0.7, 0.16), (r * 0.36, 0.55), (0.0, 0.85)], snow,
                 wobble=0.14, seed=i + 7, seg=14, ao=0.08)
    groups["pine"] = lp.take_parts()
    lp.rock((0, 0, 0.6), (1.1, 1.0, 0.7), rock, seed=41)
    lp.rock((0.1, 0.05, 1.0), (0.95, 0.85, 0.3), snow, seed=42, jitter=0.12, flat_bottom=False)
    lp.rock((0.9, 0.5, 0.2), (0.3, 0.28, 0.22), rock, seed=45)
    groups["ice_rock"] = lp.take_parts()
    _stone_courses(6.0, 1.8, 0.9, ice_dark, 3, seed=46)
    for x, h in ((-2.2, 0.7), (-0.6, 0.4), (1.0, 0.8), (2.4, 0.5)):
        lp.box((x, 0, 1.8 + h / 2), (1.2, 0.9, h), ice, bevel=0.08)
        lp.cone((x + 0.3, 0.46, 1.8 + h - 0.15), 0.06, 0.4, ice, rot=(180, 0, 0), verts=5)  # 冰溜子
    lp.box((0, 0, 1.85), (6.1, 1.0, 0.14), snow, bevel=0.06, ao=0.05)
    groups["frozen_wall"] = lp.take_parts()
    for k, (x, y, h, r, rx, ry) in enumerate(((0, 0, 1.6, 0.3, 0, 0), (0.25, 0.1, 1.0, 0.18, 20, 30),
                                               (-0.22, 0.12, 0.8, 0.15, -25, 10), (0.05, -0.25, 0.7, 0.14, 10, -30))):
        with lp.frame((x, y, 0.1), (rx, ry, k * 40)):
            lp.cyl((0, 0, h * 0.4), r, h * 0.8, glow, verts=6, ao=0)
            lp.cone((0, 0, h * 0.8 + r * 0.6), r, r * 1.2, glow, verts=6, ao=0)
    lp.rock((0, 0, 0.1), (0.55, 0.5, 0.2), rock, seed=43)
    groups["crystal"] = lp.take_parts()
    lp.box((0, 0, 0.4), (2.0, 2.0, 0.8), rock, bevel=0.08)
    lp.box((0, 0, 0.85), (1.6, 1.6, 0.12), snow, bevel=0.05, ao=0.05)
    lp.cyl((0, 0, 2.3), 0.55, 3.0, ice_dark, verts=6)
    for z in (1.4, 2.4, 3.3):
        lp.cyl((0, 0, z), 0.6, 0.12, ice, verts=6)
    for i in range(4):
        a = i * math.pi / 2
        lp.cone((math.cos(a) * 0.6, math.sin(a) * 0.6, 3.6), 0.2, 1.0, ice,
                rot=(math.degrees(math.sin(a)) * 0.5, -math.degrees(math.cos(a)) * 0.5, 0), verts=5)
    lp.ball((0, 0, 4.1), (0.35, 0.35, 0.35), glow, ao=0)
    lp.torus((0, 0, 4.1), 0.5, 0.03, glow, rot=(70, 0, 0), ao=0)
    groups["totem"] = lp.take_parts()
    lp.ball((0, 0, 0.03), (0.3, 0.25, 0.06), snow, subdiv=2, ao=0.05)
    lp.ball((0.25, 0.1, 0.02), (0.18, 0.14, 0.04), snow, subdiv=1, ao=0.05)
    groups["d_snow"] = lp.take_parts()
    lp.cone((0, 0, 0.12), 0.05, 0.25, ice, rot=(15, 0, 0), verts=5)
    lp.cone((0.08, 0.05, 0.08), 0.04, 0.16, ice_dark, rot=(-20, 10, 0), verts=5)
    groups["d_shard"] = lp.take_parts()
    lp.rock((0, 0, 0.05), (0.12, 0.1, 0.07), rock, seed=44, jitter=0.35, subdiv=2)
    groups["d_pebble"] = lp.take_parts()
    return groups


def desert_kit():
    """沙海遗迹零件：砂岩墙、方尖碑（地标）、砂岩柱、仙人掌、台地岩、火盆瓮，以及地面装饰。"""
    sand = (0.85, 0.70, 0.46)
    sand_dark = (0.66, 0.50, 0.32)
    red_rock = (0.68, 0.38, 0.24)
    cactus = (0.30, 0.52, 0.26)
    ember = (1.0, 0.55, 0.15)
    groups = {}
    _stone_courses(6.0, 2.0, 0.8, sand, 4, seed=51)
    for x, h in ((-2.3, 0.4), (-0.9, 0.7), (0.8, 0.3), (2.2, 0.6)):
        lp.box((x, 0, 2.0 + h / 2), (1.3, 0.8, h), sand_dark, bevel=0.06)
    lp.box((0, 0.42, 1.2), (1.4, 0.04, 0.7), (0.3, 0.45, 0.6), bevel=0.02)       # 褪色壁画
    lp.box((0, 0.44, 1.2), (0.12, 0.03, 0.5), GOLD, bevel=0.01)                  # 壁画里的金色人形
    lp.ball((0, 0.44, 1.5), (0.08, 0.02, 0.08), GOLD)
    lp.lathe((0, 0, 0), [(1.6, 0.0), (1.3, 0.25), (0.6, 0.45), (0.0, 0.5)], sand, scale=(1.5, 0.5, 1), seg=16)  # 墙根积沙
    groups["sand_wall"] = lp.take_parts()
    lp.box((0, 0, 0.3), (2.2, 2.2, 0.6), sand_dark, bevel=0.06)
    lp.box((0, 0, 0.7), (1.7, 1.7, 0.2), sand, bevel=0.05)
    lp.cyl((0, 0, 3.4), 0.7, 5.2, sand, radius2=0.45, verts=4, rot=(0, 0, 45), bevel=0.03)
    lp.cone((0, 0, 6.3), 0.45, 0.6, GOLD, verts=4, rot=(0, 0, 45))
    for z in (1.6, 2.6, 3.6, 4.6):                                                  # 象形刻字
        w = 0.62 - (z - 1.6) * 0.06
        lp.box((0, w * 0.72, z), (0.3, 0.03, 0.12), sand_dark, bevel=0.01)
        lp.box((w * 0.72, 0, z + 0.3), (0.03, 0.3, 0.12), sand_dark, bevel=0.01)
    groups["obelisk"] = lp.take_parts()
    _column(3.0, 0.34, sand, sand_dark, flutes=8, base=1.0)
    lp.lathe((0, 0, 3.4), [(0.34, 0.0), (0.5, 0.12), (0.5, 0.16)], sand)          # 莲花柱头
    lp.box((0, 0, 3.65), (0.9, 0.9, 0.2), sand_dark, bevel=0.05)
    groups["sand_pillar"] = lp.take_parts()
    lp.capsule((0, 0, 0.0), (0, 0, 2.1), 0.28, cactus, radius2=0.24, seg=16)
    lp.tube([(0.2, 0, 1.0), (0.42, 0, 1.05), (0.52, 0, 1.3), (0.52, 0, 1.75)], [0.14, 0.14, 0.13, 0.12], cactus)
    lp.ball((0.52, 0, 1.76), (0.12, 0.12, 0.08), cactus)
    lp.tube([(-0.2, 0, 0.8), (-0.38, 0, 0.85), (-0.45, 0, 1.05), (-0.45, 0, 1.35)], [0.13, 0.13, 0.12, 0.11], cactus)
    lp.ball((-0.45, 0, 1.36), (0.11, 0.11, 0.07), cactus)
    for k in range(8):                                                               # 棱纹
        a = k * math.pi / 4
        lp.capsule((math.cos(a) * 0.26, math.sin(a) * 0.26, 0.15), (math.cos(a) * 0.23, math.sin(a) * 0.23, 2.0),
                   0.03, lp.shade(cactus, 1.15), seg=6)
    lp.ball((0, 0, 2.18), (0.08, 0.08, 0.05), (0.95, 0.5, 0.6), ao=0)              # 花
    groups["cactus"] = lp.take_parts()
    lp.rock((0, 0, 1.0), (1.5, 1.3, 1.0), red_rock, seed=51, jitter=0.18)
    for k in range(3):                                                               # 岩层
        lp.lathe((0, 0, 0.45 + k * 0.45), [(1.25 - k * 0.12, 0.0), (1.3 - k * 0.12, 0.06), (1.22 - k * 0.12, 0.12)],
                 lp.shade(red_rock, 0.85 + k * 0.1), wobble=0.12, seed=k, scale=(1.05, 0.9, 1))
    lp.rock((0, 0, 1.95), (1.15, 1.0, 0.18), sand_dark, seed=52, jitter=0.1, flat_bottom=False)
    groups["mesa_rock"] = lp.take_parts()
    lp.lathe((0, 0, 0), [(0.2, 0.0), (0.32, 0.12), (0.38, 0.45), (0.3, 0.75), (0.22, 0.85), (0.27, 0.92)], red_rock)
    lp.torus((0, 0, 0.45), 0.385, 0.02, GOLD)
    lp.ball((0, 0, 0.9), (0.24, 0.24, 0.08), ember, ao=0)
    lp.tube([(0, 0, 0.9), (0.03, 0, 1.15), (-0.02, 0.02, 1.35)], [0.14, 0.07, 0.005], (1.0, 0.75, 0.3), ao=0)
    groups["urn"] = lp.take_parts()
    lp.tube([(-0.4, 0, 0.0), (0, 0.03, 0.02), (0.4, 0, 0.0)], [0.05, 0.07, 0.05], sand_dark, flat=0.25,
            flat_axis=(0, 0, 1), seg=6)
    lp.tube([(-0.2, 0.25, 0.0), (0.1, 0.27, 0.015), (0.4, 0.24, 0.0)], [0.04, 0.06, 0.04], sand_dark, flat=0.25,
            flat_axis=(0, 0, 1), seg=6)
    groups["d_ripple"] = lp.take_parts()
    for i in range(6):
        lp.tube([(0, 0, 0), (math.cos(i) * 0.08, math.sin(i) * 0.08, 0.12), (math.cos(i) * 0.16, math.sin(i) * 0.16, 0.2)],
                [0.012, 0.008, 0.002], (0.55, 0.45, 0.25), seg=4, ao=0.3)
    groups["d_bush"] = lp.take_parts()
    lp.ball((0, 0, 0.08), (0.1, 0.12, 0.09), BONE, subdiv=2)
    lp.box((0, 0.1, 0.03), (0.08, 0.06, 0.05), BONE, bevel=0.015)
    for x in (0.04, -0.04):
        lp.ball((x, 0.1, 0.09), (0.025, 0.015, 0.025), (0.15, 0.12, 0.1), subdiv=1, ao=0)
    groups["d_skull"] = lp.take_parts()
    return groups


def forest_kit():
    """幽暗森林零件：古树、暗松、倒木、苔石、发光巨菇、立石（地标石阵），以及地面装饰。"""
    bark = (0.28, 0.20, 0.15)
    leaf = (0.18, 0.34, 0.16)
    leaf_dark = (0.10, 0.22, 0.14)
    moss = (0.32, 0.45, 0.22)
    stone = (0.40, 0.42, 0.40)
    glow = (0.55, 1.0, 0.75)
    cap = (0.55, 0.25, 0.60)
    groups = {}
    # 古树：根部张开的扭曲树干 + 几根主枝 + 团状树冠
    lp.lathe((0, 0, 0), [(0.62, 0.0), (0.45, 0.25), (0.36, 0.8), (0.32, 1.8), (0.26, 2.8)], bark, wobble=0.18, seed=61, seg=16)
    for k in range(5):                                                               # 板根
        a = k * 2 * math.pi / 5 + 0.3
        lp.tube([(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.6), (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.15),
                 (math.cos(a) * 0.85, math.sin(a) * 0.85, 0.0)], [0.14, 0.1, 0.04], bark, seg=8)
    for k, (x, y, z) in enumerate(((0.9, 0.3, 3.1), (-0.8, -0.2, 3.2), (0.1, 0.8, 3.3), (-0.2, -0.7, 3.4))):
        lp.tube([(0, 0, 2.3), (x * 0.5, y * 0.5, z - 0.3), (x, y, z)], [0.18, 0.11, 0.06], bark, seg=8)
    for i, (x, y, z, s) in enumerate(((0, 0, 3.7, 1.5), (0.9, 0.3, 3.2, 1.1), (-0.85, -0.2, 3.3, 1.1),
                                      (0.1, 0.85, 3.4, 0.95), (-0.2, -0.75, 3.5, 0.9), (0.3, -0.1, 4.4, 0.9))):
        lp.rock((x, y, z), (s, s, s * 0.78), leaf if i % 2 == 0 else leaf_dark, seed=70 + i, jitter=0.2, flat_bottom=False, ao=0.35)
    groups["oak"] = lp.take_parts()
    # 暗松：多层下垂枝叶
    lp.tube([(0, 0, 0), (0, 0, 2.0), (0.02, 0, 4.8)], [0.24, 0.17, 0.03], bark, seg=10)
    for i, (z, r) in enumerate(((1.6, 1.2), (2.4, 1.0), (3.15, 0.8), (3.85, 0.58), (4.5, 0.36))):
        lp.lathe((0, 0, z), [(r, -0.12), (r * 0.9, 0.05), (r * 0.5, 0.55), (0.0, 1.05)], leaf_dark, wobble=0.15, seed=80 + i, seg=14)
    groups["dark_pine"] = lp.take_parts()
    # 倒木：空心断面 + 年轮 + 苔藓 + 蘑菇 + 断枝
    with lp.frame((0, 0, 0.4), (0, 90, 0)):
        lp.lathe((0, 0, -2.0), [(0.4, 0.0), (0.42, 1.0), (0.38, 2.6), (0.4, 4.0)], bark, wobble=0.12, seed=63, seg=14)
        for z in (-2.0, 2.0):
            lp.cyl((0, 0, z), 0.34, 0.02, (0.55, 0.4, 0.28), ao=0)                 # 断面年轮
            lp.cyl((0, 0, z), 0.14, 0.03, (0.1, 0.07, 0.05), ao=0)                 # 空心
    lp.rock((0.5, 0, 0.78), (1.0, 0.35, 0.1), moss, seed=64, jitter=0.15, flat_bottom=False)
    lp.tube([(-1.3, 0.2, 0.6), (-1.35, 0.4, 0.9), (-1.3, 0.5, 1.1)], [0.08, 0.05, 0.02], bark, seg=8)
    for k, x in enumerate((0.9, 1.1, -0.4)):
        lp.lathe((x, 0.38, 0.45 + k * 0.05), [(0.0, 0.0), (0.12, 0.02), (0.1, 0.05), (0.0, 0.06)], cap, rot=(90, 0, 0))  # 层孔菌
    groups["log"] = lp.take_parts()
    lp.rock((0, 0, 0.7), (1.0, 0.95, 0.75), stone, seed=61)
    lp.rock((0.1, 0.1, 1.2), (0.85, 0.75, 0.28), moss, seed=62, jitter=0.2, flat_bottom=False)
    lp.rock((0.85, -0.4, 0.2), (0.3, 0.3, 0.22), stone, seed=65)
    for k in range(5):
        a = k * 1.2
        lp.tube([(math.cos(a) * 0.7, math.sin(a) * 0.7, 1.05), (math.cos(a) * 0.95, math.sin(a) * 0.9, 0.7)],
                [0.05, 0.005], moss, seg=6)                                          # 垂苔
    groups["mossy_rock"] = lp.take_parts()
    # 发光巨菇
    lp.tube([(0, 0, 0), (0.05, 0, 0.8), (0, 0.04, 1.8)], [0.2, 0.14, 0.12], (0.85, 0.82, 0.72), seg=14)
    lp.lathe((0, 0, 1.05), [(0.13, 0.0), (0.24, 0.04), (0.2, 0.08), (0.13, 0.06)], (0.85, 0.82, 0.72))  # 菌环
    lp.lathe((0, 0, 1.68), [(0.1, 0.0), (0.72, 0.08), (0.75, 0.16), (0.62, 0.32), (0.32, 0.45), (0.0, 0.5)], cap, wobble=0.06, seed=66)
    lp.lathe((0, 0, 1.68), [(0.7, 0.08), (0.12, 0.02)], lp.shade(glow, 0.7), ao=0)  # 发光菌褶
    for i, (x, y) in enumerate(((0.3, 0.2), (-0.35, 0.1), (0.05, -0.4), (-0.1, 0.42), (0.42, -0.2))):
        z = 1.68 + 0.5 - (x * x + y * y) * 0.75
        lp.ball((x, y, z), (0.08, 0.08, 0.04), glow, ao=0)
    for k in range(3):
        a = k * 2.1
        lp.tube([(math.cos(a) * 0.35, math.sin(a) * 0.35, 0.0), (math.cos(a) * 0.36, math.sin(a) * 0.36, 0.3)], [0.07, 0.05], (0.85, 0.82, 0.72), seg=8)
        lp.lathe((math.cos(a) * 0.36, math.sin(a) * 0.36, 0.3), [(0.0, 0.0), (0.14, 0.02), (0.12, 0.08), (0.0, 0.12)], cap)  # 小菇
    groups["glowshroom"] = lp.take_parts()
    # 立石：粗糙石碑 + 发光符文 + 顶部苔藓
    lp.rock((0, 0, 1.5), (0.6, 0.4, 1.55), stone, seed=67, jitter=0.12)
    for k, z in enumerate((1.3, 1.7, 2.1)):
        lp.box((0, 0.36, z), (0.36 - k * 0.06, 0.04, 0.06), glow, bevel=0.012, ao=0)
    lp.box((0, 0.36, 1.7), (0.06, 0.04, 0.9), glow, bevel=0.012, ao=0)
    lp.rock((0, 0, 2.95), (0.48, 0.34, 0.15), moss, seed=68, jitter=0.15, flat_bottom=False)
    groups["standing_stone"] = lp.take_parts()
    for i in range(6):
        lp.blade((0, 0, 0.02), 0.38, 0.09, 0.008, leaf, rot=(-40, 0, i * 60), tip=0.5, seg=4, ao=0.35)
    groups["d_fern"] = lp.take_parts()
    lp.cyl((0, 0, 0.06), 0.02, 0.12, (0.85, 0.82, 0.72), verts=6)
    lp.lathe((0, 0, 0.11), [(0.0, 0.0), (0.07, 0.01), (0.06, 0.04), (0.0, 0.06)], glow, seg=10, ao=0)
    groups["d_mushroom"] = lp.take_parts()
    for k, (x, y, a, c) in enumerate(((0, 0, 20, (0.45, 0.30, 0.12)), (0.15, 0.08, -30, (0.55, 0.36, 0.14)),
                                      (-0.1, 0.12, 80, (0.5, 0.25, 0.1)))):
        lp.blade((x, y, 0.006), 0.14, 0.09, 0.006, c, rot=(0, 0, a), tip=0.45, seg=3, ao=0)
    groups["d_leaves"] = lp.take_parts()
    return groups
