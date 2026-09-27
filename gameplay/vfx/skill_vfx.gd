extends Node3D
## 视觉特效管理器 - 创建临时特效节点

## 创建盾击锥形特效（前方蓝色半透明锥形，0.3秒消失）
static func create_shield_bash_vfx(origin: Vector3, facing: Vector3, range: float, cone_angle: float) -> void:
	var scene_root: Node = Engine.get_main_loop().root.get_child(0)
	
	# 创建锥形网格
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = range * tan(cone_angle)
	mesh.bottom_radius = 0.01
	mesh.height = range
	mesh_instance.mesh = mesh
	
	# 半透明蓝色材质
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.5, 1.0, 0.4)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.set_surface_override_material(0, material)
	
	# 位置和朝向
	scene_root.add_child(mesh_instance)
	mesh_instance.global_position = origin + facing * range * 0.5
	mesh_instance.global_position.y += 0.5
	
	# 让锥形朝向facing方向（锥尖朝origin）
	var target: Vector3 = origin + facing * range
	mesh_instance.look_at(target, Vector3.UP)
	mesh_instance.rotate_object_local(Vector3.RIGHT, PI / 2)
	
	# 0.3秒后删除
	await scene_root.get_tree().create_timer(0.3).timeout
	mesh_instance.queue_free()


## 创建旋风斩圆环特效（跟随施法者的半透明圆环）
static func create_whirlwind_vfx(caster: Node3D, radius: float, duration: float) -> void:
	var scene_root: Node = Engine.get_main_loop().root.get_child(0)
	
	# 创建圆环（扁平圆柱）
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.2
	mesh_instance.mesh = mesh
	
	# 半透明绿色材质
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 1.0, 0.3, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.set_surface_override_material(0, material)
	
	scene_root.add_child(mesh_instance)
	mesh_instance.global_position = caster.global_position
	mesh_instance.global_position.y = 0.1
	
	# 持续旋转并跟随施法者
	var elapsed: float = 0.0
	while elapsed < duration and is_instance_valid(mesh_instance):
		await scene_root.get_tree().process_frame
		var delta: float = scene_root.get_tree().process_frame
		elapsed += delta
		
		if is_instance_valid(caster):
			mesh_instance.global_position = caster.global_position
			mesh_instance.global_position.y = 0.1
			mesh_instance.rotate_y(delta * 3.0)
		
		# 淡出
		var alpha: float = 0.3 * (1.0 - elapsed / duration)
		material.albedo_color.a = alpha
	
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()


## 创建地面持续伤害区域显示（半透明红色区域）
static func create_ground_zone_vfx(zone_a: Vector3, zone_b: Vector3, half_width: float, duration: float) -> void:
	var scene_root: Node = Engine.get_main_loop().root.get_child(0)
	
	# 计算线段方向和长度
	var direction: Vector3 = zone_b - zone_a
	direction.y = 0.0
	var length: float = direction.length()
	
	if length < 0.01:
		# 点或圆形区域：用圆柱
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = half_width
		mesh.bottom_radius = half_width
		mesh.height = 0.1
		mesh_instance.mesh = mesh
		
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.3, 0.0, 0.4)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.set_surface_override_material(0, material)
		
		scene_root.add_child(mesh_instance)
		mesh_instance.global_position = zone_a
		mesh_instance.global_position.y = 0.05
		
		# 淡出并删除
		var elapsed: float = 0.0
		while elapsed < duration and is_instance_valid(mesh_instance):
			await scene_root.get_tree().process_frame
			elapsed += scene_root.get_tree().process_frame
			material.albedo_color.a = 0.4 * (1.0 - elapsed / duration)
		
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
	else:
		# 线段区域：用长方体
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(length, 0.1, half_width * 2.0)
		mesh_instance.mesh = mesh
		
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.3, 0.0, 0.4)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.set_surface_override_material(0, material)
		
		scene_root.add_child(mesh_instance)
		var center: Vector3 = (zone_a + zone_b) * 0.5
		center.y = 0.05
		mesh_instance.global_position = center
		mesh_instance.look_at(zone_b, Vector3.UP)
		
		# 淡出并删除
		var elapsed: float = 0.0
		while elapsed < duration and is_instance_valid(mesh_instance):
			await scene_root.get_tree().process_frame
			elapsed += scene_root.get_tree().process_frame
			material.albedo_color.a = 0.4 * (1.0 - elapsed / duration)
		
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
