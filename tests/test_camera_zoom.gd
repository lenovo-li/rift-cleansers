extends SceneTree
## 镜头缩放和 Boss 箭头指示测试：开局 5 秒后刷 Boss，测试箭头是否正确显示，并模拟滚轮缩放。
## 用法: godot --fixed-fps 60 --path . --script res://tests/test_camera_zoom.gd

var _scene: Node = null
var _session: GameSession = null
var _player: Node = null
var _spawner: Node = null
var _camera: Camera3D = null
var _hud: Control = null
var _done: bool = false
var _test_time: float = 0.0
var _zoom_tested: bool = false
var _arrow_tested: bool = false
var _expire_tested: bool = false
var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print("[test_camera] %s %s" % ["✅" if ok else "❌", what])
	if not ok:
		_failures += 1


func _init() -> void:
	seed(42)
	NetConfig.map_id = "ashen_city"
	NetConfig.character_id = "iron_guard"
	Talents.enabled = false
	_scene = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_scene.auto_pick_upgrades = true
	_scene.record_runs = false
	root.add_child(_scene)
	_session = _scene.get_node("GameSession") as GameSession
	_player = _scene.get_node("PlayerM1")
	_spawner = _scene.get_node("EnemySpawner")
	_camera = _scene.get_node("Camera")
	_hud = _scene.get_node("UI/HUD")
	_player.ai_controlled = false  # 玩家静止不动
	_session.game_over.connect(_on_game_over)
	print("[test_camera] 开始测试镜头缩放和 Boss 箭头指示")


func _process(_delta: float) -> bool:
	if _done:
		return true
	if not _session.is_running:
		return false

	var t: float = _session.get_game_time()
	_test_time = t

	# 5 秒后刷 Boss
	if t > 5.0 and _spawner.bosses.is_empty():
		print("[test_camera] t=%.1fs 刷出 Boss" % t)
		var boss: Node = _spawner.spawn_boss(0)
		# 把 Boss 移到玩家视野外
		boss.global_position = _player.global_position + Vector3(40, 0, 40)
		print("[test_camera] Boss 位置: %s" % boss.global_position)

	# 测试镜头缩放（8-12 秒）
	if t > 8.0 and t < 12.0 and not _zoom_tested:
		_test_zoom()
		_zoom_tested = true

	# 测试箭头指示（Boss 5 秒刷出，箭头显示 10 秒，7 秒时应可见）
	if t > 7.0 and not _arrow_tested:
		_test_arrow_indicator()
		_arrow_tested = true

	# 超时后（Boss 刷出 10 秒以上）箭头应隐藏
	if t > 17.0 and not _expire_tested:
		_expire_tested = true
		var indicator: Control = _hud.get("_boss_indicator")
		_check(not indicator.visible, "10 秒后箭头隐藏")

	# 20 秒后结束
	if t > 20.0:
		print("[test_camera] 测试完成，失败 %d 项" % _failures)
		_done = true
		quit(1 if _failures > 0 else 0)

	return false


func _test_zoom() -> void:
	print("[test_camera] === 测试镜头缩放 ===")
	var cam_script: Script = _camera.get_script()

	# 检查变量是否存在
	if not _camera.has_method("_unhandled_input"):
		print("[test_camera] ❌ 相机没有 _unhandled_input 方法")
		return

	# 模拟滚轮向上（拉近）
	var event_up: InputEventMouseButton = InputEventMouseButton.new()
	event_up.button_index = MOUSE_BUTTON_WHEEL_UP
	event_up.pressed = true
	print("[test_camera] 模拟滚轮向上 3 次（拉近）")
	for i in 3:
		_camera._unhandled_input(event_up)

	# 检查 _zoom_target
	if _camera.get("_zoom_target") != null:
		print("[test_camera] ✅ _zoom_target = %.2f" % _camera.get("_zoom_target"))
	else:
		print("[test_camera] ❌ _zoom_target 变量不存在")

	# 模拟滚轮向下（拉远）
	var event_down: InputEventMouseButton = InputEventMouseButton.new()
	event_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event_down.pressed = true
	print("[test_camera] 模拟滚轮向下 2 次（拉远）")
	for i in 2:
		_camera._unhandled_input(event_down)

	if _camera.get("_zoom_target") != null:
		print("[test_camera] ✅ _zoom_target = %.2f (应该接近 0.9)" % _camera.get("_zoom_target"))


func _test_arrow_indicator() -> void:
	print("[test_camera] === 测试 Boss 箭头指示 ===")

	# 检查 HUD 的 Boss 箭头变量
	if _hud.get("_boss_indicator") == null:
		print("[test_camera] ❌ _boss_indicator 不存在")
		return

	var indicator: Control = _hud.get("_boss_indicator")
	var indicator_time: float = _hud.get("_boss_indicator_time") if _hud.get("_boss_indicator_time") != null else 0.0

	print("[test_camera] 箭头剩余显示时间: %.2fs" % indicator_time)
	_check(indicator_time > 0.0, "Boss 刷出后箭头计时已启动")
	_check(indicator.visible, "Boss 在屏幕外时箭头可见")
	var arrow: Polygon2D = _hud.get("_boss_indicator_arrow")
	var cam: Camera3D = _camera
	var boss_screen: Vector2 = cam.unproject_position(_spawner.get_boss_info().pos)
	var view: Vector2 = _hud.get_viewport_rect().size
	# 箭头尖（多边形原点）默认朝 +y，旋转后的朝向应与「屏幕中心 → Boss」一致
	var tip_dir: Vector2 = Vector2(0, 1).rotated(arrow.rotation)
	var want: Vector2 = (boss_screen - view * 0.5).normalized()
	print("[test_camera] 箭头位置 %s，屏幕 %s，朝向 %s，应朝 %s" % [arrow.position, view, tip_dir, want])
	_check(tip_dir.dot(want) > 0.99, "箭头尖指向 Boss")
	_check(Rect2(Vector2.ZERO, view).has_point(arrow.position), "箭头在屏幕内")

	# 检查 Boss 位置信息
	var boss_info: Dictionary = _spawner.get_boss_info()
	if boss_info.has("pos"):
		print("[test_camera] ✅ Boss 位置信息: %s" % boss_info.pos)
	else:
		print("[test_camera] ❌ Boss 位置信息缺失")


func _on_game_over(_reason: String, _victory: bool) -> void:
	print("[test_camera] 游戏结束")
	_done = true
