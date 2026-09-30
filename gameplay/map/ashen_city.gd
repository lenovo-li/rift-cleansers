class_name AshenCity extends Node3D
## 灰烬王城：用 assets/models/ashen_city.glb 的模块化零件按固定种子摆出一张 190×190 米的废墟地图。
## 布局是确定性的（同一种子主机和客户端一样），所以联机不用同步地图。
## 渲染：同类零件一个 MultiMesh；碰撞：每个零件一个 StaticBody3D（障碍层，敌人和玩家都会被挡住）。

const LAYOUT_SEED: int = 20260927
const HALF: float = 95.0
const PLAZA_RADIUS: float = 13.0  # 出生点周围保持空旷
const KIT: String = "ashen_city"
const LAYER_OBSTACLE: int = 1 << 1
## 零件 -> 碰撞盒尺寸（米，以地面中心为原点）
const COLLIDERS: Dictionary = {
	"wall": Vector3(6.0, 2.6, 0.8), "wall_broken": Vector3(3.2, 1.6, 0.8), "pillar": Vector3(1.1, 3.7, 1.1),
	"pillar_broken": Vector3(1.1, 1.5, 1.1), "tower": Vector3(4.2, 4.4, 4.2), "brazier": Vector3(0.9, 1.1, 0.9),
	"statue": Vector3(2.6, 4.2, 2.6), "rubble": Vector3(1.8, 0.8, 1.6),
}
const DECOR_COUNTS: Dictionary = {"pebbles": 700, "grass": 900, "bones": 160, "crack": 260}

static var instance: AshenCity = null

## 每个障碍的 XZ 包围矩形（中心、半尺寸、旋转），用于刷怪/掉落避开墙体。
var _blockers: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _placed: Dictionary = {}  # 零件 -> Array[Transform3D]


func _ready() -> void:
	instance = self
	_rng.seed = LAYOUT_SEED
	_layout()
	for piece: String in _placed:
		_build_piece(piece, _placed[piece])
	if DisplayServer.get_name() != "headless":
		_scatter_decor()
		_add_brazier_lights()
		_add_embers()


func _exit_tree() -> void:
	if instance == self:
		instance = null


## pos 附近 radius 米内是否有障碍物。
func is_blocked(pos: Vector3, radius: float = 1.0) -> bool:
	for b: Array in _blockers:
		var local: Vector2 = Vector2(pos.x - b[0].x, pos.z - b[0].y).rotated(-b[2])
		if absf(local.x) < b[1].x + radius and absf(local.y) < b[1].y + radius:
			return true
	return false


## 从 pos 开始找一个不被挡住的点（螺旋外扩），找不到返回原点。
func find_free(pos: Vector3, radius: float = 1.0) -> Vector3:
	if not is_blocked(pos, radius):
		return pos
	for i in 24:
		var a: float = i * 2.4
		var r: float = 1.5 + i * 0.6
		var p: Vector3 = pos + Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x) < HALF and absf(p.z) < HALF and not is_blocked(p, radius):
			return p
	return pos


func _add(piece: String, pos: Vector3, yaw: float) -> void:
	var list: Array = _placed.get(piece, [])
	list.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, 0.0, pos.z)))
	_placed[piece] = list
	var size: Vector3 = COLLIDERS[piece]
	_blockers.append([Vector2(pos.x, pos.z), Vector2(size.x, size.z) * 0.5, -yaw])


## 位置是否离出生广场和已有障碍够远。
func _free_for(pos: Vector3, clearance: float) -> bool:
	if Vector2(pos.x, pos.z).length() < PLAZA_RADIUS + clearance:
		return false
	return not is_blocked(pos, clearance)


## 布局：中央广场（王像 + 石柱环）→ 半径 38 米的内城残墙（8 段、留缺口）→ 四角残塔 →
## 外圈散落断柱/瓦砾/火盆 → 场地边缘一圈城墙。
func _layout() -> void:
	_add("statue", Vector3(0, 0, -22), 0.0)
	for i in 10:
		var a: float = TAU * i / 10.0 + 0.3
		_add("pillar" if i % 3 != 1 else "pillar_broken", Vector3(cos(a), 0, sin(a)) * 19.0, a)
	for i in 8:
		var a: float = TAU * i / 8.0 + PI / 8.0
		var tangent: float = -a + PI / 2.0
		var c: Vector3 = Vector3(cos(a), 0, sin(a)) * 38.0
		var side: Vector3 = Vector3(cos(a + PI / 2.0), 0, sin(a + PI / 2.0))
		_add("wall", c - side * 3.2, tangent)
		_add("wall_broken" if i % 2 == 0 else "wall", c + side * 3.6, tangent)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add("tower", Vector3(sx * 64.0, 0, sz * 64.0), _rng.randf() * TAU)
	var budget: Dictionary = {"rubble": 34, "pillar_broken": 18, "brazier": 14, "wall_broken": 10}
	for piece: String in budget:
		var placed: int = 0
		for attempt in 400:
			if placed >= budget[piece]:
				break
			var p: Vector3 = Vector3(_rng.randf_range(-88, 88), 0, _rng.randf_range(-88, 88))
			if _free_for(p, 6.0 if piece != "brazier" else 3.0):
				_add(piece, p, _rng.randf() * TAU)
				placed += 1
	# 火盆额外放在内城缺口两侧，给广场附近照明
	for i in 4:
		var a: float = TAU * i / 4.0
		_add("brazier", Vector3(cos(a), 0, sin(a)) * 30.0, 0.0)
	# 边界城墙
	for i in range(-15, 16):
		var t: float = i * 6.2
		for edge: Array in [[Vector3(t, 0, -HALF - 1.5), 0.0], [Vector3(t, 0, HALF + 1.5), PI],
				[Vector3(-HALF - 1.5, 0, t), PI / 2.0], [Vector3(HALF + 1.5, 0, t), -PI / 2.0]]:
			_add("wall" if (i + 20) % 4 != 0 else "wall_broken", edge[0], edge[1])


func _build_piece(piece: String, transforms: Array) -> void:
	var mesh: Mesh = ModelLibrary.mesh(KIT, piece)
	if mesh != null:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "MM_" + piece
		mmi.multimesh = mm
		mmi.material_override = ModelLibrary.material(Color.WHITE, 0.0)
		add_child(mmi)
	var size: Vector3 = COLLIDERS[piece]
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	for t: Transform3D in transforms:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = LAYER_OBSTACLE
		body.collision_mask = 0
		body.transform = t
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3(0, size.y * 0.5, 0)
		body.add_child(col)
		add_child(body)


func _scatter_decor() -> void:
	for part: String in DECOR_COUNTS:
		var mesh: Mesh = ModelLibrary.mesh("decor", part)
		if mesh == null:
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var list: Array[Transform3D] = []
		for i in DECOR_COUNTS[part]:
			var p: Vector3 = Vector3(_rng.randf_range(-HALF, HALF), 0, _rng.randf_range(-HALF, HALF))
			if is_blocked(p, 0.3):
				continue
			var s: float = _rng.randf_range(0.7, 1.6) * (3.0 if part == "crack" else 1.0)
			list.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = ModelLibrary.material(Color.WHITE, 0.0)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## 离广场最近的 8 个火盆各一盏点光（限制数量，不拖累 500 敌人场景）。
func _add_brazier_lights() -> void:
	var braziers: Array = (_placed.get("brazier", []) as Array).duplicate()
	braziers.sort_custom(func(a: Transform3D, b: Transform3D) -> bool: return a.origin.length() < b.origin.length())
	for i in mini(8, braziers.size()):
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.light_energy = 2.2
		light.omni_range = 9.0
		light.shadow_enabled = false
		add_child(light)
		light.position = (braziers[i] as Transform3D).origin + Vector3(0, 1.6, 0)


## 广场周围漂浮余烬粒子（CPU 粒子，数量少，暖色调）。
func _add_embers() -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.emitting = true
	particles.amount = 120
	particles.lifetime = 8.0
	particles.preprocess = 2.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 32.0
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 35.0
	particles.gravity = Vector3(0, 0.15, 0)
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.8
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.24
	particles.color = Color(1.0, 0.6, 0.2, 0.7)
	add_child(particles)
	particles.position = Vector3(0, 0.5, 0)
