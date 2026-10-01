"""模型零件工具（Blender 5.x，bpy + bmesh）：用细分基本体拼装角色/敌人/场景零件，零件颜色写入顶点色。

v2「平滑中模」：
- 默认更高分段（圆柱/圆锥 12-24 边、球 2-3 级细分），按零件大小自动取，小零件不浪费面数。
- 方块和圆柱端面带小圆角（bevel），平滑着色 + 加权法线：大平面保持平整，棱角处圆润高光。
- 每个零件自带竖直方向的明暗渐变（底部略暗，假 AO），发光零件传 ao=0 关闭。
- 新增 capsule（胶囊/四肢）、tube（沿折线扫掠的变径管：尾巴、角、触手、树枝）、lathe（旋转体：长袍、瓮）、
  torus（环）、blade（刀刃/叶片等扁平零件）。

约定（与 Godot 侧 ModelLibrary 对应，v1 起不变）：
- 角色面朝 +Y（导出 glTF 后为 -Z，即 Godot 的前方），脚底在 z=0，1 单位 = 1 米。
- 颜色写在顶点色属性 "Col"（逐面角），材质 "Base" 只是占位，Godot 用自己的材质读顶点色。
- team=True 的零件用材质 "Team"，Godot 里替换成玩家槽位颜色。
- rot 为 XYZ 欧拉角（度），变换顺序：缩放 → 旋转 → 平移。
"""
import math
import random

import bmesh
import bpy
import mathutils

Vector = mathutils.Vector

_parts = []
_part_groups = []  # 与 _parts 一一对应：零件所属的骨骼分组（角色拆件导出用）
_group = "body"

AO = 0.22          # 默认底部变暗比例
SHARP_ANGLE = 48.0  # 超过这个二面角的边保持硬边（圆锥底边、刀刃等）


def reset_scene():
    global _group
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _parts.clear()
    _part_groups.clear()
    _group = "body"


def group(name):
    """之后创建的零件归入 name 分组（body / head / arm_l / arm_r / leg_l / leg_r）。只影响 export_rig。"""
    global _group
    _group = name


def shade(color, k):
    """颜色明暗：k>1 提亮，k<1 压暗。"""
    return tuple(max(0.0, min(1.0, c * k)) for c in color[:3])


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


# ---------------------------------------------------------------- 内部

def _material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    return mat


def _matrix(loc, rot, scale=(1, 1, 1)):
    r = mathutils.Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()
    s = mathutils.Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    return mathutils.Matrix.Translation(loc) @ r @ s


def _bevel_sharp(bm, width, segments=2, min_angle=50.0):
    """给二面角大于 min_angle 的边倒圆角。"""
    if width <= 0.0:
        return
    edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0.0) > math.radians(min_angle)]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=width, segments=segments, profile=0.5,
                        affect="EDGES", clamp_overlap=True)


_frames = [mathutils.Matrix.Identity(4)]


class frame:
    """局部坐标系：with lp.frame(loc, rot): 里创建的零件都相对这个坐标系（盾牌、武器、可嵌套）。"""

    def __init__(self, loc, rot=(0, 0, 0), scale=(1, 1, 1)):
        self.m = _matrix(loc, rot, scale)

    def __enter__(self):
        _frames.append(_frames[-1] @ self.m)
        return self

    def __exit__(self, *exc):
        _frames.pop()


def _object(bm, matrix):
    bm.transform(_frames[-1] @ matrix)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("part")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("part", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _finish(obj, color, team, ao=None, smooth=True, sharp=SHARP_ANGLE):
    """平滑着色 + 加权法线、写入带竖直渐变的顶点色、设置材质，登记为待合并零件。"""
    mesh = obj.data
    if smooth:
        mesh.shade_smooth()
        mesh.set_sharp_from_angle(angle=math.radians(sharp))
        mod = obj.modifiers.new("wn", "WEIGHTED_NORMAL")
        mod.mode = "FACE_AREA"
        mod.keep_sharp = True
        mod.weight = 50
        with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    else:
        mesh.shade_flat()
    ao = AO if ao is None else ao
    zs = [v.co.z for v in mesh.vertices]
    z0, z1 = min(zs), max(zs)
    span = max(z1 - z0, 1e-4)
    attr = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for loop in mesh.loops:
        t = (mesh.vertices[loop.vertex_index].co.z - z0) / span
        k = 1.0 - ao * (1.0 - t) ** 1.6
        attr.data[loop.index].color_srgb = (color[0] * k, color[1] * k, color[2] * k, 1.0)
    mesh.materials.clear()
    mesh.materials.append(_material("Team" if team else "Base"))
    _parts.append(obj)
    _part_groups.append(_group)
    return obj


def _auto_segments(r, lo=10, hi=24):
    """按半径（米）取分段数：0.03 米约 10 边，0.4 米以上 24 边。"""
    return int(max(lo, min(hi, round(8 + r * 40))))


def _bevel_width(dims, bevel):
    if bevel is not None:
        return bevel
    return min(0.035, min(dims) * 0.18)


# ---------------------------------------------------------------- 基本体

def box(loc, size, color, rot=(0, 0, 0), team=False, bevel=None, ao=None, segments=2):
    """圆角方块。size 为三边长；bevel 为圆角半径（默认按最短边自动）。"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    _bevel_sharp(bm, _bevel_width(size, bevel), segments)
    return _finish(_object(bm, _matrix(loc, rot)), color, team, ao)


def cyl(loc, radius, depth, color, rot=(0, 0, 0), verts=None, team=False, radius2=None, bevel=None, ao=None):
    """圆柱或圆台（radius2 为顶部半径），depth 沿局部 z，端面边缘倒圆角。
    verts 为分段数（默认按半径自动；显式传小值可做棱柱，如方尖碑的 4 边）。"""
    r2 = radius if radius2 is None else radius2
    seg = verts or _auto_segments(max(radius, r2))
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=radius, radius2=r2, depth=depth)
    _bevel_sharp(bm, _bevel_width((max(radius, r2) * 2, depth), bevel) * 0.8)
    obj = _object(bm, _matrix(loc, rot))
    # 少边棱柱（≤8 边）保留棱线
    return _finish(obj, color, team, ao, sharp=SHARP_ANGLE if seg > 8 else 30.0)


def cone(loc, radius, depth, color, rot=(0, 0, 0), verts=None, team=False, ao=None, tip=0.0):
    """圆锥（tip 为顶端半径，>0 时是钝头）。verts 默认按半径自动；≤6 时为棱锥（冰晶、尖刺保留棱线）。"""
    seg = verts or _auto_segments(radius, lo=10, hi=20)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=seg,
                          radius1=radius, radius2=tip, depth=depth)
    _bevel_sharp(bm, min(0.02, radius * 0.12), 2, min_angle=70.0)
    obj = _object(bm, _matrix(loc, rot))
    return _finish(obj, color, team, ao, sharp=SHARP_ANGLE if seg > 6 else 25.0)


def ball(loc, size, color, rot=(0, 0, 0), subdiv=None, team=False, ao=None):
    """椭球。size 为三轴半径；subdiv 默认按大小自动（小零件 2 级，大零件 3 级）。"""
    if subdiv is None:
        subdiv = 3 if max(size) > 0.22 else 2
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    return _finish(_object(bm, _matrix(loc, rot, size)), color, team, ao)


def rock(loc, size, color, seed, jitter=0.25, flat_bottom=True, ao=None, subdiv=3):
    """不规则石块：细分 icosphere + 多层噪声位移，底部压平，大块面之间留折痕。"""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    off = Vector((rng.uniform(-50, 50), rng.uniform(-50, 50), rng.uniform(-50, 50)))
    # 随机几个切面方向，让石头有「劈开」的大块面
    planes = [Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 1))).normalized() for _ in range(5)]
    cuts = [rng.uniform(0.72, 0.9) for _ in planes]
    for v in bm.verts:
        p = v.co.copy()
        n = mathutils.noise.noise(p * 1.3 + off) * 0.6 + mathutils.noise.noise(p * 3.1 + off) * 0.25
        p *= 1.0 + n * jitter * 1.6
        for pl, c in zip(planes, cuts):
            d = p.dot(pl)
            if d > c:
                p -= pl * (d - c)
        v.co = p
    m = _matrix(loc, (rng.uniform(-12, 12), rng.uniform(-12, 12), rng.uniform(0, 360)), size)
    bm.transform(m)
    if flat_bottom:
        floor = loc[2] - size[2] * 0.55
        for v in bm.verts:
            if v.co.z < floor:
                v.co.z = floor
    obj = _object(bm, mathutils.Matrix.Identity(4))
    return _finish(obj, color, False, ao, sharp=38.0)


def torus(loc, major, minor, color, rot=(0, 0, 0), seg=None, ring=10, team=False, ao=None, scale=(1, 1, 1)):
    """圆环（光环、腰带扣、铁环）。圆环位于局部 xy 平面。"""
    seg = seg or _auto_segments(major, lo=16, hi=32)
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c, s = math.cos(a), math.sin(a)
        ring_v = []
        for j in range(ring):
            b = 2 * math.pi * j / ring
            r = major + minor * math.cos(b)
            ring_v.append(bm.verts.new((r * c, r * s, minor * math.sin(b))))
        rings.append(ring_v)
    for i in range(seg):
        a, b = rings[i], rings[(i + 1) % seg]
        for j in range(ring):
            bm.faces.new((a[j], b[j], b[(j + 1) % ring], a[(j + 1) % ring]))
    return _finish(_object(bm, _matrix(loc, rot, scale)), color, team, ao)


def tube(points, radii, color, seg=None, team=False, ao=None, cap=True, flat=1.0, flat_axis=None, sharp=SHARP_ANGLE):
    """沿折线扫掠的变径管：points 为世界坐标点列，radii 为每点半径（可为单个数）。
    flat<1 时截面沿 flat_axis（世界方向，默认自动）压扁，用于披风、羽冠、扁尾巴。端点半径为 0 时收成尖。"""
    pts = [Vector(p) for p in points]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    seg = seg or _auto_segments(max(radii), lo=8, hi=18)
    bm = bmesh.new()
    # 平行移动标架，避免扭转；副法线 = -flat_axis，截面沿它压扁
    t0 = (pts[1] - pts[0]).normalized()
    if flat_axis is not None:
        ref = Vector(flat_axis)
    else:
        ref = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((0, 1, 0))
    nrm = t0.cross(ref).normalized()
    rings = []
    tan_prev = t0
    for i, p in enumerate(pts):
        if i == 0:
            tan = t0
        elif i == len(pts) - 1:
            tan = (pts[i] - pts[i - 1]).normalized()
        else:
            tan = ((pts[i] - pts[i - 1]).normalized() + (pts[i + 1] - pts[i]).normalized()).normalized()
        nrm = tan_prev.rotation_difference(tan) @ nrm
        tan_prev = tan
        bin_ = tan.cross(nrm).normalized()
        r = max(radii[i], 0.0015)
        ring_v = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            off = nrm * (math.cos(a) * r) + bin_ * (math.sin(a) * r * flat)
            ring_v.append(bm.verts.new(p + off))
        rings.append(ring_v)
    for a, b in zip(rings, rings[1:]):
        for j in range(seg):
            bm.faces.new((a[j], a[(j + 1) % seg], b[(j + 1) % seg], b[j]))
    if cap:
        for ring_v, p, r in ((rings[0], pts[0], radii[0]), (rings[-1], pts[-1], radii[-1])):
            c = bm.verts.new(p)
            for j in range(seg):
                bm.faces.new((ring_v[j], ring_v[(j + 1) % seg], c))
    return _finish(_object(bm, mathutils.Matrix.Identity(4)), color, team, ao, sharp=sharp)


def _round_ends(pts, radii, steps=3):
    """给折线两端加半球：起点前、终点后各补 steps 圈，最外一圈半径为 0（收成圆头）。"""
    d0 = (pts[1] - pts[0]).normalized()
    d1 = (pts[-1] - pts[-2]).normalized()
    head_p, head_r, tail_p, tail_r = [], [], [], []
    for k in range(steps):
        ang = math.pi / 2 * k / steps  # 0 → 端点尖，逐步靠近端面
        head_p.append(pts[0] - d0 * radii[0] * math.cos(ang))
        head_r.append(radii[0] * math.sin(ang))
    for k in range(steps - 1, -1, -1):
        ang = math.pi / 2 * k / steps
        tail_p.append(pts[-1] + d1 * radii[-1] * math.cos(ang))
        tail_r.append(radii[-1] * math.sin(ang))
    return head_p + pts + tail_p, head_r + radii + tail_r


def capsule(a, b, radius, color, radius2=None, team=False, ao=None, seg=None, flat=1.0):
    """两点之间的胶囊（四肢、手指、骨头），radius2 为 b 端半径（锥形四肢）。"""
    a, b = Vector(a), Vector(b)
    rb = radius if radius2 is None else radius2
    mids = max(1, int((b - a).length / 0.1))
    pts = [a + (b - a) * (k / mids) for k in range(mids + 1)]
    rs = [radius + (rb - radius) * (k / mids) for k in range(mids + 1)]
    pts, rs = _round_ends(pts, rs)
    return tube(pts, rs, color, seg=seg, team=team, ao=ao, flat=flat)


def limb(points, radii, color, team=False, ao=None, seg=None):
    """多段四肢（大腿-小腿、上臂-前臂）：折线 + 每点半径，两端圆头，每段中间补一圈让弯折更顺。"""
    pts = [Vector(p) for p in points]
    allp, allr = [], []
    for i in range(len(pts)):
        allp.append(pts[i])
        allr.append(radii[i])
        if i < len(pts) - 1:
            allp.append((pts[i] + pts[i + 1]) * 0.5)
            allr.append((radii[i] + radii[i + 1]) * 0.5)
    allp, allr = _round_ends(allp, allr)
    return tube(allp, allr, color, seg=seg, team=team, ao=ao)


def lathe(loc, profile, color, rot=(0, 0, 0), seg=None, team=False, ao=None, scale=(1, 1, 1), wobble=0.0, seed=0):
    """旋转体：profile 为 [(半径, 高度), ...]（自下而上），绕局部 z 轴旋转。
    wobble>0 时半径随角度起伏（长袍褶皱、树干）。"""
    seg = seg or _auto_segments(max(r for r, _ in profile), lo=12, hi=28)
    rng = random.Random(seed)
    phase = rng.uniform(0, 6.28)
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring_v = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            rr = r * (1.0 + wobble * math.sin(a * 5 + phase) * 0.5 + wobble * math.sin(a * 9 + phase * 2) * 0.25)
            ring_v.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rings.append(ring_v)
    for a, b in zip(rings, rings[1:]):
        for j in range(seg):
            bm.faces.new((a[j], a[(j + 1) % seg], b[(j + 1) % seg], b[j]))
    for ring_v, (r, z), top in ((rings[0], profile[0], False), (rings[-1], profile[-1], True)):
        if r > 1e-4:
            c = bm.verts.new((0, 0, z))
            for j in range(seg):
                bm.faces.new((ring_v[j], ring_v[(j + 1) % seg], c))
    return _finish(_object(bm, _matrix(loc, rot, scale)), color, team, ao)


def blade(loc, length, width, thick, color, rot=(0, 0, 0), tip=0.2, team=False, ao=0.1, curve=0.0, seg=6):
    """扁平刀刃 / 叶片 / 羽片：沿局部 +y 伸出，菱形截面（中脊 + 两侧刃口），末端 tip 比例收尖。
    curve 让刀身沿 x 弯（弯刀、草叶）。"""
    bm = bmesh.new()
    rows = []
    for i in range(seg + 1):
        t = i / seg
        w = width * 0.5 * (1.0 if t < 1.0 - tip else max(0.0, (1.0 - t) / tip))
        w = max(w, 0.0008)
        th = thick * 0.5 * (1.0 - 0.6 * t)
        y = length * t
        x = curve * t * t
        rows.append([bm.verts.new((x - w, y, 0)), bm.verts.new((x, y, th)),
                     bm.verts.new((x + w, y, 0)), bm.verts.new((x, y, -th))])
    for a, b in zip(rows, rows[1:]):
        for j in range(4):
            bm.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    return _finish(_object(bm, _matrix(loc, rot)), color, team, ao, sharp=35.0)


def mirror_x(fn, x, *args, **kwargs):
    """在 ±x 各放一个（手臂、腿、眼睛）。loc 作为第一个参数，x 分量被替换。"""
    loc = args[0]
    fn((x, loc[1], loc[2]), *args[1:], **kwargs)
    fn((-x, loc[1], loc[2]), *args[1:], **kwargs)


# ---------------------------------------------------------------- 导出

def _tris(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def _gltf(path):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_vertex_color="ACTIVE",
        export_normals=True,
        # 必须导出材质名（"Base"/"Team"），Godot 靠名字找队伍色表面；PLACEHOLDER 模式会丢掉名字
        export_materials="EXPORT",
    )


def _join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    return obj


def export(path):
    """合并所有零件为一个网格并导出 glb。返回三角面数。"""
    obj = _join(_parts, "Model")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    _gltf(path)
    return _tris(obj.data)


def export_separate(path, groups):
    """每组零件合并为一个独立对象（按名字），一起导出到同一个 glb。groups: {名字: [零件...]}。返回 {名字: 三角面数}。"""
    counts = {}
    for name, parts in groups.items():
        counts[name] = _tris(_join(parts, name).data)
    bpy.ops.object.select_all(action="SELECT")
    _gltf(path)
    return counts


def export_rig(path, joints):
    """按 group() 分组合并零件，每组的原点放在关节 joints[组名]（Blender 坐标），一起导出到 path。
    Godot 里每个分组是一个以关节为原点的网格节点，绕原点旋转即可摆动四肢。"""
    groups = {}
    for obj, g in zip(_parts, _part_groups):
        groups.setdefault(g, []).append(obj)
    scene = bpy.context.scene
    for name, parts in groups.items():
        _join(parts, name)
        scene.cursor.location = joints.get(name, (0.0, 0.0, 0.0))
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.select_all(action="SELECT")
    _gltf(path)
    return sorted(groups)


def take_parts():
    """取出并清空当前已登记的零件（分组导出用）。"""
    parts = list(_parts)
    _parts.clear()
    _part_groups.clear()
    return parts


# ---------------------------------------------------------------- 预览

def _setup_render(size):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "WORLD"
    scene.render.resolution_x = size[0]
    scene.render.resolution_y = size[1]
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("W")
    scene.world.color = (0.16, 0.17, 0.2)
    return scene


def _look_rotation(direction):
    return Vector(direction).to_track_quat("-Z", "Y").to_euler()


def render_preview(path, distance=6.0, height=2.0):
    """Workbench 渲染一张预览图（顶点色 + 平滑着色），从前上方 3/4 角度看（角色面朝 +Y）。"""
    scene = _setup_render((512, 512))
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (distance * 0.6, distance, height + distance * 0.45)
    target = (0.0, 0.0, height * 0.5)
    cam.rotation_euler = _look_rotation([target[i] - cam.location[i] for i in range(3)])
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def render_kit_preview(path, objects):
    """零件包预览：把各零件横向排开（只在预览时移动，已导出的文件不受影响），俯视 3/4 角度渲染。"""
    x = 0.0
    spans = []
    for obj in objects:
        bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        w = max(v.x for v in bb) - min(v.x for v in bb)
        obj.location.x += x + w * 0.5 - (max(v.x for v in bb) + min(v.x for v in bb)) * 0.5
        spans.append(max(v.z for v in bb))
        x += w + 0.6
    width = x - 0.6
    top = max(spans) if spans else 1.0
    scene = _setup_render((1600, 600))
    cam_data = bpy.data.cameras.new("KitCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(width * 1.05, top * 2.9)
    cam = bpy.data.objects.new("KitCam", cam_data)
    scene.collection.objects.link(cam)
    target = Vector((width * 0.5, 0, top * 0.45))
    cam.location = target + Vector((0, 30, 16))
    cam.rotation_euler = _look_rotation(target - cam.location)
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
