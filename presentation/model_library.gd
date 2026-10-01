class_name ModelLibrary extends RefCounted
## 低模资源库：assets/models/*.glb（由 tools/blender/build_models.py 生成）。
## 每个 glb 只加载一次，取出网格；颜色来自顶点色，材质按「染色」共享（同色敌人一个材质，不破坏批处理）。
## 网格原点在脚底、面朝 -Z（Godot 前方）。

const MODEL_DIR: String = "res://assets/models/"

static var _meshes: Dictionary = {}     # "文件/节点名" -> Mesh
static var _materials: Dictionary = {}  # [tint, emission] -> StandardMaterial3D


## 取模型网格。glb 里只有一个网格时 part 可省略。找不到时返回 null（调用方退回灰盒网格）。
static func mesh(model: String, part: String = "") -> Mesh:
	var key: String = model + "/" + part
	if _meshes.has(key):
		return _meshes[key]
	var path: String = MODEL_DIR + model + ".glb"
	var found: Mesh = null
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		var root: Node = packed.instantiate() if packed else null
		if root != null:
			for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
				if part.is_empty() or mi.name == part:
					found = (mi as MeshInstance3D).mesh
					break
			root.free()
	_meshes[key] = found
	return found


## 读顶点色的共享材质。tint 与顶点色相乘；emission > 0 时整体微微发光（精英）。
static func material(tint: Color = Color.WHITE, emission: float = 0.0) -> StandardMaterial3D:
	var key: Array = [tint, emission]
	if not _materials.has(key):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = tint
		mat.roughness = 0.85
		if emission > 0.0:
			mat.emission_enabled = true
			mat.emission = tint
			mat.emission_energy_multiplier = emission
		_materials[key] = mat
	return _materials[key]


const ANIM_SHADER: Shader = preload("res://presentation/model_anim.gdshader")
static var _anim_materials: Dictionary = {}  # [tint, emission, wind] -> ShaderMaterial


## 带顶点动画的共享材质（敌人、Boss、地图零件）：读顶点色 + 模型 UV 里的动作分区。
## 敌人的动作状态走实例参数（anim_a / anim_b），同一材质可以被所有同色敌人共享。
static func anim_material(tint: Color = Color.WHITE, emission: float = 0.0, wind: float = 1.0) -> ShaderMaterial:
	var key: Array = [tint, emission, wind]
	if not _anim_materials.has(key):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = ANIM_SHADER
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("emission_energy", emission)
		mat.set_shader_parameter("wind_strength", wind)
		_anim_materials[key] = mat
	return _anim_materials[key]


## 网格里名为 name 的材质所在的表面序号（glb 导出的 "Team" / "Base"）。没有时返回 -1。
static func surface_index(m: Mesh, name: String) -> int:
	if m == null:
		return -1
	for i in m.get_surface_count():
		var mat: Material = m.surface_get_material(i)
		if mat != null and mat.resource_name == name:
			return i
	return -1


static var _rigs: Dictionary = {}  # 模型名 -> {分组名: [Mesh, 关节位置]}


## 可动角色拆件（<model>_rig.glb，build_models.py 的 RIGS）：{分组名: [网格, 关节位置]}。
## 网格顶点相对关节，放在关节处的节点下绕原点旋转即可摆动。没有拆件文件时返回空字典。
static func rig(model: String) -> Dictionary:
	if _rigs.has(model):
		return _rigs[model]
	var found: Dictionary = {}
	var path: String = MODEL_DIR + model + "_rig.glb"
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		var root: Node = packed.instantiate() if packed else null
		if root != null:
			for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
				var m3: MeshInstance3D = mi as MeshInstance3D
				# glTF 导入时对象名可能落在父节点上，按网格资源名或节点名取分组名
				var key: String = String(m3.mesh.resource_name) if m3.mesh and not m3.mesh.resource_name.is_empty() else String(m3.name)
				if key.contains("_rig_"):
					key = key.get_slice("_rig_", 1)  # "iron_guard_rig_arm_l" -> "arm_l"
				found[key] = [m3.mesh, m3.global_transform.origin if m3.is_inside_tree() else _world_origin(m3)]
			root.free()
	_rigs[model] = found
	return found


## 未进场景树的节点：沿父链累加变换求世界坐标。
static func _world_origin(n: Node3D) -> Vector3:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t.origin


static func clear() -> void:
	_meshes.clear()
	_materials.clear()
	_anim_materials.clear()
	_rigs.clear()
