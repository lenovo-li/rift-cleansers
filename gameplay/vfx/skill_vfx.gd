class_name SkillVfx extends RefCounted
## 技能视觉特效助手

const CONE_COLOR: Color = Color(0.3, 0.6, 1.0, 0.4)
const WHIRL_COLOR: Color = Color(0.3, 1.0, 0.4, 0.3)
const FLAME_COLOR: Color = Color(1.0, 0.35, 0.05, 0.4)


static func _make_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## 盾击特效：前方扇形
static func shield_bash(parent: Node, origin: Vector3, facing: Vector3, radius: float) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * tan(PI / 4.0)
	mesh.bottom_radius = 0.01
	mesh.height = radius
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(CONE_COLOR)
	
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
