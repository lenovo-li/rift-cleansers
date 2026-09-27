extends Node3D
## M1 敌人管理器 - 动态生成敌人

const EnemyScene: PackedScene = preload("res://gameplay/actors/enemy.tscn")

@export var initial_count: int = 10
@export var spawn_radius: float = 20.0

var _active_enemies: Array[Node3D] = []
var _next_id: int = 1000
var _player: Node3D = null


func _ready() -> void:
	await get_tree().process_frame
	
	_player = get_tree().root.find_child("PlayerM1", true, false)
	
	# 连接SpawnDirector
	var spawn_dir: Node = get_tree().root.find_child("SpawnDirector", true, false)
	if spawn_dir:
		spawn_dir.wave_spawned.connect(_on_wave_spawned)
	
	# 初始生成
	spawn_enemies(initial_count)


func spawn_enemies(count: int) -> void:
	if _player == null:
		_player = get_tree().root.find_child("PlayerM1", true, false)
	
	for i in count:
		var enemy: CharacterBody3D = EnemyScene.instantiate()
		
		# 在玩家周围生成
		var angle: float = randf() * TAU
		var distance: float = spawn_radius + randf() * 10.0
		var offset: Vector3 = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		
		if _player:
			enemy.global_position = _player.global_position + offset
		
		enemy.entity_id = _next_id
		_next_id += 1
		
		add_child(enemy)
		_active_enemies.append(enemy)


func _on_wave_spawned(count: int) -> void:
	spawn_enemies(count)


func get_enemy_count() -> int:
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))
	return _active_enemies.size()
