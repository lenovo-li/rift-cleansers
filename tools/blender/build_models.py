"""生成游戏里的全部低模（铁卫、6 种敌人、Boss、石块），导出到 assets/models/*.glb。
用法（项目根目录）：
  blender --background --factory-startup --python tools/blender/build_models.py -- [--preview] [名字 ...]
--preview 额外渲染 tools/blender/previews/<名字>.png 用于检查造型。
风格：文档 05「低多边形 + 顶点色 + 夸张比例」，每个模型几百到一千多三角面。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly as lp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "models")
PREVIEW_DIR = os.path.join(ROOT, "tools", "blender", "previews")

# 共享调色板（sRGB）
STEEL = (0.62, 0.66, 0.72)
STEEL_DARK = (0.32, 0.35, 0.40)
GOLD = (0.95, 0.72, 0.25)
LEATHER = (0.36, 0.24, 0.16)
SKIN = (0.90, 0.72, 0.58)
BONE = (0.90, 0.87, 0.78)
ROT_GREEN = (0.45, 0.62, 0.30)
CLOTH_DARK = (0.22, 0.20, 0.24)
TEAM = (1.0, 1.0, 1.0)  # Team 材质：Godot 里换成槽位颜色
BLACK = (0.05, 0.05, 0.06)
RED_GLOW = (1.0, 0.15, 0.10)


def iron_guard():
    """铁卫：大塔盾 + 单手锤，宽肩、厚甲、队伍色披风和盾面。约 1.9 米。"""
    for x in (0.2, -0.2):
        lp.cyl((x, 0, 0.4), 0.13, 0.8, STEEL_DARK)          # 腿
        lp.box((x, 0.06, 0.07), (0.22, 0.32, 0.14), LEATHER)  # 靴
    lp.box((0, 0, 0.88), (0.56, 0.34, 0.22), LEATHER)       # 腰带
    lp.box((0, 0, 1.2), (0.66, 0.42, 0.55), STEEL)          # 胸甲
    lp.box((0, 0.22, 1.22), (0.3, 0.04, 0.3), TEAM, team=True)  # 胸前纹章
    lp.box((0, -0.24, 1.05), (0.6, 0.06, 0.95), TEAM, rot=(8, 0, 0), team=True)  # 披风
    for x in (0.44, -0.44):
        lp.ball((x, 0, 1.45), (0.2, 0.2, 0.15), GOLD)       # 肩甲
        lp.cyl((x, 0, 1.12), 0.09, 0.5, STEEL_DARK)         # 手臂
    lp.ball((0, 0.02, 1.68), (0.19, 0.19, 0.2), STEEL, subdiv=2)  # 头盔
    lp.box((0, 0.18, 1.66), (0.26, 0.04, 0.05), BLACK)      # 面罩缝
    lp.cone((0, 0, 1.92), 0.06, 0.18, GOLD)                 # 盔顶
    # 左手塔盾（朝前）
    lp.box((0.52, 0.3, 1.0), (0.12, 0.62, 0.95), STEEL, rot=(0, 0, 70))
    lp.box((0.55, 0.36, 1.0), (0.04, 0.44, 0.7), TEAM, rot=(0, 0, 70), team=True)
    lp.ball((0.58, 0.42, 1.02), (0.08, 0.08, 0.08), GOLD)
    # 右手战锤
    lp.cyl((-0.48, 0.22, 0.95), 0.035, 0.8, LEATHER, rot=(60, 0, 0))
    lp.box((-0.48, 0.55, 1.18), (0.2, 0.2, 0.3), STEEL_DARK, rot=(60, 0, 0))


def zombie():
    """腐尸：驼背、前伸双臂、破烂衣服。"""
    for x in (0.14, -0.14):
        lp.cyl((x, 0, 0.35), 0.09, 0.7, CLOTH_DARK)
    lp.box((0, 0.05, 0.95), (0.44, 0.3, 0.55), (0.35, 0.38, 0.28), rot=(20, 0, 0))
    lp.box((0.05, 0.12, 0.7), (0.4, 0.26, 0.12), (0.3, 0.26, 0.2))  # 破布
    lp.ball((0, 0.22, 1.32), (0.17, 0.17, 0.18), ROT_GREEN)
    for x in (0.08, -0.08):
        lp.ball((x, 0.36, 1.35), (0.035, 0.03, 0.035), (1.0, 0.9, 0.4))  # 眼
    for x in (0.26, -0.26):
        lp.cyl((x, 0.28, 1.08), 0.06, 0.55, ROT_GREEN, rot=(80, 0, 0))  # 前伸手臂


def skeleton():
    """骷髅兵：细骨架、肋骨、生锈短剑和小圆盾。"""
    for x in (0.12, -0.12):
        lp.cyl((x, 0, 0.38), 0.045, 0.76, BONE)
    lp.box((0, 0, 0.8), (0.3, 0.16, 0.1), BONE)                    # 骨盆
    lp.cyl((0, 0, 1.02), 0.04, 0.45, BONE)                         # 脊椎
    for i, z in enumerate((0.98, 1.08, 1.18)):
        lp.box((0, 0.02, z), (0.36 - i * 0.03, 0.2, 0.035), BONE)  # 肋骨
    for x in (0.22, -0.22):
        lp.cyl((x, 0.05, 1.05), 0.035, 0.5, BONE, rot=(15, 0, 0))
    lp.ball((0, 0.02, 1.42), (0.15, 0.16, 0.16), BONE, subdiv=2)
    for x in (0.06, -0.06):
        lp.ball((x, 0.14, 1.43), (0.04, 0.02, 0.04), BLACK)
    lp.box((-0.24, 0.3, 0.95), (0.05, 0.5, 0.08), (0.55, 0.35, 0.22), rot=(-30, 0, 0))  # 锈剑
    lp.cyl((0.28, 0.12, 1.02), 0.2, 0.05, (0.45, 0.3, 0.2), rot=(90, 0, 70), verts=10)   # 小盾


def imp():
    """爆裂小鬼：矮胖圆身、角、尖尾，身上发光裂纹（提示会爆炸）。"""
    lp.ball((0, 0, 0.55), (0.34, 0.3, 0.36), (0.85, 0.35, 0.1))
    lp.ball((0, 0.05, 0.62), (0.2, 0.28, 0.12), (1.0, 0.8, 0.2))   # 发光腹部
    for x in (0.14, -0.14):
        lp.cone((x, 0, 0.98), 0.07, 0.25, BLACK, rot=(0, x * 120, 0))  # 角
        lp.ball((x, 0.26, 0.72), (0.06, 0.03, 0.06), (1.0, 1.0, 0.6))  # 眼
        lp.cyl((x, 0, 0.16), 0.06, 0.3, (0.6, 0.25, 0.08))            # 短腿
    lp.cone((0, -0.4, 0.45), 0.06, 0.4, BLACK, rot=(-70, 0, 0))    # 尾巴


def ghoul():
    """吐酸食尸鬼：四肢着地、大下颚、背上酸囊。"""
    lp.box((0, 0, 0.62), (0.44, 0.8, 0.34), (0.25, 0.5, 0.42), rot=(-10, 0, 0))
    lp.ball((0, -0.08, 0.9), (0.26, 0.3, 0.2), (0.5, 0.95, 0.35))  # 酸囊
    lp.ball((0, 0.5, 0.78), (0.2, 0.22, 0.18), (0.3, 0.6, 0.5))    # 头
    lp.box((0, 0.62, 0.66), (0.26, 0.2, 0.08), (0.2, 0.35, 0.3))   # 下颚
    for x, y in ((0.22, 0.3), (-0.22, 0.3), (0.22, -0.3), (-0.22, -0.3)):
        lp.cyl((x, y, 0.25), 0.06, 0.5, (0.2, 0.4, 0.34), rot=(0, x * 60, 0))


def necromancer():
    """死灵法师：长袍、兜帽、发光法杖。"""
    lp.cyl((0, 0, 0.6), 0.42, 1.2, (0.3, 0.14, 0.4), radius2=0.2, verts=10)  # 长袍
    lp.cone((0, -0.02, 1.52), 0.24, 0.5, (0.25, 0.1, 0.35), verts=8)          # 兜帽
    lp.ball((0, 0.1, 1.38), (0.12, 0.08, 0.1), BLACK)                         # 兜帽阴影
    for x in (0.05, -0.05):
        lp.ball((x, 0.17, 1.4), (0.025, 0.02, 0.025), (0.7, 1.0, 0.4))
    lp.cyl((0.36, 0.1, 0.85), 0.03, 1.7, LEATHER)                             # 法杖
    lp.ball((0.36, 0.1, 1.75), (0.1, 0.1, 0.1), (0.75, 0.4, 1.0), subdiv=2)   # 法球


def bloater():
    """膨胀怪：巨大肚子、小脑袋、脓包。"""
    lp.ball((0, 0, 0.75), (0.6, 0.55, 0.62), (0.62, 0.6, 0.25), subdiv=2)
    for x, z in ((0.35, 1.0), (-0.3, 0.6), (0.1, 0.4), (-0.4, 1.05)):
        lp.ball((x, 0.45, z), (0.1, 0.08, 0.1), (0.85, 0.9, 0.35))   # 脓包
    lp.ball((0, 0.15, 1.45), (0.16, 0.16, 0.15), (0.5, 0.48, 0.2))
    for x in (0.22, -0.22):
        lp.cyl((x, 0, 0.12), 0.1, 0.24, (0.4, 0.38, 0.15))


def corrupted_knight():
    """腐化骑士（Boss）：尖刺黑甲、巨剑、发红光的眼缝和胸口。以 1 米高度建模，Godot 按 body_scale 放大。"""
    s = 0.55  # 整体按铁卫比例缩小到约 1.1 米，放大 2.5 倍后约 2.7 米
    dark = (0.18, 0.1, 0.12)
    for x in (0.22, -0.22):
        lp.cyl((x * s, 0, 0.42 * s), 0.15 * s, 0.84 * s, dark)
    lp.box((0, 0, 1.25 * s), (0.8 * s, 0.5 * s, 0.7 * s), dark)
    lp.ball((0, 0.24 * s, 1.3 * s), (0.12 * s, 0.05 * s, 0.12 * s), RED_GLOW)  # 胸口裂光
    for x in (0.55, -0.55):
        lp.ball((x * s, 0, 1.55 * s), (0.26 * s, 0.26 * s, 0.2 * s), dark)
        lp.cone((x * s, 0, 1.8 * s), 0.1 * s, 0.4 * s, (0.5, 0.1, 0.12))       # 肩刺
    lp.box((0, 0.02, 1.85 * s), (0.34 * s, 0.34 * s, 0.36 * s), dark)          # 头盔
    lp.box((0, 0.18 * s, 1.86 * s), (0.26 * s, 0.03 * s, 0.05 * s), RED_GLOW)  # 眼缝
    for x in (0.13, -0.13):
        lp.cone((x * s, 0, 2.12 * s), 0.05 * s, 0.3 * s, dark, rot=(0, x * 150, 0))  # 角
    lp.box((-0.6 * s, 0.5 * s, 1.1 * s), (0.1 * s, 1.5 * s, 0.22 * s), (0.4, 0.38, 0.42), rot=(-20, 0, 0))  # 巨剑
    lp.box((-0.6 * s, 0.05 * s, 1.18 * s), (0.4 * s, 0.1 * s, 0.1 * s), (0.5, 0.1, 0.12))                    # 护手


def frost_lich():
    """霜冻巫妖（Boss）：漂浮的破烂长袍、骷髅头冰冠、冰晶法杖、下摆冰雾。约 1.1 米，放大 2.5 倍。"""
    s = 0.55
    robe = (0.2, 0.26, 0.38)
    ice = (0.55, 0.85, 1.0)
    lp.cyl((0, 0, 0.75 * s), 0.45 * s, 1.2 * s, robe, radius2=0.25 * s, verts=8)   # 长袍（下摆离地）
    lp.cone((0, 0, 0.12 * s), 0.35 * s, 0.3 * s, ice, rot=(180, 0, 0), verts=6)    # 冰雾尖
    lp.box((0, 0, 1.45 * s), (0.7 * s, 0.4 * s, 0.35 * s), robe)                     # 肩
    lp.ball((0, 0.02, 1.78 * s), (0.2 * s, 0.2 * s, 0.22 * s), BONE)                 # 骷髅头
    lp.box((0, 0.18 * s, 1.78 * s), (0.2 * s, 0.03 * s, 0.05 * s), (0.4, 0.9, 1.0))  # 眼光
    for i, x in enumerate((-0.16, -0.05, 0.05, 0.16)):
        lp.cone((x * s, 0, 2.05 * s), 0.05 * s, (0.35 if i in (1, 2) else 0.25) * s, ice, verts=4)  # 冰冠
    for x in (0.4, -0.4):
        lp.cyl((x * s, 0.1 * s, 1.25 * s), 0.08 * s, 0.6 * s, robe, rot=(25, 0, 0))
        lp.ball((x * s, 0.22 * s, 1.0 * s), (0.07 * s, 0.07 * s, 0.07 * s), BONE)
    lp.cyl((-0.45 * s, 0.25 * s, 1.2 * s), 0.035 * s, 2.0 * s, (0.3, 0.3, 0.35))   # 法杖
    lp.cone((-0.45 * s, 0.25 * s, 2.3 * s), 0.12 * s, 0.4 * s, ice, verts=5)


def sand_colossus():
    """沙之巨像（Boss）：砂岩方块身躯、金色面具、巨大石拳，裂缝透出橙光。约 1.1 米，放大 2.5 倍。"""
    s = 0.55
    sand = (0.78, 0.62, 0.4)
    dark = (0.55, 0.4, 0.26)
    glow = (1.0, 0.6, 0.15)
    for x in (0.28, -0.28):
        lp.box((x * s, 0, 0.4 * s), (0.34 * s, 0.4 * s, 0.8 * s), dark)             # 柱腿
    lp.box((0, 0, 1.25 * s), (1.0 * s, 0.6 * s, 0.9 * s), sand)                      # 身躯
    lp.box((0, 0.31 * s, 1.25 * s), (0.08 * s, 0.02 * s, 0.6 * s), glow)             # 裂缝
    lp.box((0, 0, 1.9 * s), (0.45 * s, 0.4 * s, 0.4 * s), dark)                      # 头
    lp.box((0, 0.21 * s, 1.9 * s), (0.36 * s, 0.03 * s, 0.3 * s), GOLD)              # 金面具
    lp.box((0, 0.23 * s, 1.93 * s), (0.24 * s, 0.02 * s, 0.05 * s), glow)            # 眼光
    for x in (0.7, -0.7):
        lp.box((x * s, 0, 1.4 * s), (0.3 * s, 0.35 * s, 0.6 * s), dark)             # 上臂
        lp.box((x * s, 0.1 * s, 0.85 * s), (0.5 * s, 0.5 * s, 0.5 * s), sand)       # 石拳


def rotwood_treant():
    """腐木树人（Boss）：扭曲树干身躯、苔藓肩、枝杈头冠、发绿光的眼和腐菌。约 1.1 米，放大 2.5 倍。"""
    s = 0.55
    bark = (0.3, 0.22, 0.15)
    moss = (0.3, 0.45, 0.2)
    glow = (0.5, 1.0, 0.5)
    for x in (0.25, -0.25):
        lp.cyl((x * s, 0, 0.35 * s), 0.16 * s, 0.7 * s, bark, rot=(0, x * 40, 0), verts=6)  # 根腿
    lp.cyl((0, 0, 1.2 * s), 0.42 * s, 1.1 * s, bark, radius2=0.32 * s, verts=7)      # 树干
    lp.ball((0, 0.3 * s, 1.35 * s), (0.2 * s, 0.1 * s, 0.25 * s), (0.2, 0.14, 0.1))  # 树洞
    for x in (0.12, -0.12):
        lp.ball((x * s, 0.32 * s, 1.55 * s), (0.05 * s, 0.03 * s, 0.05 * s), glow)   # 眼
    for x in (0.5, -0.5):
        lp.ball((x * s, 0, 1.7 * s), (0.28 * s, 0.25 * s, 0.18 * s), moss)          # 苔藓肩
        lp.cyl((x * 1.3 * s, 0.1 * s, 1.25 * s), 0.1 * s, 0.8 * s, bark, rot=(20, x * 60, 0), verts=5)  # 枝臂
    for i, (x, r) in enumerate(((0, 0), (0.2, 30), (-0.2, -30), (0.1, 15))):
        lp.cyl((x * s, 0, 2.0 * s), 0.05 * s, 0.6 * s, bark, rot=(0, r, i * 20), verts=4)  # 枝冠
    lp.ball((0.3 * s, 0.25 * s, 1.0 * s), (0.1 * s, 0.1 * s, 0.06 * s), (0.6, 0.3, 0.65))  # 腐菌


def rocks():
    """障碍物石堆：3 块不规则石头，以 1 米为单位，Godot 按障碍物尺寸缩放。"""
    grey = (0.46, 0.43, 0.40)
    lp.rock((0, 0, 0.45), (0.55, 0.45, 0.5), grey, seed=1)
    lp.rock((0.35, 0.25, 0.3), (0.3, 0.28, 0.32), (0.5, 0.47, 0.43), seed=2)
    lp.rock((-0.3, -0.2, 0.25), (0.28, 0.3, 0.26), (0.4, 0.38, 0.35), seed=3)


def decor():
    """地面散布装饰（Godot 用 MultiMesh 随机撒在场地上）：碎石、枯草、骨头、焦土裂缝。"""
    groups = {}
    lp.rock((0, 0, 0.06), (0.14, 0.12, 0.08), (0.42, 0.4, 0.37), seed=11, jitter=0.35)
    lp.rock((0.2, 0.1, 0.04), (0.08, 0.07, 0.05), (0.36, 0.34, 0.31), seed=12, jitter=0.35)
    groups["pebbles"] = lp.take_parts()
    for i, (x, y, r) in enumerate(((0, 0, 0), (0.06, 0.03, 40), (-0.05, 0.04, -35), (0.02, -0.06, 15))):
        lp.cone((x, y, 0.12), 0.03, 0.26, (0.55, 0.5, 0.28), rot=(r * 0.5, r * 0.3, i * 60), verts=4)
    groups["grass"] = lp.take_parts()
    lp.cyl((0, 0, 0.03), 0.025, 0.35, BONE, rot=(0, 90, 20))
    lp.ball((0.17, 0.06, 0.04), (0.045, 0.045, 0.04), BONE)
    lp.ball((0.17, -0.02, 0.04), (0.045, 0.045, 0.04), BONE)
    groups["bones"] = lp.take_parts()
    lp.box((0, 0, 0.005), (0.9, 0.06, 0.01), (0.22, 0.2, 0.19), rot=(0, 0, 10))
    lp.box((0.3, 0.12, 0.005), (0.4, 0.05, 0.01), (0.22, 0.2, 0.19), rot=(0, 0, 55))
    groups["crack"] = lp.take_parts()
    lp.export_separate(os.path.join(OUT_DIR, "decor.glb"), groups)


def city_kit():
    """灰烬王城模块化零件：每个零件以地面中心为原点，分别导出为 ashen_city.glb 里的独立网格。
    Godot 侧 AshenCity 按固定种子摆放（主机和客户端布局一致，无需同步）。"""
    stone = (0.42, 0.40, 0.38)
    stone_dark = (0.28, 0.26, 0.25)
    char = (0.14, 0.12, 0.12)
    ember = (1.0, 0.45, 0.12)
    royal = (0.38, 0.16, 0.42)
    groups = {}
    # 城墙段：长 6 米、高 2.6 米、厚 0.8 米，顶部残缺
    lp.box((0, 0, 0.9), (6.0, 0.8, 1.8), stone)
    for x, h in ((-2.4, 0.8), (-1.2, 0.5), (0.3, 0.9), (1.6, 0.35), (2.5, 0.7)):
        lp.box((x, 0, 1.8 + h / 2), (1.1, 0.8, h), stone if h > 0.5 else stone_dark)
    lp.box((0, 0.42, 0.15), (6.1, 0.1, 0.3), char)  # 墙根焦痕
    lp.box((0.3, 0.44, 1.5), (0.9, 0.04, 1.4), royal)  # 残破王旗
    groups["wall"] = lp.take_parts()
    # 断墙：半截 + 倒塌碎块
    lp.box((0, 0, 0.6), (3.2, 0.8, 1.2), stone_dark)
    lp.box((-0.9, 0, 1.4), (1.2, 0.8, 0.4), stone)
    lp.rock((2.2, 0.4, 0.3), (0.6, 0.5, 0.35), stone, seed=21)
    lp.rock((2.7, -0.5, 0.2), (0.4, 0.35, 0.25), stone_dark, seed=22)
    groups["wall_broken"] = lp.take_parts()
    # 石柱：底座 + 八棱柱身 + 柱头
    lp.box((0, 0, 0.2), (1.1, 1.1, 0.4), stone_dark)
    lp.cyl((0, 0, 1.9), 0.38, 3.0, stone, verts=8)
    lp.box((0, 0, 3.55), (1.0, 1.0, 0.3), stone_dark)
    groups["pillar"] = lp.take_parts()
    # 断柱
    lp.box((0, 0, 0.2), (1.1, 1.1, 0.4), stone_dark)
    lp.cyl((0, 0, 0.95), 0.38, 1.1, stone, verts=8)
    lp.cyl((1.3, 0.2, 0.38), 0.36, 1.6, stone, rot=(0, 90, 25), verts=8)
    groups["pillar_broken"] = lp.take_parts()
    # 残塔：直径 4.4 米，高低不齐的垛口
    lp.cyl((0, 0, 2.2), 2.2, 4.4, stone_dark, verts=12)
    for i in range(6):
        import math
        a = i * math.pi / 3
        h = 0.6 + (i % 3) * 0.4
        lp.box((math.cos(a) * 1.9, math.sin(a) * 1.9, 4.4 + h / 2), (1.0, 0.7, h), stone, rot=(0, 0, math.degrees(a)))
    lp.box((0, 2.15, 0.9), (1.1, 0.2, 1.8), char)  # 门洞
    groups["tower"] = lp.take_parts()
    # 火盆：石座 + 铁盆 + 余烬
    lp.cyl((0, 0, 0.35), 0.35, 0.7, stone_dark, verts=6)
    lp.cyl((0, 0, 0.85), 0.55, 0.3, char, radius2=0.7, verts=8)
    lp.ball((0, 0, 1.02), (0.45, 0.45, 0.18), ember)
    groups["brazier"] = lp.take_parts()
    # 无头王像：台座 + 披风身躯 + 断剑
    lp.box((0, 0, 0.6), (2.6, 2.6, 1.2), stone_dark)
    lp.box((0, 0, 1.35), (2.2, 2.2, 0.3), stone)
    lp.cyl((0, 0, 2.7), 0.8, 2.4, stone, radius2=0.5, verts=8)
    for x in (0.7, -0.7):
        lp.ball((x, 0, 3.9), (0.35, 0.3, 0.25), stone)
    lp.cyl((0, 0, 4.0), 0.3, 0.3, char, verts=8)  # 断颈焦痕
    lp.box((0.2, 0.9, 2.6), (0.15, 0.1, 2.2), stone_dark, rot=(0, 15, 0))  # 断剑
    groups["statue"] = lp.take_parts()
    # 瓦砾堆
    for i, (x, y, sz) in enumerate(((0, 0, 0.7), (0.8, 0.3, 0.45), (-0.6, 0.5, 0.4), (0.2, -0.7, 0.5))):
        lp.rock((x, y, sz * 0.5), (sz, sz * 0.9, sz * 0.6), stone if i % 2 else stone_dark, seed=30 + i)
    lp.box((0.4, -0.2, 0.15), (1.2, 0.3, 0.2), char, rot=(0, 0, 30))  # 焦木
    groups["rubble"] = lp.take_parts()
    lp.export_separate(os.path.join(OUT_DIR, "ashen_city.glb"), groups)


def frost_kit():
    """霜冻冰原零件：冰刺、雪松、雪岩、冰墙、发光冰晶、冰图腾（地标），以及地面装饰。"""
    import math
    ice = (0.62, 0.82, 0.95)
    ice_dark = (0.35, 0.55, 0.75)
    snow = (0.92, 0.95, 0.98)
    rock = (0.40, 0.44, 0.50)
    pine = (0.16, 0.30, 0.28)
    bark = (0.30, 0.22, 0.18)
    glow = (0.45, 0.85, 1.0)
    groups = {}
    for i, (x, y, h, r) in enumerate(((0, 0, 3.6, 0.45), (0.5, 0.3, 2.4, 0.35), (-0.45, 0.25, 2.0, 0.3), (0.1, -0.5, 1.6, 0.28))):
        lp.cone((x, y, h / 2), r, h, ice if i % 2 == 0 else ice_dark, rot=(i * 6 - 8, i * 5, i * 40), verts=5)
    groups["ice_spire"] = lp.take_parts()
    lp.cyl((0, 0, 0.6), 0.2, 1.2, bark, verts=6)
    for i, (z, r) in enumerate(((1.4, 1.2), (2.4, 0.95), (3.3, 0.7), (4.1, 0.45))):
        lp.cone((0, 0, z), r, 1.2, pine, verts=7)
        lp.cone((0, 0, z + 0.2), r * 0.8, 0.7, snow, verts=7)
    groups["pine"] = lp.take_parts()
    lp.rock((0, 0, 0.6), (1.1, 1.0, 0.7), rock, seed=41)
    lp.rock((0.2, 0.1, 1.05), (0.85, 0.75, 0.25), snow, seed=42, jitter=0.15)
    groups["ice_rock"] = lp.take_parts()
    lp.box((0, 0, 0.9), (6.0, 0.9, 1.8), ice_dark)
    for x, h in ((-2.2, 0.7), (-0.6, 0.4), (1.0, 0.8), (2.4, 0.5)):
        lp.box((x, 0, 1.8 + h / 2), (1.2, 0.9, h), ice)
    lp.box((0, 0, 1.85), (6.0, 1.0, 0.12), snow)
    groups["frozen_wall"] = lp.take_parts()
    lp.cone((0, 0, 0.8), 0.3, 1.6, glow, verts=5)
    lp.cone((0.25, 0.1, 0.5), 0.18, 1.0, glow, rot=(0, 20, 30), verts=5)
    lp.rock((0, 0, 0.1), (0.5, 0.5, 0.2), rock, seed=43)
    groups["crystal"] = lp.take_parts()
    lp.box((0, 0, 0.4), (2.0, 2.0, 0.8), rock)
    lp.cyl((0, 0, 2.3), 0.55, 3.0, ice_dark, verts=6)
    for i in range(4):
        a = i * math.pi / 2
        lp.cone((math.cos(a) * 0.6, math.sin(a) * 0.6, 3.6), 0.2, 1.0, ice, rot=(math.degrees(math.sin(a)) * 0.5, -math.degrees(math.cos(a)) * 0.5, 0), verts=4)
    lp.ball((0, 0, 4.1), (0.35, 0.35, 0.35), glow)
    groups["totem"] = lp.take_parts()
    lp.ball((0, 0, 0.03), (0.3, 0.25, 0.06), snow)
    lp.ball((0.25, 0.1, 0.02), (0.18, 0.14, 0.04), snow)
    groups["d_snow"] = lp.take_parts()
    lp.cone((0, 0, 0.12), 0.05, 0.25, ice, rot=(15, 0, 0), verts=4)
    lp.cone((0.08, 0.05, 0.08), 0.04, 0.16, ice_dark, rot=(-20, 10, 0), verts=4)
    groups["d_shard"] = lp.take_parts()
    lp.rock((0, 0, 0.05), (0.12, 0.1, 0.07), rock, seed=44, jitter=0.35)
    groups["d_pebble"] = lp.take_parts()
    lp.export_separate(os.path.join(OUT_DIR, "frost_wastes.glb"), groups)


def desert_kit():
    """沙海遗迹零件：砂岩墙、方尖碑（地标）、砂岩柱、仙人掌、台地岩、火盆瓮，以及地面装饰。"""
    sand = (0.85, 0.70, 0.46)
    sand_dark = (0.66, 0.50, 0.32)
    red_rock = (0.68, 0.38, 0.24)
    cactus = (0.30, 0.52, 0.26)
    ember = (1.0, 0.55, 0.15)
    gold = GOLD
    groups = {}
    lp.box((0, 0, 1.0), (6.0, 0.8, 2.0), sand)
    for x, h in ((-2.3, 0.4), (-0.9, 0.7), (0.8, 0.3), (2.2, 0.6)):
        lp.box((x, 0, 2.0 + h / 2), (1.3, 0.8, h), sand_dark)
    lp.box((0, 0.42, 1.2), (1.2, 0.04, 0.6), (0.3, 0.45, 0.6))  # 褪色壁画
    groups["sand_wall"] = lp.take_parts()
    lp.box((0, 0, 0.3), (2.2, 2.2, 0.6), sand_dark)
    lp.cyl((0, 0, 3.3), 0.7, 5.4, sand, radius2=0.45, verts=4, rot=(0, 0, 45))
    lp.cone((0, 0, 6.3), 0.45, 0.6, gold, verts=4, rot=(0, 0, 45))
    groups["obelisk"] = lp.take_parts()
    lp.box((0, 0, 0.2), (1.0, 1.0, 0.4), sand_dark)
    lp.cyl((0, 0, 1.9), 0.34, 3.0, sand, verts=6)
    lp.box((0, 0, 3.5), (0.9, 0.9, 0.25), sand_dark)
    groups["sand_pillar"] = lp.take_parts()
    lp.cyl((0, 0, 1.1), 0.28, 2.2, cactus, verts=6)
    lp.cyl((0.4, 0, 1.3), 0.14, 0.7, cactus, verts=6)
    lp.cyl((0.55, 0, 1.75), 0.14, 0.6, cactus, verts=6)
    lp.cyl((-0.38, 0, 1.0), 0.13, 0.5, cactus, verts=6)
    lp.cyl((-0.5, 0, 1.35), 0.13, 0.5, cactus, verts=6)
    groups["cactus"] = lp.take_parts()
    lp.rock((0, 0, 1.0), (1.5, 1.3, 1.0), red_rock, seed=51, jitter=0.18)
    lp.box((0, 0, 1.95), (2.2, 1.9, 0.2), sand_dark)
    groups["mesa_rock"] = lp.take_parts()
    lp.cyl((0, 0, 0.45), 0.35, 0.9, red_rock, radius2=0.25, verts=8)
    lp.ball((0, 0, 0.95), (0.3, 0.3, 0.15), ember)
    groups["urn"] = lp.take_parts()
    lp.box((0, 0, 0.01), (0.8, 0.08, 0.02), sand_dark, rot=(0, 0, 5))
    lp.box((0.1, 0.25, 0.01), (0.6, 0.07, 0.02), sand_dark, rot=(0, 0, -5))
    groups["d_ripple"] = lp.take_parts()
    for i in range(5):
        lp.cone((0, 0, 0.12), 0.03, 0.28, (0.55, 0.45, 0.25), rot=(30, 0, i * 72), verts=3)
    groups["d_bush"] = lp.take_parts()
    lp.ball((0, 0, 0.08), (0.1, 0.12, 0.09), BONE)
    lp.box((0, 0.1, 0.03), (0.08, 0.06, 0.05), BONE)
    groups["d_skull"] = lp.take_parts()
    lp.export_separate(os.path.join(OUT_DIR, "sand_ruins.glb"), groups)


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
    lp.cyl((0, 0, 1.4), 0.4, 2.8, bark, radius2=0.28, verts=7)
    for i, (x, y, z, s) in enumerate(((0, 0, 3.6, 1.8), (0.9, 0.3, 3.1, 1.2), (-0.8, -0.2, 3.2, 1.2), (0.1, 0.8, 3.3, 1.0))):
        lp.ball((x, y, z), (s, s, s * 0.8), leaf if i % 2 == 0 else leaf_dark)
    groups["oak"] = lp.take_parts()
    lp.cyl((0, 0, 0.8), 0.22, 1.6, bark, verts=6)
    for z, r in ((1.8, 1.1), (2.8, 0.85), (3.7, 0.6), (4.5, 0.35)):
        lp.cone((0, 0, z), r, 1.3, leaf_dark, verts=7)
    groups["dark_pine"] = lp.take_parts()
    lp.cyl((0, 0, 0.4), 0.4, 4.0, bark, rot=(0, 90, 0), verts=7)
    lp.box((0.5, 0, 0.8), (1.4, 0.7, 0.08), moss)
    lp.cyl((-1.3, 0.3, 0.55), 0.08, 0.7, bark, rot=(30, 0, 0), verts=5)
    groups["log"] = lp.take_parts()
    lp.rock((0, 0, 0.7), (1.0, 0.95, 0.75), stone, seed=61)
    lp.rock((0.1, 0.1, 1.25), (0.8, 0.7, 0.25), moss, seed=62, jitter=0.2)
    groups["mossy_rock"] = lp.take_parts()
    lp.cyl((0, 0, 0.9), 0.14, 1.8, (0.85, 0.82, 0.72), verts=6)
    lp.ball((0, 0, 1.9), (0.7, 0.7, 0.35), cap)
    for i, (x, y) in enumerate(((0.3, 0.2), (-0.35, 0.1), (0.05, -0.4))):
        lp.ball((x, y, 2.1), (0.1, 0.1, 0.06), glow)
    groups["glowshroom"] = lp.take_parts()
    lp.box((0, 0, 1.5), (1.2, 0.8, 3.0), stone, rot=(0, 4, 0))
    lp.box((0, 0.41, 1.8), (0.5, 0.02, 0.8), glow)  # 发光符文
    lp.box((0, 0, 3.1), (1.0, 0.7, 0.2), moss)
    groups["standing_stone"] = lp.take_parts()
    for i in range(5):
        lp.box((0, 0, 0.1), (0.05, 0.4, 0.02), leaf, rot=(40, 0, i * 72))
    groups["d_fern"] = lp.take_parts()
    lp.cyl((0, 0, 0.06), 0.02, 0.12, (0.85, 0.82, 0.72), verts=4)
    lp.ball((0, 0, 0.13), (0.07, 0.07, 0.04), glow)
    groups["d_mushroom"] = lp.take_parts()
    lp.box((0, 0, 0.005), (0.14, 0.1, 0.01), (0.45, 0.30, 0.12), rot=(0, 0, 20))
    lp.box((0.15, 0.08, 0.005), (0.12, 0.09, 0.01), (0.55, 0.36, 0.14), rot=(0, 0, -30))
    groups["d_leaves"] = lp.take_parts()
    lp.export_separate(os.path.join(OUT_DIR, "dark_forest.glb"), groups)


def elementalist():
    """元素术士：长袍 + 宽檐尖帽 + 法杖三色宝珠（火/冰/雷）。袍子下摆和帽带用队伍色。约 1.9 米。"""
    robe = (0.28, 0.24, 0.36)
    lp.cyl((0, 0, 0.55), 0.42, 1.1, robe, radius2=0.24, verts=10)          # 长袍下摆
    lp.cyl((0, 0, 0.06), 0.44, 0.12, TEAM, verts=10, team=True)           # 下摆队伍色镶边
    lp.box((0, 0, 1.25), (0.46, 0.3, 0.45), robe)                          # 上身
    lp.box((0, 0.16, 1.28), (0.12, 0.04, 0.4), GOLD)                       # 前襟金线
    for x in (0.3, -0.3):
        lp.cyl((x, 0.05, 1.2), 0.08, 0.5, robe, rot=(20, 0, 0))            # 袖子
        lp.ball((x, 0.14, 0.97), (0.06, 0.06, 0.06), SKIN)                 # 手
    lp.ball((0, 0.02, 1.62), (0.14, 0.14, 0.15), SKIN)                     # 头
    lp.box((0, 0.13, 1.55), (0.14, 0.05, 0.12), (0.85, 0.85, 0.88))        # 胡子
    lp.cyl((0, 0, 1.76), 0.34, 0.05, CLOTH_DARK, verts=12)                 # 帽檐
    lp.cyl((0, 0, 1.8), 0.19, 0.06, TEAM, verts=12, team=True)             # 帽带
    lp.cone((0.04, -0.02, 2.05), 0.18, 0.5, CLOTH_DARK, rot=(-12, 8, 0), verts=8)  # 尖帽
    # 法杖（右手）+ 三色宝珠
    lp.cyl((-0.36, 0.2, 1.0), 0.03, 1.8, LEATHER)
    lp.ball((-0.36, 0.2, 1.95), (0.1, 0.1, 0.1), (1.0, 0.45, 0.1), subdiv=2)
    lp.ball((-0.28, 0.2, 1.85), (0.06, 0.06, 0.06), (0.5, 0.85, 1.0))
    lp.ball((-0.44, 0.2, 1.85), (0.06, 0.06, 0.06), (0.75, 0.7, 1.0))


def shadow_walker():
    """影行者：兜帽斗篷、面巾、双持短刃，身形瘦长前倾。围巾和腰带用队伍色。约 1.8 米。"""
    cloak = (0.16, 0.14, 0.2)
    for x in (0.14, -0.14):
        lp.cyl((x, 0, 0.42), 0.09, 0.84, CLOTH_DARK)                     # 细腿
        lp.box((x, 0.05, 0.06), (0.16, 0.28, 0.12), BLACK)               # 软靴
    lp.box((0, 0, 0.9), (0.4, 0.26, 0.12), TEAM, team=True)             # 腰带
    lp.box((0, 0.02, 1.18), (0.44, 0.28, 0.5), cloak, rot=(-8, 0, 0))   # 上身
    lp.cyl((0, -0.12, 0.95), 0.34, 0.9, cloak, radius2=0.18, verts=8)   # 斗篷下摆
    lp.box((0, 0.12, 1.46), (0.34, 0.2, 0.08), TEAM, team=True)         # 围巾
    lp.ball((0, 0.04, 1.6), (0.15, 0.15, 0.17), SKIN)                    # 头
    lp.box((0, 0.15, 1.56), (0.22, 0.04, 0.08), BLACK)                   # 面巾
    lp.cone((0, -0.02, 1.72), 0.21, 0.42, cloak, rot=(-15, 0, 0), verts=8)  # 兜帽
    for x, s in ((0.3, 1), (-0.3, -1)):
        lp.cyl((x, 0.1, 1.15), 0.06, 0.46, cloak, rot=(35, 0, 0))        # 手臂前伸
        lp.ball((x, 0.28, 0.98), (0.05, 0.05, 0.05), SKIN)
        lp.box((x, 0.5, 0.92), (0.04, 0.44, 0.07), STEEL, rot=(-20, 0, s * 10))  # 短刃
        lp.box((x, 0.3, 0.97), (0.1, 0.04, 0.04), GOLD)                   # 护手


def cleric():
    """牧师：白金长袍、圣徽、法冠与发光圣锤。披肩和圣徽底色用队伍色。约 1.9 米。"""
    robe = (0.9, 0.88, 0.8)
    lp.cyl((0, 0, 0.55), 0.4, 1.1, robe, radius2=0.26, verts=10)        # 长袍
    lp.cyl((0, 0, 0.08), 0.42, 0.14, GOLD, verts=10)                     # 金边下摆
    lp.box((0, 0, 1.25), (0.5, 0.32, 0.45), robe)                        # 上身
    lp.box((0, 0, 1.46), (0.62, 0.36, 0.1), TEAM, team=True)            # 披肩
    lp.box((0, 0.17, 1.24), (0.16, 0.04, 0.2), TEAM, team=True)         # 圣徽底
    lp.box((0, 0.2, 1.24), (0.04, 0.02, 0.16), GOLD)                     # 圣徽竖
    lp.box((0, 0.2, 1.28), (0.12, 0.02, 0.04), GOLD)                     # 圣徽横
    for x in (0.32, -0.32):
        lp.cyl((x, 0.04, 1.15), 0.09, 0.5, robe, rot=(15, 0, 0))         # 袖子
        lp.ball((x, 0.12, 0.92), (0.06, 0.06, 0.06), SKIN)
    lp.ball((0, 0.02, 1.64), (0.15, 0.15, 0.16), SKIN)                   # 头
    lp.cyl((0, 0, 1.84), 0.13, 0.22, robe, radius2=0.08, verts=8)        # 法冠
    lp.box((0, 0.1, 1.86), (0.04, 0.02, 0.14), GOLD)
    # 右手圣锤（锤头发光金色）
    lp.cyl((-0.36, 0.2, 0.95), 0.03, 1.1, LEATHER)
    lp.box((-0.36, 0.2, 1.52), (0.26, 0.16, 0.16), GOLD)
    lp.ball((-0.36, 0.2, 1.52), (0.1, 0.1, 0.1), (1.0, 0.95, 0.6))


MODELS = {
    "iron_guard": (iron_guard, 2.0), "elementalist": (elementalist, 2.0),
    "shadow_walker": (shadow_walker, 2.0), "cleric": (cleric, 2.0), "zombie": (zombie, 1.6), "skeleton": (skeleton, 1.6),
    "imp": (imp, 1.2), "ghoul": (ghoul, 1.2), "necromancer": (necromancer, 1.8),
    "bloater": (bloater, 1.6), "corrupted_knight": (corrupted_knight, 1.3), "rocks": (rocks, 1.0),
    "frost_lich": (frost_lich, 1.3), "sand_colossus": (sand_colossus, 1.3), "rotwood_treant": (rotwood_treant, 1.3),
    "decor": (decor, 0.5),
    "ashen_city": (city_kit, 4.0),
    "frost_wastes": (frost_kit, 4.0), "sand_ruins": (desert_kit, 4.0), "dark_forest": (forest_kit, 4.0),
}
KITS = ("decor", "ashen_city", "frost_wastes", "sand_ruins", "dark_forest")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = "--preview" in argv
    names = [a for a in argv if not a.startswith("--")] or list(MODELS)
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for name in names:
        fn, height = MODELS[name]
        lp.reset_scene()
        fn()
        if name in KITS:
            print("[models] %s: multi-mesh kit" % name)
            continue
        tris = lp.export(os.path.join(OUT_DIR, name + ".glb"))
        print("[models] %s: %d tris" % (name, tris))
        if preview:
            lp.render_preview(os.path.join(PREVIEW_DIR, name + ".png"), distance=height * 2.4, height=height)


main()
