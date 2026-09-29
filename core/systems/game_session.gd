class_name GameSession extends Node
## 游戏会话：计时、暂停、经验与升级、胜负。
## 目标 10 分钟：9:00 Boss 登场，击败 Boss 胜利；玩家死亡失败。

signal game_started
signal game_over(reason: String, victory: bool)
signal level_up(new_level: int)

var game_time: float = 0.0
var is_running: bool = false
var victory: bool = false
var end_reason: String = ""
var player_level: int = 1
var player_exp: float = 0.0
## 多人：返回玩家人数。等级共享、击杀数约为人数倍，经验按人数均分以保持单人的升级节奏。
var player_count_provider: Callable = Callable()


func start_game() -> void:
	game_time = 0.0
	is_running = true
	victory = false
	end_reason = ""
	player_level = 1
	player_exp = 0.0
	game_started.emit()


func _process(delta: float) -> void:
	if not is_running:
		return
	game_time += delta


func end_game(reason: String, is_victory: bool = false) -> void:
	if not is_running:
		return
	is_running = false
	victory = is_victory
	end_reason = reason
	game_over.emit(reason, is_victory)


func add_experience(amount: float) -> void:
	if not is_running:
		return
	var n: int = maxi(1, int(player_count_provider.call())) if player_count_provider.is_valid() else 1
	player_exp += amount * get_exp_multiplier() / float(n)

	var required: float = get_exp_required(player_level)
	while player_exp >= required:
		player_exp -= required
		player_level += 1
		level_up.emit(player_level)
		required = get_exp_required(player_level)


## 文档 05 §2.2 的 20 + 8L，再加 0.6L² 让中后期放缓（目标：5 分钟 Lv15-20，10 分钟 Lv25-30）。
func get_exp_required(level: int) -> float:
	return 20.0 + float(level) * 8.0 + 0.6 * float(level * level)


func get_exp_multiplier() -> float:
	# 文档 05 §2.2：前 1 分钟双倍，1-3 分钟 1.5 倍
	if game_time < 60.0:
		return 2.0
	elif game_time < 180.0:
		return 1.5
	return 1.0


func get_game_time() -> float:
	return game_time


func get_player_level() -> int:
	return player_level


func get_player_exp() -> float:
	return player_exp
