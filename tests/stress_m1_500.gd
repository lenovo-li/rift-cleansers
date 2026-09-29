extends SceneTree
## M1 压力测试（文档 07 退出条件「500 敌人 @ 60 FPS」）：真实游戏场景 + 真实敌人节点，渲染开启。
## 用法（不要加 --headless，需要真实渲染）:
##   godot --path . --script res://tests/stress_m1_500.gd -- --count=500 --seconds=15
## 前 5 秒热身不计入；输出平均 FPS、1% 低帧、物理耗时平均值和 P99。

var _count: int = 500
var _seconds: float = 15.0
var _warmup: float = 5.0
var _elapsed: float = 0.0
var _frame_times: Array[float] = []
var _physics_times: Array[float] = []
var _scene: Node = null
var _player: Node = null
var _done: bool = false


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			_count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_scene = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_scene.auto_pick_upgrades = true
	var director: SpawnDirector = _scene.get_node("GameSession/SpawnDirector") as SpawnDirector
	director.stress_cap = _count
	root.add_child(_scene)
	_player = _scene.get_node("PlayerM1")
	print("[stress] count=%d seconds=%.0f" % [_count, _seconds])


func _process(delta: float) -> bool:
	if _done:
		return true
	# 玩家不死、绕圈移动，敌人持续追击和挨打
	_player.stats.health = _player.stats.max_health
	_elapsed += delta
	var a: float = _elapsed * 0.5
	_player.move_override = Vector3(-sin(a), 0, cos(a))
	if _elapsed > _warmup:
		_frame_times.append(delta)
		_physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if _elapsed >= _warmup + _seconds:
		_finish()
	return false


func _finish() -> void:
	_done = true
	var enemies: int = get_nodes_in_group("enemies").size()
	var sorted: Array[float] = _frame_times.duplicate()
	sorted.sort()
	var total: float = 0.0
	for t: float in _frame_times:
		total += t
	var avg_fps: float = _frame_times.size() / total
	var worst: Array[float] = sorted.slice(int(sorted.size() * 0.99))
	var worst_avg: float = 0.0
	for t: float in worst:
		worst_avg += t
	var low_fps: float = worst.size() / worst_avg if worst_avg > 0.0 else 0.0
	var physics_ms: float = 0.0
	for t: float in _physics_times:
		physics_ms += t
	physics_ms /= maxf(1.0, _physics_times.size())
	_physics_times.sort()
	var physics_p99: float = _physics_times[int(_physics_times.size() * 0.99)]
	var ok: bool = avg_fps >= 60.0
	print("[stress] enemies=%d avg_fps=%.1f 1%%low=%.1f physics_avg=%.2fms physics_p99=%.2fms frames=%d -> %s" % [
		enemies, avg_fps, low_fps, physics_ms, physics_p99, _frame_times.size(), "PASS" if ok else "FAIL"])
	paused = false
	quit(0 if ok else 1)
