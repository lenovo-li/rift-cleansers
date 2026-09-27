class_name SpawnDirector extends Node
## 生成导演 - 控制敌人刷怪节奏

signal wave_spawned(enemy_count: int)

@export var max_budget: int = 50
@export var base_spawn_interval: float = 4.0

var current_budget: int = 0
var spawn_timer: float = 0.0
var game_session: GameSession = null


func initialize(session: GameSession) -> void:
	game_session = session
	spawn_timer = base_spawn_interval


func _process(delta: float) -> void:
	if game_session == null or not game_session.is_running:
		return
	
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = base_spawn_interval
		try_spawn_wave()


func try_spawn_wave() -> void:
	if current_budget >= max_budget:
		return
	
	var game_time: float = game_session.get_game_time()
	var spawn_count: int = get_spawn_count_for_time(game_time)
	
	if current_budget + spawn_count <= max_budget:
		wave_spawned.emit(spawn_count)
		current_budget += spawn_count


func get_spawn_count_for_time(time: float) -> int:
	if time < 60.0:
		return randi_range(2, 3)
	elif time < 180.0:
		return randi_range(3, 5)
	elif time < 300.0:
		return randi_range(5, 8)
	else:
		return randi_range(8, 12)


func on_enemy_died() -> void:
	current_budget = max(0, current_budget - 1)
