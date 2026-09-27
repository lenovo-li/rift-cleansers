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
static func whirlwind(parent: Node, caster: Node3D, radius: float, duration: float) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = radius - 0.3
	mesh.outer_radius = radius
	mesh_instance.mesh = mesh
	var mat: StandardMaterial3D = _make_material(WHIRL_COLOR)
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
		mat.albedo_color.a = 0.3 * (1.0 - elapsed / duration)
	
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()


## 地面火焰特效
static func ground_zone(parent: Node, a: Vector3, b: Vector3, half_width: float, duration: float) -> void:
	var dir: Vector3 = b - a
	dir.y = 0.0
	var length: float = dir.length()
	
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	if length < 0.01:
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = half_width
		mesh.bottom_radius = half_width
		mesh.height = 0.1
		mesh_instance.mesh = mesh
		mesh_instance.global_position = a
	else:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(length, 0.1, half_width * 2.0)
		mesh_instance.mesh = mesh
		mesh_instance.global_position = (a + b) * 0.5
		mesh_instance.look_at(b, Vector3.UP)
	
	mesh_instance.global_position.y = 0.05
	var mat: StandardMaterial3D = _make_material(FLAME_COLOR)
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	
	# 淡出
	var elapsed: float = 0.0
	while elapsed < duration and is_instance_valid(mesh_instance):
		await parent.get_tree().process_frame
		elapsed += parent.get_tree().root.get_process_delta_time()
		mat.albedo_color.a = 0.4 * (1.0 - elapsed / duration)
	
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()
