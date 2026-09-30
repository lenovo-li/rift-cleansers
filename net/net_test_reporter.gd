extends Node
## 联机测试用：命令行带 --net-report=路径 时每秒把 NetSession.report() 追加到 JSON 文件，
## --quit-after=秒 到时退出。由 tests/net_smoke.py 启动两个进程后对比主机和客户端的记录。

var _path: String = ""
var _quit_after: float = -1.0
var _elapsed: float = 0.0
var _next: float = 1.0
var _history: Array = []
var _net: NetSession = null
var _immortal: bool = false
var _shot_path: String = ""
var _shot_at: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--net-report="):
			_path = arg.get_slice("=", 1)
		elif arg.begins_with("--quit-after="):
			_quit_after = float(arg.get_slice("=", 1))
		elif arg.begins_with("--screenshot="):
			# --screenshot=路径@秒：到时截图（打开 F3 调试面板）
			var spec: String = arg.get_slice("=", 1)
			_shot_path = spec.get_slice("@", 0)
			_shot_at = float(spec.get_slice("@", 1))
		elif arg.begins_with("--stress="):
			# 压力测试：主机把敌人数量维持在 N，玩家不会死
			var director: SpawnDirector = get_parent().get_node("GameSession/SpawnDirector") as SpawnDirector
			director.stress_cap = int(arg.get_slice("=", 1))
			_immortal = true
	if _path.is_empty() and _quit_after < 0.0 and _shot_path.is_empty():
		queue_free()


func _process(delta: float) -> void:
	_elapsed += delta
	if _immortal and not NetConfig.is_client():
		for p: Node in get_tree().get_nodes_in_group("players"):
			p.stats.health = p.stats.max_health
	if _net == null:
		_net = get_parent().get("net") as NetSession
	if _elapsed >= _next and _net != null and not _path.is_empty():
		_next += 1.0
		var r: Dictionary = _net.report()
		r["wall"] = Time.get_unix_time_from_system()
		_history.append(r)
		var f: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_history))
			f.close()
	if not _shot_path.is_empty() and _elapsed >= _shot_at - 0.5 and _shot_at > 0.0:
		var hud: Node = get_parent().get_node("UI/HUD")
		if not hud._debug_label.visible:
			hud.toggle_debug()
		if _elapsed >= _shot_at:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			_shot_at = -1.0
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		get_tree().quit(0)
