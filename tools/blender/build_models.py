"""生成游戏里的全部模型（4 个角色、10 种敌人、4 个 Boss、石堆、地面装饰、4 套地图零件），导出到 assets/models/*.glb。
用法（项目根目录）：
  blender --background --factory-startup --python tools/blender/build_models.py -- [--preview] [名字 ...]
--preview 额外渲染 tools/blender/previews/<名字>.png 用于检查造型（零件包横向排开渲染）。
每次构建同时保存 tools/blender/blend/<名字>.blend（角色另有 <名字>_rig.blend），可用 Blender 直接打开。
风格：v2「平滑中模」——细分基本体 + 圆角 + 平滑着色 + 顶点色（带假 AO），见 lowpoly.py。
造型代码：heroes.py（角色）、enemies.py（敌人）、bosses.py（Boss）、kits.py（场景零件）。
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bosses  # noqa: E402
import enemies  # noqa: E402
import heroes  # noqa: E402
import kits  # noqa: E402
import lowpoly as lp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "models")
PREVIEW_DIR = os.path.join(ROOT, "tools", "blender", "previews")
# 每个模型的 Blender 源文件（可直接用 Blender 打开查看；目录里有 .gdignore，Godot 不导入）
BLEND_DIR = os.path.join(ROOT, "tools", "blender", "blend")

# 名字 -> (造型函数, 预览相机高度)
MODELS = {
    "iron_guard": (heroes.iron_guard, 2.0), "elementalist": (heroes.elementalist, 2.0),
    "shadow_walker": (heroes.shadow_walker, 2.0), "cleric": (heroes.cleric, 2.0),
    "zombie": (enemies.zombie, 1.6), "skeleton": (enemies.skeleton, 1.6), "imp": (enemies.imp, 1.2),
    "ghoul": (enemies.ghoul, 1.2), "necromancer": (enemies.necromancer, 1.8), "bloater": (enemies.bloater, 1.6),
    "ember_guard": (enemies.ember_guard, 1.6), "frost_wraith": (enemies.frost_wraith, 1.6),
    "sand_scarab": (enemies.sand_scarab, 0.8), "spore_shambler": (enemies.spore_shambler, 1.4),
    "corrupted_knight": (bosses.corrupted_knight, 1.3), "frost_lich": (bosses.frost_lich, 1.3),
    "sand_colossus": (bosses.sand_colossus, 1.3), "rotwood_treant": (bosses.rotwood_treant, 1.3),
    "rocks": (kits.rocks, 1.0),
}
# 零件包：函数返回 {网格名: [零件...]}，每组导出为同一个 glb 里的独立网格
KITS = {
    "decor": kits.decor, "ashen_city": kits.city_kit, "frost_wastes": kits.frost_kit,
    "sand_ruins": kits.desert_kit, "dark_forest": kits.forest_kit,
}

# 可动角色：额外导出 <名字>_rig.glb，每个 lp.group 分组一个网格，原点在关节（Blender 坐标，+x 为角色左侧）。
# 长袍角色没有 leg 分组，Godot 端按有无分组自动跳过。
RIGS = {
    "iron_guard": {"body": (0, 0, 0.9), "head": (0, 0, 1.5), "arm_l": (0.44, 0, 1.4), "arm_r": (-0.44, 0, 1.4),
                   "leg_l": (0.2, 0, 0.82), "leg_r": (-0.2, 0, 0.82)},
    "elementalist": {"body": (0, 0, 0.9), "head": (0, 0, 1.48), "arm_l": (0.3, 0, 1.4), "arm_r": (-0.3, 0, 1.4)},
    "shadow_walker": {"body": (0, 0, 0.9), "head": (0, 0, 1.45), "arm_l": (0.3, 0, 1.36), "arm_r": (-0.3, 0, 1.36),
                      "leg_l": (0.14, 0, 0.84), "leg_r": (-0.14, 0, 0.84)},
    "cleric": {"body": (0, 0, 0.9), "head": (0, 0, 1.5), "arm_l": (0.32, 0, 1.38), "arm_r": (-0.32, 0, 1.38)},
}


def build_kit(name, preview):
    lp.reset_scene()
    groups = KITS[name]()
    counts = lp.export_separate(os.path.join(OUT_DIR, name + ".glb"), groups)
    print("[models] %s: %s" % (name, ", ".join("%s=%d" % kv for kv in counts.items())))
    # 导出后再横向排开零件（glb 里每个零件仍在原点），.blend 里打开就能逐个看清
    objs = sorted((o for o in bpy.context.scene.objects if o.name in counts), key=lambda o: list(counts).index(o.name))
    width, top = lp.layout_row(objs)
    lp.save_blend(os.path.join(BLEND_DIR, name + ".blend"))
    if preview:
        lp.render_kit_preview(os.path.join(PREVIEW_DIR, name + ".png"), width, top)


def build_model(name, preview):
    fn, height = MODELS[name]
    lp.reset_scene()
    fn()
    tris = lp.export(os.path.join(OUT_DIR, name + ".glb"))
    lp.save_blend(os.path.join(BLEND_DIR, name + ".blend"))
    print("[models] %s: %d tris" % (name, tris))
    if preview:
        lp.render_preview(os.path.join(PREVIEW_DIR, name + ".png"), distance=height * 1.6, height=height)
    if name in RIGS:
        lp.reset_scene()
        fn()
        parts = lp.export_rig(os.path.join(OUT_DIR, name + "_rig.glb"), RIGS[name])
        lp.save_blend(os.path.join(BLEND_DIR, name + "_rig.blend"))
        print("[models] %s_rig: %s" % (name, ", ".join(parts)))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = "--preview" in argv
    names = [a for a in argv if not a.startswith("--")] or list(MODELS) + list(KITS)
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    os.makedirs(BLEND_DIR, exist_ok=True)
    for name in names:
        if name in KITS:
            build_kit(name, preview)
        else:
            build_model(name, preview)


main()
