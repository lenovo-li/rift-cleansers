extends Node3D
## 敌人管理器 - MultiMesh批量渲染
## 这是M0性能测试的核心

@export var enemy_count: int = 1000
@export var spawn_radius: float = 80.0
@export var move_speed: float = 5.0
@export var grid_cell_size: float = 10.0

class EnemyData:
	var id: int
	var position: Vector3
	var velocity: Vector3

var _enemies: Array[EnemyData] = []
var _spatial_grid: SpatialGrid = null
var _multimesh: MultiMeshInstance3D = null


func _ready() -> void:
	_spatial_grid = SpatialGrid.new(grid_cell_size)
	
	# 【关键】创建MultiMesh - 这让1000敌人只用1次Draw Call
	_multimesh = MultiMeshInstance3D.new()
	_multimesh.multimesh = MultiMesh.new()
	_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.multimesh.instance_count = enemy_count
	
	# 简单方块mesh
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	_multimesh.multimesh.mesh = box
	
	# 红色材质
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	_multimesh.material_override = mat
	
	add_child(_multimesh)
	
	# 生成敌人数据（轻量级，不是Node）
	for i in enemy_count:
		var angle: float = randf() * TAU
		var dist: float = randf() * spawn_radius
		var pos: Vector3 = Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
		
		var enemy: EnemyData = EnemyData.new()
		enemy.id = i
		enemy.position = pos
		enemy.velocity = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * move_speed
		_enemies.append(enemy)
	
	print("[enemy_manager] spawned %d enemies using MultiMesh" % enemy_count)


func _physics_process(delta: float) -> void:
	_spatial_grid.clear()
	
	# 批量更新所有敌人
	for i in _enemies.size():
		var e: EnemyData = _enemies[i]
		
		# 简单移动
		e.position += e.velocity * delta
		
		# 边界反弹
		if abs(e.position.x) > spawn_radius:
			e.velocity.x *= -1
		if abs(e.position.z) > spawn_radius:
			e.velocity.z *= -1
		
		# 【关键】更新MultiMesh Transform
		var t: Transform3D = Transform3D()
		t.origin = e.position
		_multimesh.multimesh.set_instance_transform(i, t)
		
		# 插入空间网格（用于范围查询）
		_spatial_grid.insert(e.id, e.position)


func get_enemy_count() -> int:
	return _enemies.size()


func get_spatial_grid() -> SpatialGrid:
	return _spatial_grid
