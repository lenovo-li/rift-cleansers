class_name MapBase extends Node3D
## 地图：按 NetConfig.map_id 从 MapCatalog 取主题，用对应 glb 的模块化零件按固定种子摆出 190×190 米的场地。
## 布局是确定性的（同一种子主机和客户端一样），所以联机不用同步地图。
## 渲染：同类零件一个 MultiMesh；碰撞：每个零件一个 StaticBody3D（障碍层，敌人和玩家都会被挡住）。
## 同时负责：环境/光照/地面主题、地面装饰、光源、漂浮粒子，以及主机上的环境危险（定期在玩家附近生成）。

const HALF: float = 95.0
const PLAZA_RADIUS: float = 13.0  # 出生点周围保持空旷
const LAYER_OBSTACLE: int = 1 << 1
const BlastScript: GDScript = preload("res://gameplay/actors/delayed_blast.gd")
const HazardScript: GDScript = preload("res://gameplay/actors/hazard_zone.gd")

static var current: MapBase = null

var map_id: String = MapCatalog.DEFAULT_ID
var def: Dictionary = {}
## 每个障碍的 XZ 包围矩形（中心、半尺寸、旋转），用于刷怪/掉落避开墙体。
var _blockers: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _placed: Dictionary = {}  # 零件 -> Array[Transform3D]
var _hazard_timer: float = 0.0
var _hazard_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	current = self
	map_id = NetConfig.map_id if MapCatalog.is_valid(NetConfig.map_id) else MapCatalog.DEFAULT_ID
	def = MapCatalog.get_def(map_id)
	rng.seed = def.seed
	_hazard_rng.randomize()
	_hazard_timer = float(def.hazard.get("first", 60.0))
	MapLayouts.build(self, def.layout)
	for piece: String in _placed:
		_build_piece(piece, _placed[piece])
	_apply_theme()
	if DisplayServer.get_name() != "headless":
		_scatter_decor()
		_add_lights()
		_add_particles()


func _exit_tree() -> void:
	if current == self:
		current = null


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


## 布局脚本调用：放置一个零件（碰撞盒尺寸取 def.colliders）。
func add(piece: String, pos: Vector3, yaw: float) -> void:
	var list: Array = _placed.get(piece, [])
	list.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, 0.0, pos.z)))
	_placed[piece] = list
	var size: Vector3 = def.colliders[piece]
	_blockers.append([Vector2(pos.x, pos.z), Vector2(size.x, size.z) * 0.5, -yaw])


## 位置是否离出生广场和已有障碍够远。
func free_for(pos: Vector3, clearance: float) -> bool:
	if Vector2(pos.x, pos.z).length() < PLAZA_RADIUS + clearance:
		return false
	return not is_blocked(pos, clearance)


## 随机撒 budget 里的零件：{零件: 数量}，clearance 为与其他障碍的间距。
func scatter(budget: Dictionary, clearance: float = 6.0, extent: float = 88.0) -> void:
	for piece: String in budget:
		var placed: int = 0
		for attempt in 400:
			if placed >= budget[piece]:
				break
			var p: Vector3 = Vector3(rng.randf_range(-extent, extent), 0, rng.randf_range(-extent, extent))
			if free_for(p, clearance):
				add(piece, p, rng.randf() * TAU)
				placed += 1


## 场地边缘一圈（每 6.2 米一段，每 4 段换一次 alt）。
func border(piece: String, alt: String) -> void:
	for i in range(-15, 16):
		var t: float = i * 6.2
		for edge: Array in [[Vector3(t, 0, -HALF - 1.5), 0.0], [Vector3(t, 0, HALF + 1.5), PI],
				[Vector3(-HALF - 1.5, 0, t), PI / 2.0], [Vector3(HALF + 1.5, 0, t), -PI / 2.0]]:
			add(piece if (i + 20) % 4 != 0 else alt, edge[0], edge[1])


func placed_count(piece: String) -> int:
	return (_placed.get(piece, []) as Array).size()


func _build_piece(piece: String, transforms: Array) -> void:
	var mesh: Mesh = ModelLibrary.mesh(def.kit, piece)
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
	var size: Vector3 = def.colliders[piece]
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


## 环境、太阳、地面材质按主题设置（复制一份，不改动场景里共享的资源）。
func _apply_theme() -> void:
	var parent: Node = get_parent()
	var we: WorldEnvironment = parent.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		var env: Environment = we.environment.duplicate()
		var e: Dictionary = def.env
		env.background_color = e.background
		env.ambient_light_color = e.ambient
		env.ambient_light_energy = e.ambient_energy
		env.fog_light_color = e.fog
		env.fog_density = e.fog_density
		we.environment = env
	var sun: DirectionalLight3D = parent.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = def.env.sun
		sun.light_energy = def.env.sun_energy
	var ground: CSGBox3D = parent.get_node_or_null("Ground") as CSGBox3D
	if ground != null and ground.material is ShaderMaterial:
		var mat: ShaderMaterial = (ground.material as ShaderMaterial).duplicate()
		for key: String in def.ground:
			mat.set_shader_parameter(key, def.ground[key])
		ground.material = mat


func _scatter_decor() -> void:
	var decor: Dictionary = def.decor
	for part: String in decor.counts:
		var mesh: Mesh = ModelLibrary.mesh(decor.kit, part)
		if mesh == null:
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var list: Array[Transform3D] = []
		var big: float = float(decor.get("big", {}).get(part, 1.0))
		for i in decor.counts[part]:
			var p: Vector3 = Vector3(rng.randf_range(-HALF, HALF), 0, rng.randf_range(-HALF, HALF))
			if is_blocked(p, 0.3):
				continue
			var s: float = rng.randf_range(0.7, 1.6) * big
			list.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = ModelLibrary.material(Color.WHITE, 0.0)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## 离广场最近的 8 个光源零件各一盏点光（限制数量，不拖累 500 敌人场景）。
func _add_lights() -> void:
	var l: Dictionary = def.lights
	var sources: Array = (_placed.get(l.piece, []) as Array).duplicate()
	sources.sort_custom(func(a: Transform3D, b: Transform3D) -> bool: return a.origin.length() < b.origin.length())
	for i in mini(8, sources.size()):
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = l.color
		light.light_energy = l.energy
		light.omni_range = 9.0
		light.shadow_enabled = false
		add_child(light)
		light.position = (sources[i] as Transform3D).origin + Vector3(0, l.height, 0)


## 广场周围漂浮粒子（余烬/雪花/沙尘/萤火虫，CPU 粒子，数量少）。
func _add_particles() -> void:
	var pd: Dictionary = def.particles
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.emitting = true
	particles.amount = pd.get("amount", 120)
	particles.lifetime = 8.0
	particles.preprocess = 2.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 32.0
	particles.direction = pd.get("direction", Vector3(0, 1, 0))
	particles.spread = 35.0
	particles.gravity = pd.gravity
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.8
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.24
	particles.color = pd.color
	add_child(particles)
	particles.position = Vector3(0, pd.get("height", 0.5), 0)


## 环境危险（主机/单人）：开局 first 秒后，每 interval 秒在随机一名存活玩家附近生成一次。
## blast = 延时爆炸（红圈预警），zone = 持续减速伤害区。客户端通过特效事件回放。
func _physics_process(delta: float) -> void:
	if NetConfig.is_client() or def.hazard.is_empty():
		return
	var session: GameSession = get_parent().get_node_or_null("GameSession") as GameSession
	if session == null or not session.is_running:
		return
	_hazard_timer -= delta
	if _hazard_timer > 0.0:
		return
	var h: Dictionary = def.hazard
	_hazard_timer = float(h.interval) * (0.7 if session.get_game_time() > 300.0 else 1.0)
	for p: Node3D in PlayerQuery.alive(get_tree()):
		for i in int(h.get("count", 1)):
			var a: float = _hazard_rng.randf() * TAU
			var pos: Vector3 = find_free(p.global_position + Vector3(cos(a), 0, sin(a)) * _hazard_rng.randf_range(2.0, 9.0), 0.5)
			spawn_hazard(pos)


func spawn_hazard(pos: Vector3) -> void:
	var h: Dictionary = def.hazard
	if h.kind == "blast":
		var blast: Node3D = BlastScript.new()
		blast.setup(h.radius, h.damage, h.fuse, h.name)
		blast.color = h.color
		get_parent().add_child(blast)
		blast.global_position = pos
		SkillVfx.record(["blast", pos, h.radius, h.fuse, h.color])
	else:
		var zone: Node3D = HazardScript.new()
		zone.setup(h.radius, h.slow, h.duration, h.color)
		zone.dps = h.damage
		zone.source_name = h.name
		get_parent().add_child(zone)
		zone.global_position = pos
		SkillVfx.record(["hazard", pos, h.radius, h.duration, h.color])
