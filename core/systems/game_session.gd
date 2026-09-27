class_name GameSession extends Node
## 游戏会话管理器

signal game_started
signal game_over(reason: String)
signal level_up(new_level: int)

var game_time: float = 0.0
var is_running: bool = false
var player_level: int = 1
var player_exp: float = 0.0


func start_game() -> void:
	game_time = 0.0
	is_running = true
	player_level = 1
	player_exp = 0.0
	game_started.emit()


func _process(delta: float) -> void:
	if not is_running:
		return
	game_time += delta
	
	if game_time >= 600.0:  # 10分钟
		end_game("time_up")


func end_game(reason: String) -> void:
	if not is_running:
		return
	is_running = false
	game_over.emit(reason)


func add_experience(amount: float) -> void:
	player_exp += amount * get_exp_multiplier()
	
	var required: float = get_exp_required(player_level)
	while player_exp >= required:
		player_exp -= required
		player_level += 1
		level_up.emit(player_level)
		required = get_exp_required(player_level)


func get_exp_required(level: int) -> float:
	return 20.0 + float(level) * 8.0


func get_exp_multiplier() -> float:
	if game_time < 60.0:
		return 3.0
	elif game_time < 180.0:
		return 2.0
	return 1.0


func get_game_time() -> float:
	return game_time


func get_player_level() -> int:
	return player_level


func get_player_exp() -> float:
	return player_exp
