class_name SkillVfx extends RefCounted
## 技能视觉特效助手

const CONE_COLOR: Color = Color(0.3, 0.6, 1.0, 0.4)
const WHIRL_COLOR: Color = Color(0.3, 1.0, 0.4, 0.3)
const FLAME_COLOR: Color = Color(1.0, 0.35, 0.05, 0.4)

## 联机：主机设置后，每次调用特效都会把参数交给 recorder(event: Array)，由 NetSession 转发给客户端回放。
static var recorder: Callable = Callable()


static func record(event: Array) -> void:
	if recorder.is_valid():
		recorder.call(event)


static func _make_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## 盾击特效：前方扇形
static func shield_bash(parent: Node, origin: Vector3, facing: Vector3, radius: float, color: Color = CONE_COLOR) -> void:
	record(["cone", origin, facing, radius, color])
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * tan(PI / 4.0)
	mesh.bottom_radius = 0.01
	mesh.height = radius
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color)
	
	parent.add_child(mesh_instance)
	mesh_instance.global_position = origin + facing * radius * 0.5
	mesh_instance.global_position.y = 0.5
	mesh_instance.look_at(origin + facing * radius, Vector3.UP)
	mesh_instance.rotate_object_local(Vector3.RIGHT, PI / 2)
	
	await parent.get_tree().create_timer(0.3).timeout
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()


## 旋风斩特效：跟随的圆环
static func whirlwind(parent: Node, caster: Node3D, radius: float, duration: float, color: Color = WHIRL_COLOR) -> void:
	record(["whirl", int(caster.get("net_slot")), radius, duration, color])
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = radius - 0.3
	mesh.outer_radius = radius
	mesh_instance.mesh = mesh
	var mat: StandardMaterial3D = _make_material(color)
	mesh_instance.material_override = mat
	
	parent.add_child(mesh_instance)
	mesh_instance.global_position = caster.global_position
	mesh_instance.global_position.y = 0.3
	
	# 跟随并旋转
	var elapsed: float = 0.0
	while elapsed < duration and is_instance_valid(mesh_instance) and is_instance_valid(caster):
		await parent.get_tree().process_frame
		elapsed += parent.get_tree().root.get_process_delta_time()
		
		mesh_instance.global_position = caster.global_position
		mesh_instance.global_position.y = 0.3
		mesh_instance.rotate_y(parent.get_tree().root.get_process_delta_time() * 5.0)
		mat.albedo_color.a = color.a * (1.0 - elapsed / duration)
	
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()


## 地面火焰特效
static func ground_zone(parent: Node, a: Vector3, b: Vector3, half_width: float, duration: float, color: Color = FLAME_COLOR) -> void:
	record(["zone", a, b, half_width, duration, color])
	var dir: Vector3 = b - a
	dir.y = 0.0
	var length: float = dir.length()
	
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mat: StandardMaterial3D = _make_material(color)
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	if length < 0.01:
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = half_width
		mesh.bottom_radius = half_width
		mesh.height = 0.1
		mesh_instance.mesh = mesh
		mesh_instance.global_position = Vector3(a.x, 0.05, a.z)
	else:
		# 线段两端各延伸 half_width（与 GroundZone 的胶囊判定大致一致）
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(half_width * 2.0, 0.1, length + half_width * 2.0)
		mesh_instance.mesh = mesh
		var mid: Vector3 = (a + b) * 0.5
		mesh_instance.global_transform = Transform3D(Basis.looking_at(dir / length, Vector3.UP), Vector3(mid.x, 0.05, mid.z))
	
	# 淡出
	var elapsed: float = 0.0
	while elapsed < duration and is_instance_valid(mesh_instance):
		await parent.get_tree().process_frame
		elapsed += parent.get_tree().root.get_process_delta_time()
		mat.albedo_color.a = color.a * (1.0 - elapsed / duration)
	
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()


## 一次性扩散圆盘：从 0 扩到 radius 并淡出（嘲讽、震地、爆燃、碎裂、治疗、爆炸等）。
static func pulse_ring(parent: Node, center: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	record(["ring", center, radius, color, duration])
	if parent == null or not parent.is_inside_tree():
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.06
	cyl.radial_segments = 32
	mi.mesh = cyl
	var mat: StandardMaterial3D = _make_material(color)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = Vector3(center.x, 0.08, center.z)
	mi.scale = Vector3(0.1, 1.0, 0.1)
	var tween: Tween = mi.create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(radius, 1.0, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mi.queue_free)


## 冲锋拖尾：起点到终点的长条，快速淡出。
static func dash_trail(parent: Node, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	record(["trail", a, b, width, color])
	if parent == null or not parent.is_inside_tree() or a.distance_to(b) < 0.1:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(width, 0.05, a.distance_to(b))
	mi.mesh = box
	var mat: StandardMaterial3D = _make_material(color)
	mi.material_override = mat
	parent.add_child(mi)
	var mid: Vector3 = (a + b) * 0.5
	mi.global_transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), Vector3(mid.x, 0.06, mid.z))
	var tween: Tween = mi.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(mi.queue_free)


# ---------- M3：打击感特效（全部经 record 录制，联机客户端同样回放） ----------

const ShockwaveShader: Shader = preload("res://presentation/shaders/shockwave.gdshader")
const DissolveShader: Shader = preload("res://presentation/shaders/dissolve.gdshader")
const MAX_GHOSTS: int = 40

static var _shock_mat: ShaderMaterial = null
static var _dissolve_mat: ShaderMaterial = null
static var _noise: NoiseTexture2D = null
static var _ghosts: int = 0


static func _noise_tex() -> NoiseTexture2D:
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.width = 128
		_noise.height = 128
		_noise.seamless = true
		var fn: FastNoiseLite = FastNoiseLite.new()
		fn.frequency = 0.05
		_noise.noise = fn
	return _noise


## 冲击波环：从中心扩散到 radius，带噪声扰动（震地、盾击 5 段、爆燃、Boss 阶段）。
static func shockwave(parent: Node, center: Vector3, radius: float, color: Color, duration: float = 0.45) -> void:
	record(["shock", center, radius, color, duration])
	if parent == null or not parent.is_inside_tree():
		return
	if _shock_mat == null:
		_shock_mat = ShaderMaterial.new()
		_shock_mat.shader = ShockwaveShader
		_shock_mat.set_shader_parameter("noise_tex", _noise_tex())
	var mi: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(radius * 2.2, radius * 2.2)
	mi.mesh = plane
	mi.material_override = _shock_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(center.x, 0.1, center.z)
	mi.set_instance_shader_parameter("wave_color", color)
	mi.set_instance_shader_parameter("progress", 0.0)
	var tw: Tween = mi.create_tween()
	# 线性时间；半径的 ease-out 在 shader 里做，淡出不会被提前
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("progress", v), 0.0, 1.0, duration)
	tw.tween_callback(mi.queue_free)


## 粒子爆发（见 ParticleFx.PRESETS）。
static func burst(parent: Node, preset: String, pos: Vector3, scale: float = 1.0, color: Color = Color(0, 0, 0, 0)) -> void:
	record(["burst", preset, pos, scale, color])
	ParticleFx.burst(parent, preset, pos, scale, color)


## 锯齿电弧（盾击 3 段连锁）：a 到 b 之间 4 段折线，闪两下后消失。
static func arc(parent: Node, a: Vector3, b: Vector3, color: Color) -> void:
	record(["arc", a, b, color])
	if parent == null or not parent.is_inside_tree():
		return
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	var mat: StandardMaterial3D = _make_material(color)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var points: Array[Vector3] = [a + Vector3(0, 1, 0)]
	var side: Vector3 = (b - a).cross(Vector3.UP).normalized()
	for i in range(1, 4):
		points.append(a.lerp(b, i / 4.0) + Vector3(0, 1, 0) + side * randf_range(-0.5, 0.5))
	points.append(b + Vector3(0, 1, 0))
	for i in points.size() - 1:
		var seg: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		var length: float = points[i].distance_to(points[i + 1])
		box.size = Vector3(0.12, 0.12, length)
		seg.mesh = box
		seg.material_override = mat
		root.add_child(seg)
		var mid: Vector3 = (points[i] + points[i + 1]) * 0.5
		seg.global_transform = Transform3D(Basis.looking_at((points[i + 1] - points[i]).normalized(), Vector3.UP), mid)
	var tw: Tween = root.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.2, 0.05)
	tw.tween_property(mat, "albedo_color:a", color.a, 0.05)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tw.tween_callback(root.queue_free)


## 敌人死亡：原地留下一个溶解中的残影 + 碎屑。同时存在的残影有上限，超出时只放碎屑。
## 不录制：联机客户端收到 "dead" 事件时用自己的敌人视图网格播放同一效果。
static func death(parent: Node, pos: Vector3, mesh: Mesh, height: float, color: Color, elite: bool, scale: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mid: Vector3 = pos + Vector3(0, maxf(height, 0.8 * scale), 0)
	ParticleFx.burst(parent, "debris", mid, 1.3 if elite else 0.8, color.darkened(0.2))
	if elite:
		ParticleFx.burst(parent, "star", mid, 1.2, color)
	if mesh == null or _ghosts >= MAX_GHOSTS or DisplayServer.get_name() == "headless":
		return
	if _dissolve_mat == null:
		_dissolve_mat = ShaderMaterial.new()
		_dissolve_mat.shader = DissolveShader
		_dissolve_mat.set_shader_parameter("noise_tex", _noise_tex())
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _dissolve_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, height, 0)
	mi.scale = Vector3.ONE * scale
	# 低模（ArrayMesh）自带顶点色，不再叠加代表色；灰盒胶囊没有顶点色，用代表色
	mi.set_instance_shader_parameter("base_color", color if mesh is PrimitiveMesh else Color.WHITE)
	_ghosts += 1
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("progress", v), 0.0, 1.0, 0.35)
	tw.tween_property(mi, "scale", Vector3(1.15, 0.7, 1.15) * scale, 0.35)
	tw.chain().tween_callback(func() -> void:
		_ghosts -= 1
		mi.queue_free())


static func reset_counters() -> void:
	_ghosts = 0


## 震屏。slot >= 0 时只震该槽位玩家的屏幕（联机时由主机转发给对应客户端）。
static func shake(tree: SceneTree, strength: float, _slot: int = -1) -> void:
	shake_local(tree, strength)


static func shake_local(tree: SceneTree, strength: float) -> void:
	if tree == null or tree.root == null:
		return
	var cam: Camera3D = tree.root.get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(strength)


## 盾击四段视觉进化（文档 05 §5「四档视觉成长」）：
## 1 段 小而清楚：蓝色扇形 + 火花；3 段 更亮 + 连锁电弧（由技能结果给出）；
## 5 段 形态质变：扇形变大 + 蓝色冲击波；8 段 环境级：橙红扇形 + 火焰 + 大冲击波。
static func shield_bash_tiered(parent: Node, origin: Vector3, facing: Vector3, radius: float, tier: int,
		hit_points: Array, chain_links: Array) -> void:
	var cone: Color = CONE_COLOR
	match tier:
		3: cone = Color(0.45, 0.75, 1.0, 0.55)
		5: cone = Color(0.55, 0.85, 1.0, 0.6)
		8: cone = Color(1.0, 0.5, 0.15, 0.6)
	shield_bash(parent, origin, facing, radius, cone)
	for p: Vector3 in hit_points:
		burst(parent, "spark", p + Vector3(0, 1, 0), 1.0 if tier < 8 else 1.3,
				Color(1.0, 0.6, 0.2) if tier >= 8 else Color(0.7, 0.9, 1.0))
	for link: Array in chain_links:
		arc(parent, link[0], link[1], Color(0.6, 0.85, 1.0, 0.9))
	if tier >= 5:
		shockwave(parent, origin + facing * radius * 0.6, radius * 1.5,
				Color(1.0, 0.55, 0.2, 1.0) if tier >= 8 else Color(0.5, 0.8, 1.0, 1.0))
	if tier >= 8:
		for i in 3:
			burst(parent, "fire", origin + facing * radius * (0.3 + 0.3 * i), 1.0)


## 预警圈：地面红色闪烁圆圈（陨石术即将落地）。
static func telegraph_circle(parent: Node, center: Vector3, radius: float, duration: float) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = center + Vector3(0, 0.03, 0)
	mi.material_override = _make_material(Color(1.0, 0.2, 0.1, 0.4))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var t: Tween = mi.create_tween()
	t.set_loops(ceili(duration / 0.6))
	t.tween_property(mi, "transparency", 0.8, 0.3)
	t.tween_property(mi, "transparency", 0.0, 0.3)
	await parent.get_tree().create_timer(duration).timeout
	if is_instance_valid(mi):
		mi.queue_free()


## 陨石落地爆炸（冲击波 + 火焰爆裂 + 可选的第二圈冲击波）。
static func meteor_impact(parent: Node, center: Vector3, radius: float, second_wave: bool) -> void:
	shockwave(parent, center, radius, Color(1.0, 0.4, 0.1, 1.0), 0.5)
	burst(parent, "fire", center + Vector3(0, 0.8, 0), radius * 0.15, Color(1.0, 0.5, 0.1))
	if second_wave:
		await parent.get_tree().create_timer(0.25).timeout
		if is_instance_valid(parent):
			shockwave(parent, center, radius * 1.6, Color(1.0, 0.5, 0.2, 0.6), 0.4)
