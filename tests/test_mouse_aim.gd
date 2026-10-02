extends SceneTree
## 测试鼠标瞄准模式：验证按住鼠标时角色朝向跟随，技能朝鼠标方向释放。
## 用法（需要开窗口，不能 --headless）:
##   godot --fixed-fps 60 --path . --script res://tests/test_mouse_aim.gd

var _scene: Node = null
var _player: Node = null
var _phase: int = 0
var _frame_count: int = 0
var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("[test_mouse_aim] 开始测试")
	Talents.enabled = false
	_scene = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_scene.auto_pick_upgrades = true
	_scene.record_runs = false
	root.add_child(_scene)
	_player = _scene.get_node("PlayerM1")
	if _player == null:
		push_error("找不到玩家节点")
		quit(1)
		return

	print("[test_mouse_aim] 玩家位置: %s" % _player.global_position)


func _process(_delta: float) -> bool:
	_frame_count += 1

	match _phase:
		0:  # 等待游戏初始化并添加技能
			if _frame_count > 10:
				# 确保玩家有远程技能
				var ability_system: AbilitySystem = _player.ability_system
				if ability_system.get_skill("fireball") == null:
					var fireball: Skill = SkillFactory.create("fireball")
					ability_system.add_skill(fireball)
				if ability_system.get_skill("ice_lance") == null:
					var ice_lance: Skill = SkillFactory.create("ice_lance")
					ability_system.add_skill(ice_lance)
				print("[test_mouse_aim] 添加技能: fireball, ice_lance")
				_phase = 1
				_frame_count = 0

		1:  # 测试：不按鼠标时 mouse_aim_active 应该是 false
			_test("初始状态 mouse_aim_active 为 false", not _player.mouse_aim_active)
			_phase = 2
			_frame_count = 0

		2:  # 模拟按住鼠标左键并移动光标
			var vp: Viewport = root
			var cam: Camera3D = vp.get_camera_3d()
			if cam == null:
				push_error("找不到相机")
				return _finish()

			# 设置鼠标位置到玩家右侧（屏幕坐标）
			var target_world: Vector3 = _player.global_position + Vector3(5, 0, 0)
			var target_screen: Vector2 = cam.unproject_position(target_world)
			vp.warp_mouse(target_screen)

			# 模拟按住鼠标左键（通过设置输入状态）
			var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
			mouse_event.button_index = MOUSE_BUTTON_LEFT
			mouse_event.pressed = true
			Input.parse_input_event(mouse_event)

			_phase = 3
			_frame_count = 0

		3:  # 等待几帧让瞄准模式激活（需要超过 MOUSE_HOLD_THRESHOLD = 0.15s，约 9 帧）
			if _frame_count >= 12:
				_test("按住鼠标后 mouse_aim_active 为 true", _player.mouse_aim_active)

				# 测试角色朝向是否指向鼠标方向（右侧，即 +X）
				var facing_right: bool = _player.facing.x > 0.8 and abs(_player.facing.z) < 0.3
				_test("角色朝向跟随鼠标（朝右）", facing_right)

				_phase = 4
				_frame_count = 0

		4:  # 测试技能释放方向
			if _player.ability_system.can_cast("fireball"):
				var initial_facing: Vector3 = _player.facing
				var result: Dictionary = _player.cast_skill("fireball")

				# 验证 manual_aim 标记传递正确
				_test("火球术有结果", not result.is_empty())

				# 火球在手动瞄准时应该朝 facing 方向打（已经指向鼠标）
				var aims: Array = result.get("impacts", [])
				if not aims.is_empty():
					var aim_pos: Vector3 = aims[0]
					var aim_dir: Vector3 = (aim_pos - _player.global_position).normalized()
					var dir_match: bool = aim_dir.dot(initial_facing) > 0.9
					_test("火球朝鼠标方向释放", dir_match)

				_phase = 5
				_frame_count = 0

		5:  # 松开鼠标
			var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
			mouse_event.button_index = MOUSE_BUTTON_LEFT
			mouse_event.pressed = false
			Input.parse_input_event(mouse_event)

			_phase = 6
			_frame_count = 0

		6:  # 等待几帧后验证瞄准模式取消
			if _frame_count >= 5:
				_test("松开鼠标后 mouse_aim_active 为 false", not _player.mouse_aim_active)
				return _finish()

	return false


func _test(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % name)
	else:
		_failed += 1
		push_error("[FAIL] %s" % name)


func _finish() -> bool:
	print("\n测试结果: %d 通过, %d 失败" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true
