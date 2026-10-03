"""16 个新技能的专属特效网格（Blender 5.x）→ assets/models/skill_vfx_kit.glb + 地面贴图 assets/textures/vfx/sk_*.png

用法：
  blender --background --factory-startup --python tools/blender/build_skill_vfx.py --
约定同 build_vfx.py：XY 平面是地面，+Y 为前方（Godot -Z），z 向上；颜色写顶点色 "Col"，UV 给着色器做渐变。
着色器分工（presentation/shaders）：solid 实体（顶点色，偏红的面自发光）/ slash 刀光扫描（UV.x 沿弧，UV.y 内→外）/
beam 向上流动的能量（UV.y 底→顶）/ fresnel 边缘发光的罩子。每个技能一个主网格，名字带 _B 的是备选方案。
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import bmesh  # noqa: E402
import build_vfx as bv  # noqa: E402

OUT_KIT = os.path.join(bv.ROOT, "assets", "models", "skill_vfx_kit.glb")
OUT_BLEND = os.path.join(bv.ROOT, "tools", "blender", "blend", "skill_vfx_kit.blend")

ROCK = (0.42, 0.33, 0.25)
ROCK_DARK = (0.24, 0.19, 0.15)
LAVA = (1.0, 0.42, 0.06)
STEEL = (0.72, 0.76, 0.84)
STEEL_DARK = (0.38, 0.42, 0.5)
GOLD = (1.0, 0.8, 0.35)
ICE = (0.7, 0.93, 1.0)
ICE_DEEP = (0.32, 0.62, 0.95)
WHITE = (1.0, 1.0, 1.0)


def _ribbon(name, path, widths, up=False):
    """沿 path（XY 点列）的带状网格：UV.x 沿路径 0→1，UV.y 内缘 0 → 外缘 1。
    up=True 时带子竖起来（宽度沿 z），否则平躺（宽度沿路径法线）。"""
    verts, faces, uvs = [], [], []
    n = len(path)
    for i, (p, w) in enumerate(zip(path, widths)):
        q = path[min(i + 1, n - 1)] if i < n - 1 else path[i]
        o = path[max(i - 1, 0)]
        dx, dy = q[0] - o[0], q[1] - o[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        if up:
            verts += [(p[0], p[1], 0.0), (p[0], p[1], w)]
        else:
            verts += [(p[0] - nx * w * 0.5, p[1] - ny * w * 0.5, 0.0), (p[0] + nx * w * 0.5, p[1] + ny * w * 0.5, 0.0)]
        t = i / (n - 1)
        uvs += [(t, 0.0), (t, 1.0)]
    for i in range(n - 1):
        a = i * 2
        faces.append((a, a + 2, a + 3, a + 1))
    return bv.mesh_object(name, verts, faces, uvs)


# ============================================================ 铁卫

def quake_slab(name="QuakeSlab", seed=21):
    """地震：一块被地底顶起的岩板（锯齿顶边的厚板，底部一圈熔岩色会自发光）。Godot 里成圈撒开、逐圈顶起。"""
    rng = random.Random(seed)
    top = [(x, 1.0 + rng.uniform(-0.25, 0.2)) for x in (0.45, 0.25, 0.05, -0.15, -0.35)]
    outline = [(-0.5, 0.0), (0.5, 0.0), (0.52, 0.55)] + top + [(-0.5, 0.6)]
    bm = bmesh.new()
    bv._prism(bm, outline, -0.14, 0.14)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: LAVA if v.co.z < 0.08 else (ROCK if p.normal.z > 0.3 else ROCK_DARK))


def quake_pillar_b(name="QuakePillar_B", seed=22):
    """备选：玄武岩六棱柱簇（顶端带裂口），高低错落。"""
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(5):
        cx, cy = rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35)
        h = rng.uniform(0.6, 1.2)
        ring = [(cx + math.cos(a) * 0.18, cy + math.sin(a) * 0.18) for a in (i / 6 * 2 * math.pi for i in range(6))]
        bot = [bm.verts.new((x, y, 0.0)) for x, y in ring]
        topv = [bm.verts.new((x, y, h + rng.uniform(-0.08, 0.08))) for x, y in ring]
        bm.faces.new(topv)
        for i in range(6):
            j = (i + 1) % 6
            bm.faces.new((bot[i], bot[j], topv[j], topv[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: LAVA if v.co.z < 0.06 else (ROCK if p.normal.z > 0.5 else ROCK_DARK))


def iron_bulwark(name="IronBulwark"):
    """铁壁：一面竖立的塔盾（鸢形轮廓，中脊 + 两排铆钉），底边在 z=0，正面朝 +Y。Godot 里绕施法者围成一圈。"""
    outline = [(0.0, 0.0), (0.38, 0.35), (0.45, 1.25), (0.3, 1.45), (-0.3, 1.45), (-0.45, 1.25), (-0.38, 0.35)]
    bm = bmesh.new()
    bv._prism(bm, outline, -0.05, 0.05)
    bv._box_bm(bm, (0.0, 0.07, 0.8), (0.07, 0.05, 1.1))  # 中脊
    for z in (0.5, 0.85, 1.2):
        for x in (-0.28, 0.28):
            bv._box_bm(bm, (x, 0.07, z), (0.06, 0.04, 0.06))  # 铆钉
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: GOLD if v.co.y > 0.055 else (STEEL if p.normal.y > 0.5 else STEEL_DARK))


def roar_wave(name="RoarWave", segments=64):
    """战吼：竖起的声浪环（半径 1，高 0.5，上缘呈锯齿 = 声波），beam 着色器让能量向上流。Godot 里多圈依次扩散。"""
    pts = [(math.cos(a), math.sin(a)) for a in (i / segments * 2 * math.pi for i in range(segments + 1))]
    widths = [0.35 + (0.25 if i % 4 == 0 else 0.0) for i in range(segments + 1)]
    return _ribbon(name, pts, widths, up=True)


def roar_fang(name="RoarFang"):
    """战吼高段：从地面刺出的獠牙状能量尖（弯曲的锥），solid 着色器，外圈一排。"""
    bm = bmesh.new()
    rings = []
    for k in range(6):
        t = k / 5
        r = 0.16 * (1 - t) + 0.01
        cy = 0.25 * t * t  # 向前弯
        rings.append([bm.verts.new((math.cos(a) * r, cy + math.sin(a) * r, t * 1.1)) for a in (i / 5 * 2 * math.pi for i in range(5))])
    for k in range(5):
        for i in range(5):
            j = (i + 1) % 5
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: LAVA if v.co.z > 0.8 else GOLD)


def flame_crescent(name="FlameCrescent", arc_deg=135.0, segments=26):
    """烈焰斩：火焰月牙刀光（厚弧带，外缘锯齿状，slash 着色器从内到外渐变）+ 沿弧撒的火舌锥（solid 着色器自发光）。"""
    verts, faces, uvs, colors = [], [], [], []
    half = math.radians(arc_deg) * 0.5
    for i in range(segments + 1):
        t = i / segments
        a = -half + t * 2.0 * half
        r_in, r_out = 0.25, 1.0
        dx, dy = math.sin(a), math.cos(a)
        verts += [(dx * r_in, dy * r_in, 0.0), (dx * r_out, dy * r_out, 0.0)]
        uvs += [(t, 0.0), (t, 1.0)]
        colors += [(0.8, 0.25, 0.05), LAVA]
    for i in range(segments):
        a = i * 2
        faces.append((a, a + 2, a + 3, a + 1))
    obj = bv.mesh_object(name, verts, faces, uvs, colors)
    # 火舌锥（外缘 10 个）
    bm = bmesh.new()
    for k in range(10):
        t = (k + 0.5) / 10
        a = -half + t * 2.0 * half
        cx, cy = math.sin(a) * 1.05, math.cos(a) * 1.05
        base = [(cx + math.cos(b) * 0.08, cy + math.sin(b) * 0.08) for b in (i / 4 * 2 * math.pi for i in range(4))]
        bot = [bm.verts.new((x, y, 0.0)) for x, y in base]
        tip = bm.verts.new((cx, cy, 0.3 + (k % 3) * 0.05))
        for i in range(4):
            bm.faces.new([bot[i], bot[(i + 1) % 4], tip])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    flickers = bv.from_bmesh("FlameFlickers", bm, lambda p, v: LAVA)
    flickers.parent = obj
    flickers.location = (0, 0, 0)
    return obj


# ============================================================ 元素术士

def thunder_cloud(name="ThunderCloud", seed=33):
    """雷暴：扁平雷云团（压扁的多球聚合体，深蓝灰色，半径 1，高 0.4，悬在 z=2.5），fresnel 着色器边缘发光。"""
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(8):
        cx = rng.uniform(-0.5, 0.5)
        cy = rng.uniform(-0.5, 0.5)
        r = rng.uniform(0.35, 0.6)
        geom = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
        for v in geom["verts"]:
            v.co.x += cx
            v.co.y += cy
            v.co.z = v.co.z * 0.35 + 2.6
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: (0.25, 0.3, 0.45), smooth=True)


def thunder_bolt(name="ThunderBolt", seed=34):
    """雷暴：一道闪电（折线，beam 着色器，从云底 z=2.2 到地面）。Godot 里每波打 3 条随机位置。"""
    rng = random.Random(seed)
    pts = [(0, 0)] + [(rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4)) for _ in range(4)] + [(0, 0)]
    verts, faces = [], []
    zs = [2.2 - k / 5 * 2.2 for k in range(6)]
    for k, (x, y) in enumerate(pts):
        for side in (-0.04, 0.04):
            verts.append((x + side, y, zs[k]))
    for k in range(5):
        a = k * 2
        faces.append((a, a + 2, a + 3, a + 1))
    return bv.mesh_object(name, verts, faces, uvs=[(k / 5, i) for k in range(6) for i in (0, 1)], colors=[(0.7, 0.85, 1.0)] * 12)


def frost_hex(name="FrostHex"):
    """冰霜护盾：一块六边形冰晶板（厚 0.12，边长 0.4，中心透明边缘白），solid 着色器。Godot 里 8 块围圈。"""
    outline = [(math.cos(a) * 0.4, math.sin(a) * 0.4) for a in (i / 6 * 2 * math.pi for i in range(6))]
    bm = bmesh.new()
    bv._prism(bm, outline, -0.06, 0.06)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # 正反两面是透亮的冰，侧边是白色霜边
    return bv.from_bmesh(name, bm, lambda p, v: ICE if abs(p.normal.y) > 0.5 else WHITE)


def frost_dome_b(name="FrostDome_B"):
    """备选：半球冰罩（半径 1.2，底在 z=0），fresnel 着色器全包。"""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.2)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < -0.05], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: ICE_DEEP, smooth=True)


def arcane_shard(name="ArcaneShard"):
    """奥术弹幕：一颗飞弹（拉长的八面体，长 0.5，前端尖锐，solid 着色器紫白渐变），前方 +Y。Godot 里 spawn 多颗瞄准。"""
    bm = bmesh.new()
    tip = bm.verts.new((0, 0.25, 0))
    mid = [bm.verts.new((x, y, z)) for x, y, z in ((0.08, 0, 0.08), (0, 0, 0.11), (-0.08, 0, 0.08), (0, 0, -0.08))]
    tail = bm.verts.new((0, -0.25, 0))
    for i in range(4):
        bm.faces.new([tip, mid[i], mid[(i + 1) % 4]])
        bm.faces.new([tail, mid[(i + 1) % 4], mid[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: (0.95, 0.85, 1.0) if v.co.y > 0 else (0.6, 0.4, 0.9), smooth=True)


def lava_geyser(name="LavaGeyser", segments=12):
    """熔岩爆发：喷发柱（圆柱，底 r=0.3，顶 r=0.15，高 1.5，beam 着色器向上流），从火山口喷出。"""
    verts, faces, uvs = [], [], []
    for k in range(2):
        r = 0.3 if k == 0 else 0.15
        z = 0.0 if k == 0 else 1.5
        for i in range(segments):
            a = i / segments * 2 * math.pi
            verts.append((math.cos(a) * r, math.sin(a) * r, z))
            uvs.append((i / segments, k))
    for i in range(segments):
        j = (i + 1) % segments
        faces.append((i, j, j + segments, i + segments))
    return bv.mesh_object(name, verts, faces, uvs, colors=[LAVA] * (segments * 2))


def lava_crater(name="LavaCrater", segments=16):
    """熔岩爆发：火山口（凹陷的圆盘，r=1.2，中心下沉 0.2），solid 着色器中心发光。"""
    verts, faces = [], []
    for r_ring in (0.0, 0.4, 0.8, 1.2):
        for i in range(segments if r_ring > 0 else 1):
            if r_ring == 0:
                verts.append((0, 0, -0.2))
            else:
                a = i / segments * 2 * math.pi
                depth = -0.2 * (1 - r_ring / 1.2) ** 2
                verts.append((math.cos(a) * r_ring, math.sin(a) * r_ring, depth))
    for ring in range(3):  # 0：中心扇面；1、2：相邻两圈之间的四边形
        base = 1 + (ring - 1) * segments
        nxt = 1 + ring * segments
        for i in range(segments):
            j = (i + 1) % segments
            if ring == 0:
                faces.append((0, 1 + i, 1 + j))
            else:
                faces.append((base + i, base + j, nxt + j, nxt + i))
    return bv.mesh_object(name, verts, faces, colors=[LAVA if i < 1 + segments else ROCK_DARK for i in range(len(verts))])


# ============================================================ 影行者

def blood_spray(name="BloodSpray", seed=44):
    """剔骨/背刺：血液飞溅（12 个小球簇射），solid 着色器。Godot 里从目标位置向外抛洒。"""
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(12):
        a = (k / 12 + rng.uniform(-0.05, 0.05)) * 2 * math.pi
        dist = rng.uniform(0.15, 0.4)
        geom = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.05)
        for v in geom["verts"]:
            v.co.x += math.cos(a) * dist
            v.co.y += math.sin(a) * dist
            v.co.z += rng.uniform(0.08, 0.22)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: (0.75, 0.08, 0.12), smooth=True)


def shadow_veil(name="ShadowVeil"):
    """暗影分身：暗影雾气（扁平扭曲球，r=0.8，高 0.6，悬在 z=1.0），fresnel 着色器紫黑半透明。"""
    rng = random.Random(45)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=0.8)
    for v in bm.verts:
        v.co.z = v.co.z * 0.75 + 1.0
        v.co.x += rng.uniform(-0.1, 0.1)  # 轻微扰动，像翻滚的雾
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: (0.35, 0.25, 0.55), smooth=True)


def shadow_claw(name="ShadowClaw", segments=14):
    """剔骨：三道平行的弧形爪痕（一个网格，slash 着色器：UV.x 沿弧扫过，中段最宽、两端收尖）。
    躺在 XY 平面，Godot 里竖起来斜砍在目标身上。"""
    verts, faces, uvs = [], [], []
    for k in range(3):
        off = (k - 1) * 0.28
        base = len(verts)
        for i in range(segments + 1):
            t = i / segments
            a = -0.9 + t * 1.8
            cx, cy = math.sin(a) * 0.9 + off * 0.3, math.cos(a) * 0.9 - 0.9 + off
            w = 0.11 * math.sin(math.pi * t) ** 0.6 * (1.0 if k == 1 else 0.8)
            nx, ny = math.sin(a), math.cos(a)
            verts += [(cx - nx * w, cy - ny * w, 0.0), (cx + nx * w, cy + ny * w, 0.0)]
            uvs += [(t, 0.0), (t, 1.0)]
        for i in range(segments):
            a = base + i * 2
            faces.append((a, a + 2, a + 3, a + 1))
    return bv.mesh_object(name, verts, faces, uvs)


def poison_drop(name="PoisonDrop"):
    """毒刃：毒液液滴（水滴形，solid 着色器绿色半透明）。Godot 里从刀尖飞向目标后炸开。"""
    bm = bmesh.new()
    geom = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.12)
    for v in geom["verts"]:
        v.co.z *= 1.4  # 拉长
        if v.co.z > 0.1:
            v.co.z += 0.05  # 顶部收尖
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: (0.35, 0.95, 0.25), smooth=True)


# ============================================================ 牧师

def holy_wing(name="HolyWing"):
    """守护天使：一侧翅膀（5 根羽毛，弧形排列），solid 着色器金白色。Godot 里左右对称摆放。"""
    bm = bmesh.new()
    for k in range(5):
        a = k / 5 * math.pi * 0.5  # 从竖直到平展
        cx = math.sin(a) * 0.8
        cz = 1.2 + math.cos(a) * 0.6
        feather = [(cx + x * math.cos(a) - y * math.sin(a) * 0.3, y, cz + x * math.sin(a) + y * math.cos(a) * 0.3)
                   for x, y in [(-0.08, 0), (0.08, 0), (0.05, 0.35), (-0.05, 0.35)]]
        verts_idx = [bm.verts.new(p) for p in feather]
        bm.faces.new(verts_idx)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: GOLD if v.co.z > 1.3 else WHITE)


def purify_lotus(name="PurifyLotus"):
    """净化：莲花（6 片花瓣从地面张开，solid 着色器白金渐变）。Godot 里旋转展开动画。"""
    bm = bmesh.new()
    for k in range(6):
        a = k / 6 * 2 * math.pi
        dx, dy = math.cos(a), math.sin(a)
        petal = [(dx * r, dy * r, z) for r, z in [(0.05, 0.05), (0.45, 0.15), (0.55, 0.4), (0.35, 0.5)]]
        vs = [bm.verts.new(p) for p in petal]
        bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: GOLD if v.co.z > 0.3 else WHITE)


def resurrection_spire(name="ResurrectionSpire"):
    """复活术：上升光柱（锥台，底 r=0.2，顶 r=0.05，高 3.0，beam 着色器），顶部带翅膀轮廓。"""
    bm = bmesh.new()
    segments = 16
    for k, (r, z) in enumerate([(0.2, 0), (0.05, 3.0)]):
        ring = [bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for a in (i / segments * 2 * math.pi for i in range(segments))]
        if k == 0:
            bot_ring = ring
        else:
            top_ring = ring
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([bot_ring[i], bot_ring[j], top_ring[j], top_ring[i]])
    # 顶部简化翅膀（两个三角形）
    wing_l = bm.verts.new((-0.6, 0, 3.2))
    wing_r = bm.verts.new((0.6, 0, 3.2))
    apex = bm.verts.new((0, 0, 3.0))
    bm.faces.new([apex, wing_l, top_ring[segments // 4]])
    bm.faces.new([apex, top_ring[segments * 3 // 4], wing_r])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: GOLD if v.co.z > 2.8 else WHITE)


def holy_blade(name="HolyBlade"):
    """圣怒：天降圣剑（剑身从 z=4 刺向地面，金色，solid 着色器），Godot 里从天而降插地。"""
    # _prism 的轮廓在竖直的 XZ 平面：剑尖在原点朝下，剑身向上 2.2 米（Godot 里从高空落下插进地面）
    blade = [(0.0, 0.0), (0.16, 0.45), (0.12, 2.2), (-0.12, 2.2), (-0.16, 0.45)]
    bm = bmesh.new()
    bv._prism(bm, blade, -0.035, 0.035)
    bv._box_bm(bm, (0.0, 0.0, 2.26), (0.75, 0.1, 0.12))  # 护手
    bv._box_bm(bm, (0.0, 0.0, 2.62), (0.09, 0.09, 0.6))  # 握柄
    bv._box_bm(bm, (0.0, 0.0, 2.98), (0.18, 0.12, 0.18))  # 剑首
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bv.from_bmesh(name, bm, lambda p, v: WHITE if v.co.z < 2.2 and abs(v.co.x) < 0.05 else GOLD)


# ============================================================ 构建与导出

PARTS = [
    quake_slab, quake_pillar_b, iron_bulwark, roar_wave, roar_fang, flame_crescent,
    thunder_cloud, thunder_bolt, frost_hex, frost_dome_b, arcane_shard, lava_geyser, lava_crater,
    blood_spray, shadow_veil, shadow_claw, poison_drop,
    holy_wing, purify_lotus, resurrection_spire, holy_blade,
]


def build_kit(spread=2.5):
    """生成所有网格，spread > 0 时排列预览。"""
    objs = []
    for i, fn in enumerate(PARTS):
        obj = fn()
        if spread > 0:
            obj.location = ((i % 6) * spread, (i // 6) * spread, 0)
        objs.append(obj)
    return objs


def export_kit(objs, path=OUT_KIT):
    """导出为 GLB（选中全部对象，应用变换，export_yup 转 Godot 坐标）。"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_vertex_color="ACTIVE", export_normals=True,
                              export_texcoords=True, export_materials="EXPORT")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = build_kit(spread=0.0)
    export_kit(objs)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print(f"[skill_vfx] exported {len(objs)} meshes → {OUT_KIT}")
    print(f"[skill_vfx] saved .blend → {OUT_BLEND}")


if __name__ == "__main__" and "--" in sys.argv and bpy.app.background:
    main()


