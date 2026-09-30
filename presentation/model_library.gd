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


## 网格里名为 name 的材质所在的表面序号（glb 导出的 "Team" / "Base"）。没有时返回 -1。
static func surface_index(m: Mesh, name: String) -> int:
	if m == null:
		return -1
	for i in m.get_surface_count():
		var mat: Material = m.surface_get_material(i)
		if mat != null and mat.resource_name == name:
			return i
	return -1


static func clear() -> void:
	_meshes.clear()
	_materials.clear()
