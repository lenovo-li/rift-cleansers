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


MODELS = {
    "iron_guard": (iron_guard, 2.0), "zombie": (zombie, 1.6), "skeleton": (skeleton, 1.6),
    "imp": (imp, 1.2), "ghoul": (ghoul, 1.2), "necromancer": (necromancer, 1.8),
    "bloater": (bloater, 1.6), "corrupted_knight": (corrupted_knight, 1.3), "rocks": (rocks, 1.0),
    "decor": (decor, 0.5),
}


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
        if name == "decor":
            print("[models] decor: 4 meshes")
            continue
        tris = lp.export(os.path.join(OUT_DIR, name + ".glb"))
        print("[models] %s: %d tris" % (name, tris))
        if preview:
            lp.render_preview(os.path.join(PREVIEW_DIR, name + ".png"), distance=height * 2.4, height=height)


main()
