extends SceneTree
## 模拟测试：玩家站桩不动跑完第 1 分钟，验证文档 05 §6.1「第1分钟升级3-5次」。
## 用法（--fixed-fps 让每帧固定 1/60 秒，headless 下全速跑完）:
##   godot --headless --fixed-fps 60 --path . --script res://tests/sim_first_minute.gd
## 可选参数（写在 -- 之后）: --seconds=N --seed=N

const MIN_LEVEL: int = 4
const MAX_LEVEL: int = 6

var _session: GameSession = null
var _player: Node = null
var _seconds: float = 60.0
var _kills: int = 0
var _next_report: float = 10.0
var _done: bool = false


func _init() -> void:
	var sim_seed: int = 12345
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			sim_seed = int(arg.get_slice("=", 1))
	seed(sim_seed)

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--char="):
			NetConfig.character_id = arg.get_slice("=", 1)
	print("[sim] character=%s" % NetConfig.character_id)
	var scene: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	scene.auto_pick_upgrades = true  # 升级面板会暂停场景树，模拟里直接选第一项
	scene.record_runs = false
	root.add_child(scene)
	_session = scene.get_node("GameSession") as GameSession
	_player = scene.get_node("PlayerM1")
	var director: SpawnDirector = scene.get_node("GameSession/SpawnDirector") as SpawnDirector
	assert(director != null)
	print("[sim] seed=%d seconds=%.0f" % [sim_seed, _seconds])


func _process(_delta: float) -> bool:
	if _done:
		return true
	if _session == null or not _session.is_running:
		# 还没开始，或者提前结束（死亡）
		if _session != null and _session.get_game_time() > 0.0:
			return _finish("session ended early")
		return false
	var t: float = _session.get_game_time()
	if t >= _next_report:
		_report(t)
		_next_report += 10.0
	if t >= _seconds:
		return _finish("time reached")
	return false


func _report(t: float) -> void:
	var enemies: int = get_nodes_in_group("enemies").size()
	print("[sim] t=%5.1fs level=%d exp=%.0f hp=%.0f enemies=%d" % [
		t, _session.get_player_level(), _session.get_player_exp(),
		_player.get_health(), enemies])


func _finish(reason: String) -> bool:
	_done = true
	var level: int = _session.get_player_level()
	_report(_session.get_game_time())
	var ok: bool = level >= MIN_LEVEL and level <= MAX_LEVEL and _player.get_health() > 0.0
	print("[sim] %s -> level=%d (期望 %d-%d), hp=%.0f: %s" % [
		reason, level, MIN_LEVEL, MAX_LEVEL, _player.get_health(), "PASS" if ok else "FAIL"])
	quit(0 if ok else 1)
	return true
