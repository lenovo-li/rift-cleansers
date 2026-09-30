class_name ParticleFx extends RefCounted
## 一次性粒子爆发（Kenney Particle Pack 贴图 + GPUParticles3D）。
## 每种预设有一个节点池，重复使用；全局同时存在的爆发有上限，500 敌人同时挨打时不会失控。
## 通过 SkillVfx.burst 调用会被录制，联机客户端同样能看到。

const TEX_DIR: String = "res://assets/particles/kenney_particle-pack/PNG (Transparent)/"
const MAX_ACTIVE: int = 48
const POOL_PER_PRESET: int = 16
## 预设 -> {tex, amount, life, speed, spread, gravity, size, color, radius, additive}
const PRESETS: Dictionary = {
	"spark": {"tex": "spark_05.png", "amount": 8, "life": 0.35, "speed": Vector2(5, 9), "spread": 70.0,
		"gravity": -8.0, "size": Vector2(0.25, 0.45), "color": Color(1.0, 0.85, 0.5), "radius": 0.2, "additive": true},
	"debris": {"tex": "dirt_02.png", "amount": 10, "life": 0.6, "speed": Vector2(3, 7), "spread": 60.0,
		"gravity": -14.0, "size": Vector2(0.3, 0.6), "color": Color(0.6, 0.55, 0.5), "radius": 0.4, "additive": false},
	"smoke": {"tex": "smoke_04.png", "amount": 6, "life": 0.9, "speed": Vector2(0.5, 1.5), "spread": 180.0,
		"gravity": 1.5, "size": Vector2(0.9, 1.6), "color": Color(0.5, 0.5, 0.55, 0.6), "radius": 0.6, "additive": false},
	"dust": {"tex": "smoke_07.png", "amount": 18, "life": 0.7, "speed": Vector2(4, 7), "spread": 180.0,
		"gravity": 0.0, "size": Vector2(0.8, 1.4), "color": Color(0.75, 0.65, 0.5, 0.7), "radius": 0.5, "additive": false, "flat": true},
	"fire": {"tex": "flame_03.png", "amount": 16, "life": 0.55, "speed": Vector2(2, 5), "spread": 45.0,
		"gravity": 5.0, "size": Vector2(0.6, 1.1), "color": Color(1.0, 0.55, 0.15), "radius": 0.8, "additive": true},
	"shard": {"tex": "trace_04.png", "amount": 12, "life": 0.45, "speed": Vector2(6, 11), "spread": 90.0,
		"gravity": -10.0, "size": Vector2(0.3, 0.5), "color": Color(0.6, 0.9, 1.0), "radius": 0.3, "additive": true},
	"star": {"tex": "star_06.png", "amount": 14, "life": 0.9, "speed": Vector2(2, 4), "spread": 180.0,
		"gravity": 3.0, "size": Vector2(0.35, 0.7), "color": Color(1.0, 0.9, 0.4), "radius": 0.8, "additive": true},
	"magic": {"tex": "magic_03.png", "amount": 10, "life": 0.6, "speed": Vector2(1, 3), "spread": 180.0,
		"gravity": 1.0, "size": Vector2(0.6, 1.0), "color": Color(0.5, 0.8, 1.0), "radius": 0.6, "additive": true},
}

static var _pools: Dictionary = {}       # 预设 -> Array[GPUParticles3D]
static var _draw_materials: Dictionary = {}  # 预设 -> StandardMaterial3D
static var _process_materials: Dictionary = {}  # 预设 -> ParticleProcessMaterial（颜色每次覆盖）
static var _host: Node = null
static var _active_until: Array[int] = []  # 每个活跃爆发结束的时刻（毫秒）


## 在 pos 处爆发一次。scale 同时缩放范围和速度；color 为透明时用预设颜色。
static func burst(parent: Node, preset: String, pos: Vector3, scale: float = 1.0, color: Color = Color(0, 0, 0, 0)) -> void:
	if parent == null or not parent.is_inside_tree() or not PRESETS.has(preset):
		return
	if DisplayServer.get_name() == "headless":
		return  # 无头模拟里不创建粒子
	var now: int = Time.get_ticks_msec()
	while not _active_until.is_empty() and _active_until[0] <= now:
		_active_until.pop_front()
	if _active_until.size() >= MAX_ACTIVE:
		return
	var p: GPUParticles3D = _acquire(parent, preset)
	if p == null:
		return
	var cfg: Dictionary = PRESETS[preset]
	var pm: ParticleProcessMaterial = p.process_material
	pm.color = cfg.color if color.a <= 0.0 else color
	pm.emission_sphere_radius = float(cfg.radius) * scale
	pm.initial_velocity_min = cfg.speed.x * scale
	pm.initial_velocity_max = cfg.speed.y * scale
	p.global_position = pos
	p.restart()
	p.emitting = true
	var until: int = now + int(float(cfg.life) * 1000.0) + 100
	var idx: int = _active_until.bsearch(until)
	_active_until.insert(idx, until)
	p.set_meta("busy_until", until)


static func _acquire(parent: Node, preset: String) -> GPUParticles3D:
	var host: Node = parent.get_tree().current_scene if parent.get_tree().current_scene else parent
	if _host == null or not is_instance_valid(_host) or _host != host:
		_host = host  # 场景重载后旧节点已随场景释放
		_pools.clear()
		_active_until.clear()
	var pool: Array = _pools.get(preset, [])
	var now: int = Time.get_ticks_msec()
	for p: GPUParticles3D in pool:
		if int(p.get_meta("busy_until", 0)) <= now:
			return p
	if pool.size() >= POOL_PER_PRESET:
		return null
	var p: GPUParticles3D = _create(preset)
	_host.add_child(p)
	pool.append(p)
	_pools[preset] = pool
	return p


static func _create(preset: String) -> GPUParticles3D:
	var cfg: Dictionary = PRESETS[preset]
	var p: GPUParticles3D = GPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(cfg.amount)
	p.lifetime = float(cfg.life)
	p.explosiveness = 0.95
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	p.process_material = (_process_material(preset) as ParticleProcessMaterial).duplicate()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _draw_material(preset)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _process_material(preset: String) -> ParticleProcessMaterial:
	if not _process_materials.has(preset):
		var cfg: Dictionary = PRESETS[preset]
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.direction = Vector3(1, 0, 0) if cfg.get("flat", false) else Vector3(0, 1, 0)
		pm.spread = float(cfg.spread)
		if cfg.get("flat", false):
			pm.particle_flag_align_y = false
			pm.direction = Vector3(1, 0.05, 0)
		pm.gravity = Vector3(0, float(cfg.gravity), 0)
		pm.damping_min = 2.0
		pm.damping_max = 4.0
		pm.scale_min = cfg.size.x
		pm.scale_max = cfg.size.y
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		# 淡出：透明度随生命周期从 1 到 0
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		var tex: GradientTexture1D = GradientTexture1D.new()
		tex.gradient = ramp
		pm.color_ramp = tex
		var shrink: Curve = Curve.new()
		shrink.add_point(Vector2(0, 1))
		shrink.add_point(Vector2(1, 0.4))
		var curve_tex: CurveTexture = CurveTexture.new()
		curve_tex.curve = shrink
		pm.scale_curve = curve_tex
		_process_materials[preset] = pm
	return _process_materials[preset]


static func _draw_material(preset: String) -> StandardMaterial3D:
	if not _draw_materials.has(preset):
		var cfg: Dictionary = PRESETS[preset]
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = load(TEX_DIR + String(cfg.tex))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if cfg.additive else BaseMaterial3D.BLEND_MODE_MIX
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_draw_materials[preset] = mat
	return _draw_materials[preset]
