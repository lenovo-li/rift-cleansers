"""技能特效资源（Blender 5.x，bpy）：特效网格套件 vfx_kit.glb + 贴图（符文法阵、地裂）。

用法：
  blender --background --factory-startup --python tools/blender/build_vfx.py -- [--preview]
也可以在 Blender MCP 里 exec 本文件后调用 build_kit() 预览（不导出）。

约定与 lowpoly.py 相同：Blender +Y 为前方（Godot -Z），z 向上，平面特效躺在 XY 平面（Godot 地面）。
网格带 UV（Godot 着色器用 UV 做渐变/滚动），颜色写在顶点色 "Col"。
"""
import math
import os
import random
import sys

import bpy
import bmesh

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_KIT = os.path.join(ROOT, "assets", "models", "vfx_kit.glb")
OUT_TEX = os.path.join(ROOT, "assets", "textures", "vfx")

STEEL = (0.78, 0.82, 0.9)
EDGE = (1.0, 1.0, 1.0)
HILT = (0.35, 0.25, 0.18)
LAVA = (1.0, 0.45, 0.08)
BASALT = (0.16, 0.12, 0.11)
ICE = (0.65, 0.92, 1.0)
ICE_DEEP = (0.3, 0.6, 0.95)


def clear():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def _material(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def mesh_object(name, verts, faces, uvs=None, colors=None, smooth=False):
    """由顶点/面建网格。uvs、colors 为逐顶点列表（写入每个面角）。"""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    uv = mesh.uv_layers.new(name="UVMap")
    col = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for poly in mesh.polygons:
        poly.use_smooth = smooth
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            if uvs:
                uv.data[li].uv = uvs[vi]
            c = colors[vi] if colors else (1.0, 1.0, 1.0)
            col.data[li].color_srgb = (c[0], c[1], c[2], 1.0)
    mesh.materials.append(_material("Vfx"))
    return obj


def from_bmesh(name, bm, color_fn, smooth=False):
    """bmesh -> 对象；color_fn(face, vert) 给每个面角上色。"""
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.uv_layers.new(name="UVMap")
    col = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for poly in mesh.polygons:
        poly.use_smooth = smooth
        for li in poly.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index]
            c = color_fn(poly, v)
            col.data[li].color_srgb = (c[0], c[1], c[2], 1.0)
    mesh.materials.append(_material("Vfx"))
    return obj


# ---------- 斩击弧：月牙形带状网格，u 沿弧（0 起刀 → 1 收刀），v 从内缘 0 到外缘 1 ----------
def slash_arc(name="SlashArc", arc_deg=160.0, inner=0.5, segments=28):
    verts, faces, uvs = [], [], []
    half = math.radians(arc_deg) * 0.5
    for i in range(segments + 1):
        t = i / segments
        a = -half + t * 2.0 * half
        # 月牙：中段最宽，两端收尖；刀锋侧（收刀端）略厚
        width = (1.0 - inner) * math.sin(math.pi * t) ** 0.7 * (0.75 + 0.25 * t)
        r_in = 1.0 - width
        # 方向：a=0 指向 +Y（前方）
        dx, dy = math.sin(a), math.cos(a)
        verts.append((dx * r_in, dy * r_in, 0.0))
        verts.append((dx * 1.0, dy * 1.0, 0.0))
        uvs.append((t, 0.0))
        uvs.append((t, 1.0))
    for i in range(segments):
        a, b = i * 2, i * 2 + 2
        faces.append((a, b, b + 1, a + 1))
    return mesh_object(name, verts, faces, uvs)


# ---------- 旋风带：绕 z 轴的倾斜螺旋带（旋风斩 / 刀刃风暴 / 雷暴），u 沿带，v 从下到上 ----------
def swirl(name="Swirl", turns=1.0, segments=48, height=0.9, rise=0.35):
    verts, faces, uvs = [], [], []
    for i in range(segments + 1):
        t = i / segments
        a = t * turns * 2.0 * math.pi
        r = 1.0 - 0.15 * t
        z0 = rise * t
        # 带子宽度两端收窄，看起来像一道风刃
        w = height * math.sin(math.pi * t) ** 0.5
        dx, dy = math.sin(a), math.cos(a)
        verts.append((dx * r, dy * r, z0))
        verts.append((dx * (r + 0.12), dy * (r + 0.12), z0 + w))
        uvs.append((t, 0.0))
        uvs.append((t, 1.0))
    for i in range(segments):
        a, b = i * 2, i * 2 + 2
        faces.append((a, b, b + 1, a + 1))
    return mesh_object(name, verts, faces, uvs)


# ---------- 光柱：两端开口的圆筒，u 绕一圈，v 从底到顶（惩击、神圣干预） ----------
def beam(name="Beam", segments=16):
    verts, faces, uvs = [], [], []
    for i in range(segments + 1):
        a = i / segments * 2.0 * math.pi
        verts.append((math.cos(a), math.sin(a), 0.0))
        verts.append((math.cos(a), math.sin(a), 1.0))
        uvs.append((i / segments, 0.0))
        uvs.append((i / segments, 1.0))
    for i in range(segments):
        a, b = i * 2, i * 2 + 2
        faces.append((a, b, b + 1, a + 1))
    return mesh_object(name, verts, faces, uvs)


def _box_bm(bm, center, size):
    geom = bmesh.ops.create_cube(bm, size=1.0)
    for v in geom["verts"]:
        v.co.x = v.co.x * size[0] + center[0]
        v.co.y = v.co.y * size[1] + center[1]
        v.co.z = v.co.z * size[2] + center[2]
    return geom["verts"]


# ---------- 飞刃（刀扇、刀刃风暴）：沿 +Y 的菱形刀身 + 护手 + 握柄，平躺 ----------
def dagger(name="Dagger", length=0.7):
    bm = bmesh.new()
    blade_len = length * 0.7
    # 刀身：中脊凸起的扁菱形（6 顶点）
    tip = bm.verts.new((0, blade_len, 0))
    base_l = bm.verts.new((-0.07, 0, 0))
    base_r = bm.verts.new((0.07, 0, 0))
    mid_l = bm.verts.new((-0.09, blade_len * 0.35, 0))
    mid_r = bm.verts.new((0.09, blade_len * 0.35, 0))
    ridge_t = bm.verts.new((0, blade_len * 0.35, 0.03))
    ridge_b = bm.verts.new((0, blade_len * 0.35, -0.03))
    for ridge in (ridge_t, ridge_b):
        bm.faces.new((tip, mid_l, ridge) if ridge is ridge_t else (tip, ridge, mid_l))
        bm.faces.new((tip, ridge, mid_r) if ridge is ridge_t else (tip, mid_r, ridge))
        bm.faces.new((mid_l, base_l, ridge) if ridge is ridge_t else (mid_l, ridge, base_l))
        bm.faces.new((mid_r, ridge, base_r) if ridge is ridge_t else (mid_r, base_r, ridge))
        bm.faces.new((base_l, base_r, ridge) if ridge is ridge_t else (base_l, ridge, base_r))
    _box_bm(bm, (0, -0.02, 0), (0.26, 0.04, 0.05))          # 护手
    _box_bm(bm, (0, -0.02 - length * 0.14, 0), (0.05, length * 0.24, 0.05))  # 握柄
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    def color(poly, v):
        if poly.center.y > 0.01:
            return EDGE if abs(poly.center.x) < 0.03 else STEEL
        return HILT
    return from_bmesh(name, bm, color)


# ---------- 巨剑（旋风斩）：更宽更长的剑，剑根在原点、剑尖朝 +Y ----------
def greatsword(name="Greatsword"):
    obj = dagger(name, length=1.6)
    obj.scale = (1.8, 1.0, 1.3)
    return obj


# ---------- 陨石：凹凸的玄武岩块，裂缝朝下（落地面）处是熔岩色 ----------
def meteor(name="Meteor", seed=7):
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in bm.verts:
        n = v.co.normalized()
        bump = 1.0 + rng.uniform(-0.18, 0.18) + 0.12 * math.sin(n.x * 5.0) * math.cos(n.y * 4.0)
        v.co = n * bump
    # 少量顶点再往里压，形成坑
    for v in rng.sample(list(bm.verts), 10):
        v.co *= 0.82
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    def color(poly, v):
        # 下半部和凹坑发熔岩光
        depth = poly.center.length
        if poly.center.z < -0.62 or depth < 0.84:
            return LAVA
        return BASALT if rng.random() > 0.25 else (0.28, 0.2, 0.16)
    return from_bmesh(name, bm, color)


# ---------- 冰枪：六棱柱 + 长尖，尖端朝 +Y ----------
def ice_lance(name="IceLance", length=1.8, radius=0.16, sides=6):
    bm = bmesh.new()
    ring_back, ring_front = [], []
    for i in range(sides):
        a = i / sides * 2.0 * math.pi
        x, z = math.cos(a) * radius, math.sin(a) * radius
        ring_back.append(bm.verts.new((x * 0.6, 0.0, z * 0.6)))
        ring_front.append(bm.verts.new((x, length * 0.45, z)))
    tip = bm.verts.new((0, length, 0))
    tail = bm.verts.new((0, -0.25, 0))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring_back[i], ring_back[j], ring_front[j], ring_front[i]))
        bm.faces.new((ring_front[i], ring_front[j], tip))
        bm.faces.new((ring_back[j], ring_back[i], tail))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bmesh(name, bm, lambda p, v: ICE if p.center.y > length * 0.45 else ICE_DEEP)


# ---------- 冰刺丛（冰霜新星地面、冰冻区域）：一簇朝外倾斜的冰锥，底在 z=0 ----------
def ice_spikes(name="IceSpikes", count=7, seed=3):
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(count):
        a = k / count * 2.0 * math.pi + rng.uniform(-0.3, 0.3)
        dist = 0.0 if k == 0 else rng.uniform(0.25, 0.55)
        h = rng.uniform(0.7, 1.2) * (1.4 if k == 0 else 1.0)
        r = rng.uniform(0.09, 0.15)
        base = (math.cos(a) * dist, math.sin(a) * dist)
        lean = (math.cos(a) * 0.35 * dist, math.sin(a) * 0.35 * dist)
        ring = []
        for i in range(5):
            b = i / 5 * 2.0 * math.pi
            ring.append(bm.verts.new((base[0] + math.cos(b) * r, base[1] + math.sin(b) * r, 0.0)))
        tip = bm.verts.new((base[0] + lean[0], base[1] + lean[1], h))
        for i in range(5):
            bm.faces.new((ring[i], ring[(i + 1) % 5], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bmesh(name, bm, lambda p, v: ICE if p.center.z > 0.35 else ICE_DEEP)


# ---------- 护盾罩：半球测地网格（神圣护盾、反伤光环），法线朝外，UV 用于六边形纹理 ----------
def dome(name="Dome"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < -0.05], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    obj = from_bmesh(name, bm, lambda p, v: (1.0, 1.0, 1.0))
    # 球面 UV：u 按方位角，v 按高度（着色器做扫光和边缘发光）
    mesh = obj.data
    uv = mesh.uv_layers[0]
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = (math.atan2(co.y, co.x) / (2.0 * math.pi) + 0.5, max(co.z, 0.0))
    return obj


# ---------- 烟团：几个凹凸球叠成的一朵烟（烟雾弹），底在 z=0 ----------
def smoke_puff(name="SmokePuff", seed=11):
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(5):
        geom = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        r = rng.uniform(0.35, 0.55) * (1.3 if k == 0 else 1.0)
        c = (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), r * 0.8 + (0.35 if k == 0 else rng.uniform(0.0, 0.3)))
        for v in geom["verts"]:
            v.co = v.co * r * (1.0 + rng.uniform(-0.12, 0.12))
            v.co.x += c[0]
            v.co.y += c[1]
            v.co.z += c[2]
    return from_bmesh(name, bm, lambda p, v: (0.42, 0.38, 0.5) if p.center.z < 0.5 else (0.62, 0.58, 0.7), smooth=True)


GOLD = (1.0, 0.78, 0.3)
SHIELD_BLUE = (0.45, 0.65, 1.0)
EARTH = (0.55, 0.42, 0.3)
EARTH_DARK = (0.3, 0.22, 0.17)


def _prism(bm, outline, y0, y1, scale=1.0):
    """把 XZ 平面上的轮廓 [(x, z)] 沿 y 从 y0 挤出到 y1（正面朝 +Y = Godot 前方）。"""
    back = [bm.verts.new((x * scale, y0, z * scale)) for x, z in outline]
    front = [bm.verts.new((x * scale, y1, z * scale)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))


def _torus_bm(bm, center, major, minor, segments=24, sides=4):
    """躺在 XY 平面的圆环（截面 sides 边形）。"""
    rings = []
    for i in range(segments):
        a = i / segments * 2.0 * math.pi
        ring = []
        for k in range(sides):
            b = k / sides * 2.0 * math.pi
            r = major + math.cos(b) * minor
            ring.append(bm.verts.new((center[0] + math.cos(a) * r, center[1] + math.sin(a) * r, center[2] + math.sin(b) * minor)))
        rings.append(ring)
    for i in range(segments):
        r0, r1 = rings[i], rings[(i + 1) % segments]
        for k in range(sides):
            m = (k + 1) % sides
            bm.faces.new((r0[k], r1[k], r1[m], r0[m]))


# ---------- 盾纹（铁卫普攻）：竖立的鸢形盾徽章，金边 + 蓝底 + 白十字，正面朝 +Y ----------
def shield_rune(name="ShieldRune"):
    half = [(0.36, 0.42), (0.39, 0.12), (0.32, -0.14), (0.18, -0.34), (0.0, -0.48)]
    outline = half + [(-x, z) for x, z in reversed(half[:-1])]
    bm = bmesh.new()
    _prism(bm, outline, -0.03, 0.03)
    _prism(bm, outline, 0.03, 0.06, scale=0.78)
    _prism(bm, [(-0.05, 0.3), (0.05, 0.3), (0.05, -0.3), (-0.05, -0.3)], 0.06, 0.09)
    _prism(bm, [(-0.22, 0.12), (0.22, 0.12), (0.22, 0.02), (-0.22, 0.02)], 0.06, 0.09)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    def color(poly, v):
        y = poly.center.y
        return EDGE if y > 0.061 else (SHIELD_BLUE if y > 0.031 else GOLD)
    return from_bmesh(name, bm, color)


# ---------- 元素水晶（元素术士普攻）：六棱双锥，前尖长后尖短，沿 +Y ----------
def crystal(name="Crystal", sides=6):
    bm = bmesh.new()
    ring = [bm.verts.new((math.cos(i / sides * 2.0 * math.pi) * 0.12, 0.0, math.sin(i / sides * 2.0 * math.pi) * 0.12))
            for i in range(sides)]
    tip = bm.verts.new((0, 0.5, 0))
    tail = bm.verts.new((0, -0.22, 0))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring[i], ring[j], tip))
        bm.faces.new((ring[j], ring[i], tail))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bmesh(name, bm, lambda p, v: EDGE if p.center.y > 0.1 else (0.75, 0.82, 1.0))


# ---------- 圣光十字（牧师普攻）：平躺的凯尔特十字（长臂朝 +Y）+ 光环 ----------
def holy_cross(name="HolyCross"):
    bm = bmesh.new()
    _box_bm(bm, (0, 0.04, 0), (0.1, 0.66, 0.06))
    _box_bm(bm, (0, 0.15, 0), (0.42, 0.1, 0.06))
    _torus_bm(bm, (0, 0.15, 0), 0.16, 0.022, segments=20)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bmesh(name, bm, lambda p, v: EDGE if abs(p.center.x) < 0.06 and abs(p.center.y - 0.15) < 0.06 else GOLD)


# ---------- 光冠（祝福 8 段、神圣干预）：平躺的圆环 + 12 根向上的光刺 ----------
def halo(name="Halo", spikes=12):
    bm = bmesh.new()
    _torus_bm(bm, (0, 0, 0), 0.4, 0.03, segments=32)
    for i in range(spikes):
        a = i / spikes * 2.0 * math.pi
        h = 0.2 if i % 2 == 0 else 0.12
        c = (math.cos(a) * 0.4, math.sin(a) * 0.4)
        base = [bm.verts.new((c[0] + math.cos(a + b) * 0.035, c[1] + math.sin(a + b) * 0.035, 0.0))
                for b in (0.0, 2.1, 4.2)]
        top = bm.verts.new((c[0], c[1], h))
        for k in range(3):
            bm.faces.new((base[k], base[(k + 1) % 3], top))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bmesh(name, bm, lambda p, v: EDGE if p.center.z > 0.08 else GOLD)


# ---------- 岩刺丛（震地、处决余波）：几根带折角的尖石，底在 z=0 ----------
def rock_spikes(name="RockSpikes", count=4, seed=9):
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(count):
        a = k / count * 2.0 * math.pi + rng.uniform(-0.4, 0.4)
        dist = 0.0 if k == 0 else rng.uniform(0.25, 0.45)
        h = rng.uniform(0.6, 0.95) * (1.4 if k == 0 else 1.0)
        r = rng.uniform(0.14, 0.22)
        bx, by = math.cos(a) * dist, math.sin(a) * dist
        lean = (math.cos(a) * 0.3 * dist, math.sin(a) * 0.3 * dist)
        base, mid = [], []
        for i in range(5):
            b = i / 5 * 2.0 * math.pi + rng.uniform(-0.2, 0.2)
            rr = r * rng.uniform(0.8, 1.2)
            base.append(bm.verts.new((bx + math.cos(b) * rr, by + math.sin(b) * rr, 0.0)))
            mid.append(bm.verts.new((bx + lean[0] * 0.5 + math.cos(b) * rr * 0.55,
                                     by + lean[1] * 0.5 + math.sin(b) * rr * 0.55, h * rng.uniform(0.4, 0.55))))
        tip = bm.verts.new((bx + lean[0], by + lean[1], h))
        for i in range(5):
            j = (i + 1) % 5
            bm.faces.new((base[i], base[j], mid[j], mid[i]))
            bm.faces.new((mid[i], mid[j], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bmesh(name, bm, lambda p, v: EARTH if p.center.z > 0.3 and rng.random() > 0.3 else EARTH_DARK)


# ---------- 格栅护罩（高段护盾 / 反射光环）：测地半球每个三角面内缩后只留边框，形成发光格栅 ----------
def lattice_dome(name="LatticeDome"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < -0.05], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    inner = list(bm.faces)
    bmesh.ops.inset_individual(bm, faces=inner, thickness=0.035, use_even_offset=True)
    bmesh.ops.delete(bm, geom=inner, context="FACES_ONLY")
    return from_bmesh(name, bm, lambda p, v: (1.0, 1.0, 1.0))


def pulse_sigil_shape():
    """铁卫普攻地面纹：外圈 + 8 面小盾轮廓 + 内圈虚线。"""
    f = Flat()
    f.ring(0.94, 1.0)
    f.ring(0.60, 0.63)
    for i in range(24):
        if i % 2 == 0:
            f.ring(0.44, 0.47, 4, i / 24 * 2.0 * math.pi, (i + 1) / 24 * 2.0 * math.pi)
    for i in range(8):
        a = i / 8 * 2.0 * math.pi
        c = _polar(0.78, a)
        t = (-math.sin(a), math.cos(a))
        n = (math.cos(a), math.sin(a))

        def at(u, v):
            return (c[0] + t[0] * u + n[0] * v, c[1] + t[1] * u + n[1] * v)
        pts = [at(-0.09, 0.1), at(0.09, 0.1), at(0.08, -0.02), at(0.0, -0.12), at(-0.08, -0.02)]
        for k in range(5):
            f.line(pts[k], pts[(k + 1) % 5], 0.025)
        f.line(at(0, 0.06), at(0, -0.06), 0.02)
    return f.build("PulseSigil")


def holy_sigil_shape():
    """牧师地面纹：太阳光芒（长短交替 16 道）+ 双圈 + 中心十字。"""
    f = Flat()
    f.ring(0.96, 1.0)
    f.ring(0.52, 0.56)
    f.ring(0.30, 0.32)
    for i in range(16):
        a = i / 16 * 2.0 * math.pi
        f.line(_polar(0.58, a), _polar(0.93 if i % 2 == 0 else 0.78, a), 0.05, 0.004)
    f.line((0, -0.26), (0, 0.26), 0.05)
    f.line((-0.18, 0.06), (0.18, 0.06), 0.05)
    for i in range(8):
        a = (i + 0.5) / 8 * 2.0 * math.pi
        f.quad([_polar(0.40, a - 0.07), _polar(0.46, a), _polar(0.40, a + 0.07), _polar(0.34, a)])
    return f.build("HolySigil")


def glow_ring_shape():
    """柔和的能量环（多层同心环，越往外越细），普攻脉冲、冲击用。"""
    f = Flat()
    for k, (r, w) in enumerate(((0.97, 0.03), (0.9, 0.06), (0.8, 0.02), (0.72, 0.012))):
        f.ring(r - w, r, 96)
    return f.build("GlowRing")


# ---------- 贴图：平面白色图形，从正上方正交渲染成透明底 PNG，Godot 着色器负责上色和发光 ----------
class Flat:
    """在 XY 平面上累积线段/圆环/多边形，最后合成一个网格对象。"""

    def __init__(self):
        self.verts, self.faces = [], []

    def quad(self, pts):
        base = len(self.verts)
        self.verts.extend((p[0], p[1], 0.0) for p in pts)
        self.faces.append(tuple(range(base, base + len(pts))))

    def line(self, p, q, w, w2=None):
        w2 = w if w2 is None else w2
        dx, dy = q[0] - p[0], q[1] - p[1]
        n = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / n, dx / n
        self.quad([(p[0] + nx * w * 0.5, p[1] + ny * w * 0.5), (p[0] - nx * w * 0.5, p[1] - ny * w * 0.5),
                   (q[0] - nx * w2 * 0.5, q[1] - ny * w2 * 0.5), (q[0] + nx * w2 * 0.5, q[1] + ny * w2 * 0.5)])

    def ring(self, r0, r1, segments=96, a0=0.0, a1=2.0 * math.pi):
        for i in range(segments):
            t0 = a0 + (a1 - a0) * i / segments
            t1 = a0 + (a1 - a0) * (i + 1) / segments
            self.quad([(math.cos(t0) * r0, math.sin(t0) * r0), (math.cos(t0) * r1, math.sin(t0) * r1),
                       (math.cos(t1) * r1, math.sin(t1) * r1), (math.cos(t1) * r0, math.sin(t1) * r0)])

    def build(self, name):
        return mesh_object(name, self.verts, self.faces)


def _polar(r, a):
    return (math.cos(a) * r, math.sin(a) * r)


def rune_circle_shape():
    f = Flat()
    f.ring(0.955, 1.0)
    f.ring(0.80, 0.83)
    f.ring(0.36, 0.39)
    f.ring(0.08, 0.12, 32)
    # 外圈符文带：24 道刻度 + 12 个小符号（菱形 / 竖杠 / 三角轮换）
    for i in range(24):
        a = i / 24 * 2.0 * math.pi
        f.line(_polar(0.83, a), _polar(0.87 if i % 2 else 0.955, a), 0.012)
    for i in range(12):
        a = (i + 0.5) / 12 * 2.0 * math.pi
        c = _polar(0.895, a)
        s = 0.035
        kind = i % 3
        if kind == 0:
            f.quad([_polar(0.895 - s, a), (c[0] + math.cos(a + math.pi / 2) * s * 0.7, c[1] + math.sin(a + math.pi / 2) * s * 0.7),
                    _polar(0.895 + s, a), (c[0] - math.cos(a + math.pi / 2) * s * 0.7, c[1] - math.sin(a + math.pi / 2) * s * 0.7)])
        elif kind == 1:
            f.line(_polar(0.86, a - 0.03), _polar(0.93, a - 0.03), 0.014)
            f.line(_polar(0.86, a + 0.03), _polar(0.93, a + 0.03), 0.014)
        else:
            f.quad([_polar(0.86, a - 0.04), _polar(0.86, a + 0.04), _polar(0.935, a)])
    # 六芒星（两个内接三角形）+ 内圈到星角的连线
    for k in range(2):
        pts = [_polar(0.80, math.pi / 2 + k * math.pi / 3 + j * 2.0 * math.pi / 3) for j in range(3)]
        for j in range(3):
            f.line(pts[j], pts[(j + 1) % 3], 0.022)
    for j in range(6):
        a = math.pi / 2 + j * math.pi / 3
        f.line(_polar(0.39, a), _polar(0.62, a), 0.012)
        f.quad([_polar(0.60, a - 0.06), _polar(0.66, a), _polar(0.60, a + 0.06), _polar(0.54, a)])
    return f.build("RuneCircle")


def crack_shape(seed=5):
    """地裂：从中心放射的分叉裂纹，越往外越细。"""
    rng = random.Random(seed)
    f = Flat()

    def branch(p, a, w, length, depth):
        steps = 5
        for _ in range(steps):
            a += rng.uniform(-0.45, 0.45)
            q = (p[0] + math.cos(a) * length / steps, p[1] + math.sin(a) * length / steps)
            f.line(p, q, w, w * 0.8)
            p, w = q, w * 0.8
            if depth > 0 and rng.random() < 0.35:
                branch(p, a + rng.choice((-1, 1)) * rng.uniform(0.5, 0.9), w * 0.8, length * 0.45, depth - 1)

    for i in range(9):
        a = i / 9 * 2.0 * math.pi + rng.uniform(-0.2, 0.2)
        branch((math.cos(a) * 0.06, math.sin(a) * 0.06), a, 0.075, rng.uniform(0.7, 0.92), 2)
    f.quad([_polar(0.1, i / 8 * 2.0 * math.pi) for i in range(8)])
    return f.build("Crack")


def render_top(obj, path, size=512):
    """只渲染 obj：正交俯视、白色平涂、透明背景。"""
    scene = bpy.context.scene
    for o in scene.objects:
        o.hide_render = o is not obj and o.type == "MESH"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (1.0, 1.0, 1.0)
    scene.render.film_transparent = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.get("TopCam")
    if cam is None:
        cam = bpy.data.objects.new("TopCam", bpy.data.cameras.new("TopCam"))
        scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.04
    cam.location = (obj.location.x, obj.location.y, 5.0)
    cam.rotation_euler = (0.0, 0.0, 0.0)
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in scene.objects:
        o.hide_render = False


KIT = (slash_arc, swirl, beam, dagger, greatsword, meteor, ice_lance, ice_spikes, dome, smoke_puff,
       shield_rune, crystal, holy_cross, halo, rock_spikes, lattice_dome)
TEXTURES = {"rune_circle": rune_circle_shape, "crack": crack_shape, "pulse_sigil": pulse_sigil_shape,
            "holy_sigil": holy_sigil_shape, "glow_ring": glow_ring_shape}


def build_kit(spread=3.0):
    """建出全部特效网格。spread > 0 时横向排开（MCP 预览用），导出前归位。"""
    objs = [fn() for fn in KIT]
    for i, obj in enumerate(objs):
        obj.location.x = i * spread
    return objs


def export_kit(objs, path=OUT_KIT):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.location = (0.0, 0.0, 0.0)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_vertex_color="ACTIVE", export_normals=True,
                              export_texcoords=True, export_materials="EXPORT")


def build_textures(out_dir=OUT_TEX):
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in TEXTURES.items():
        obj = fn()
        obj.location = (0.0, -10.0, 0.0)
        render_top(obj, os.path.join(out_dir, name + ".png"))
        bpy.data.objects.remove(obj, do_unlink=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_textures()
    objs = build_kit(spread=0.0)
    export_kit(objs)
    print("[vfx] exported %d meshes -> %s" % (len(objs), OUT_KIT))


if __name__ == "__main__" and "--" in sys.argv and bpy.app.background:
    main()
