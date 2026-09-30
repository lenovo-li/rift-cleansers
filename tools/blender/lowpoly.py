"""低模零件工具（Blender 5.x，bpy）：用少面数基本体拼装角色/敌人，零件颜色写入顶点色。

约定（与 Godot 侧 ModelLibrary 对应）：
- 角色面朝 +Y（导出 glTF 后为 -Z，即 Godot 的前方），脚底在 z=0，1 单位 = 1 米。
- 颜色写在顶点色属性 "Col"（逐面角），材质 "Base" 只是占位，Godot 用自己的材质读顶点色。
- team=True 的零件用材质 "Team"，Godot 里替换成玩家槽位颜色。
"""
import math
import random

import bpy

_parts = []


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _parts.clear()


def _material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    return mat


def _finish(obj, color, team, flat=True):
    """应用变换、写入顶点色、设置材质，登记为待合并零件。"""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh = obj.data
    attr = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    rgba = (color[0], color[1], color[2], 1.0)
    for i in range(len(attr.data)):
        attr.data[i].color_srgb = rgba
    mesh.materials.clear()
    mesh.materials.append(_material("Team" if team else "Base"))
    if flat:
        for poly in mesh.polygons:
            poly.use_smooth = False
    _parts.append(obj)
    return obj


def _place(obj, loc, rot, scale):
    obj.location = loc
    obj.rotation_euler = tuple(math.radians(a) for a in rot)
    obj.scale = scale


def box(loc, size, color, rot=(0, 0, 0), team=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    obj = bpy.context.active_object
    _place(obj, loc, rot, size)
    return _finish(obj, color, team)


def cyl(loc, radius, depth, color, rot=(0, 0, 0), verts=8, team=False, radius2=None):
    """圆柱或圆台（radius2 为顶部半径）。depth 沿局部 z。"""
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=1.0, depth=1.0)
        obj = bpy.context.active_object
        _place(obj, loc, rot, (radius, radius, depth))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=depth)
        obj = bpy.context.active_object
        _place(obj, loc, rot, (1, 1, 1))
    return _finish(obj, color, team)


def cone(loc, radius, depth, color, rot=(0, 0, 0), verts=6, team=False):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth)
    obj = bpy.context.active_object
    _place(obj, loc, rot, (1, 1, 1))
    return _finish(obj, color, team)


def ball(loc, size, color, rot=(0, 0, 0), subdiv=1, team=False):
    """低面数椭球（icosphere 细分 1 = 80 面）。size 为三轴半径。"""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1.0)
    obj = bpy.context.active_object
    _place(obj, loc, rot, size)
    return _finish(obj, color, team)


def rock(loc, size, color, seed, jitter=0.25):
    """不规则石块：icosphere 顶点随机位移。"""
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0)
    obj = bpy.context.active_object
    for v in obj.data.vertices:
        v.co *= 1.0 + rng.uniform(-jitter, jitter)
    _place(obj, loc, (rng.uniform(0, 30), rng.uniform(0, 30), rng.uniform(0, 360)), size)
    return _finish(obj, color, False)


def mirror_x(fn, x, *args, **kwargs):
    """在 ±x 各放一个（手臂、腿、眼睛）。loc 作为第一个参数，x 分量被替换。"""
    loc = args[0]
    fn((x, loc[1], loc[2]), *args[1:], **kwargs)
    fn((-x, loc[1], loc[2]), *args[1:], **kwargs)


def export(path):
    """合并所有零件为一个网格并导出 glb。返回三角面数。"""
    bpy.ops.object.select_all(action="DESELECT")
    for p in _parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = _parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = "Model"
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
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
    return tris


def render_preview(path, distance=6.0, height=2.0):
    """Workbench 渲染一张预览图（顶点色 + 平面着色），用来检查造型。"""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = False
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    # 从前上方 3/4 角度看（角色面朝 +Y）
    cam.location = (distance * 0.6, distance, height + distance * 0.45)
    target = (0.0, 0.0, height * 0.5)
    direction = [target[i] - cam.location[i] for i in range(3)]
    cam.rotation_euler = _look_rotation(direction)
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def _look_rotation(direction):
    import mathutils
    return mathutils.Vector(direction).to_track_quat("-Z", "Y").to_euler()


def export_separate(path, groups):
    """每组零件合并为一个独立对象（按名字），一起导出到同一个 glb。groups: {名字: [零件...]}。"""
    for name, parts in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        bpy.context.active_object.name = name
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_vertex_color="ACTIVE", export_materials="EXPORT")


def take_parts():
    """取出并清空当前已登记的零件（分组导出用）。"""
    parts = list(_parts)
    _parts.clear()
    return parts
